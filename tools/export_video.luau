--!nocheck
-- Exporta los datos para el video de presentacion (tools/make_video.py):
--   world.json        ciudad estatica (sin la parcela 1 ni objetos moviles)
--   dynamic.json      coches, peatones, nubes y semaforos (coordenadas locales)
--   stage_XX.json     la parcela 1 tras cada compra (cronologia de construccion)
--   lune run tools/export_video.luau build/TinyEmpireTycoon.rbxlx build/video

local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local H = require("../tests/harness")

local placePath = process.args[1] or "build/TinyEmpireTycoon.rbxlx"
local outDir = process.args[2] or "build/video"
fs.writeDir(outDir)

local game = H.loadPlace(placePath)
H.setup({ studio = true })
local server = H.newRealm("server", game)
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
server.runScript(SSS.TinyEmpireServer.Main)
H.connectRemotes(RS.TinyEmpireRemotes)
local GameService = server.require(SSS.TinyEmpireServer.Services.GameService)
local Config = server.require(RS.TinyEmpireShared.Config)

local ws = H.place:GetService("Workspace")
local map = ws:FindFirstChild("TinyEmpireMap")

local function get(inst, prop, default)
	local ok, v = pcall(function()
		return inst[prop]
	end)
	if ok and v ~= nil then
		return v
	end
	return default
end

local function shapeOf(p)
	if p.ClassName == "WedgePart" then
		return 3
	end
	local s = get(p, "Shape", nil)
	if s and s.Name == "Cylinder" then
		return 1
	elseif s and s.Name == "Ball" then
		return 2
	end
	return 0
end

local MATS = { Neon = 1, Glass = 2, Foil = 3 }

-- Ancestro animado (TE_Spin / TE_Bob / TE_Slide) dentro de `root`
local function animatedAncestor(inst, root)
	local node = inst
	while node and node ~= root do
		if node:HasTag("TE_Spin") or node:HasTag("TE_Bob") or node:HasTag("TE_Slide") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function pivotOf(inst)
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	return get(inst, "WorldPivot", nil) or inst:GetDescendants()[1].CFrame
end

local function record(p, groupIndex)
	local cf = p.CFrame
	local c = get(p, "Color", nil)
	local mat = get(p, "Material", nil)
	local flags = 0
	if p:HasTag("TE_Window") then
		flags += 1
	end
	if p:HasTag("TE_Lamp") then
		flags += 2
	end
	if p:HasTag("TE_Pulse") then
		flags += 4
	end
	return {
		{ cf:GetComponents() },
		{ p.Size.X, p.Size.Y, p.Size.Z },
		c and { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } or { 150, 150, 150 },
		shapeOf(p),
		mat and MATS[mat.Name] or 0,
		get(p, "Transparency", 0),
		flags,
		groupIndex or 0,
	}
end

-- Recoge piezas visibles bajo `root`, excluyendo los subarboles de `skip`
local function collect(root, skip)
	local parts, groups, groupIndex = {}, {}, {}
	local function walk(inst)
		if skip and skip(inst) then
			return
		end
		if inst:IsA("BasePart") then
			if get(inst, "Transparency", 0) < 0.95 then
				local anim = animatedAncestor(inst, root)
				local gi = 0
				if anim then
					local key = anim:GetDebugId()
					if not groupIndex[key] then
						local pv = pivotOf(anim)
						table.insert(groups, {
							pivot = { pv:GetComponents() },
							spin = anim:HasTag("TE_Spin") and (anim:GetAttribute("SpinSpeed") or 45) or 0,
							axis = anim:GetAttribute("SpinAxis") or "Y",
							bob = anim:HasTag("TE_Bob") and (anim:GetAttribute("BobHeight") or 1) or 0,
							bobSpeed = anim:GetAttribute("BobSpeed") or 1,
							slide = anim:HasTag("TE_Slide") and { anim:GetAttribute("SlideOffset").X, anim:GetAttribute("SlideOffset").Y, anim:GetAttribute("SlideOffset").Z } or nil,
							slideSpeed = anim:GetAttribute("SlideSpeed") or 0.3,
							slideMode = anim:GetAttribute("SlideMode") or "pingpong",
							slidePhase = anim:GetAttribute("SlidePhase") or 0,
						})
						groupIndex[key] = #groups
					end
					gi = groupIndex[key]
				end
				table.insert(parts, record(inst, gi))
			end
		end
		for _, c in ipairs(inst:GetChildren()) do
			walk(c)
		end
	end
	walk(root)
	return { parts = parts, groups = groups }
end

local function isDynamic(inst)
	return inst:HasTag("TE_Car") or inst:HasTag("TE_Walker") or inst:HasTag("TE_Cloud") or inst.Name == "Camera"
end

local function save(name, data)
	fs.writeFile(outDir .. "/" .. name .. ".json", serde.encode("json", data))
end

local function localParts(model)
	local pv = pivotOf(model)
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and get(d, "Transparency", 0) < 0.95 then
			local rel = pv:ToObjectSpace(d.CFrame)
			local r = record(d, 0)
			r[1] = { rel:GetComponents() }
			local limb = ""
			if d.Name == "LegL" or (d.Name == "Shoe" and rel.Position.X < 0) then
				limb = "legL"
			elseif d.Name == "LegR" or (d.Name == "Shoe" and rel.Position.X > 0) then
				limb = "legR"
			elseif d.Name == "ArmL" or d.Name == "ArmR" then
				limb = d.Name == "ArmL" and "armL" or "armR"
			end
			r[9] = limb
			table.insert(out, r)
		end
	end
	return out
end

local function act(p, ...)
	RS.TinyEmpireRemotes.Action.OnServerEvent:Fire(p, ...)
	H.advance(0.15, 0.15)
end

-- El protagonista entra primero: recibe la parcela 1 (Barrio Pastel, junto a la plaza)
local hero = H.addPlayer("TuImperio", 1)
H.advance(2)
local hs = GameService.getState(hero)
local plot = hs.plot.model
local plotReal = H.unwrap(plot)
local mapReal = H.unwrap(map)

-- Jugadores en las demas parcelas para que la ciudad tenga vida
for i = 2, 8 do
	local p = H.addPlayer("Vecino" .. i, 500 + i)
	H.advance(1)
	local s = GameService.getState(p)
	s.data.runEarned = 10 ^ (2 + i * 0.9)
	s.data.cash = 10 ^ (3 + i * 0.9)
	if i >= 4 then
		act(p, "buyExpansion", 1)
	end
	if i >= 7 then
		act(p, "buyExpansion", 2)
	end
	for k, b in ipairs(Config.Businesses) do
		if k <= i + 1 then
			act(p, "buyBusiness", b.id)
			for _ = 1, (i + k) % 4 do
				act(p, "upgradeBusiness", b.id)
			end
		end
	end
	if i == 5 then
		act(p, "simulate", "pass", "theme")
	end
end


save("world", collect(mapReal, function(inst)
	return inst == plotReal or isDynamic(inst)
end))

local dyn = { cars = {}, walkers = {}, clouds = {}, lights = {}, ring = { 330, 185 } }
for _, d in ipairs(mapReal:GetDescendants()) do
	if d:HasTag("TE_Car") then
		table.insert(dyn.cars, { parts = localParts(d), phase = d:GetAttribute("Phase"), lane = d:GetAttribute("Lane"), speed = d:GetAttribute("Speed") })
	elseif d:HasTag("TE_Walker") then
		local a = d:GetAttribute("A")
		local b = d:GetAttribute("B")
		table.insert(dyn.walkers, {
			parts = localParts(d),
			mode = d:GetAttribute("WalkMode"),
			cx = d:GetAttribute("CenterX") or 0,
			cz = d:GetAttribute("CenterZ") or 0,
			radius = d:GetAttribute("Radius") or 20,
			a = a and { a.X, a.Y, a.Z } or nil,
			b = b and { b.X, b.Y, b.Z } or nil,
			speed = d:GetAttribute("Speed"),
			phase = d:GetAttribute("Phase"),
			baseY = d:GetAttribute("BaseY"),
		})
	elseif d:HasTag("TE_Cloud") then
		local pv = pivotOf(d)
		table.insert(dyn.clouds, { parts = localParts(d), pos = { pv.Position.X, pv.Position.Y, pv.Position.Z }, speed = d:GetAttribute("Speed") })
	elseif d:HasTag("TE_TrafficLight") then
		local lamps = {}
		for _, n in ipairs({ "Red", "Yellow", "Green" }) do
			local l = d:FindFirstChild(n)
			local c = l:GetAttribute("OnColor")
			table.insert(lamps, { pos = { l.CFrame.Position.X, l.CFrame.Position.Y, l.CFrame.Position.Z }, color = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } })
		end
		table.insert(dyn.lights, { phase = d:GetAttribute("Phase"), lamps = lamps })
	end
end
save("dynamic", dyn)

-- Cronologia de construccion de la parcela 1
local steps = {
	{ "buyBusiness", "lemonade" },
	{ "buyBusiness", "foodtruck" },
	{ "upgradeBusiness", "lemonade" },
	{ "buyBusiness", "bakery" },
	{ "upgradeBusiness", "lemonade" },
	{ "buyBusiness", "cafe" },
	{ "upgradeBusiness", "foodtruck" },
	{ "buyExpansion", 1 },
	{ "buyBusiness", "toystore" },
	{ "upgradeBusiness", "bakery" },
	{ "upgradeBusiness", "bakery" },
	{ "buyBusiness", "workshop" },
	{ "buyBusiness", "warehouse" },
	{ "buyUpgrade", "u_vans" },
	{ "upgradeBusiness", "cafe" },
	{ "upgradeBusiness", "cafe" },
	{ "buyExpansion", 2 },
	{ "buyBusiness", "factory" },
	{ "upgradeBusiness", "toystore" },
	{ "upgradeBusiness", "toystore" },
	{ "buyBusiness", "techlab" },
	{ "buyUpgrade", "u_solar" },
	{ "buyBusiness", "tower" },
	{ "upgradeBusiness", "tower" },
	{ "upgradeBusiness", "tower" },
	{ "buyUpgrade", "u_heli" },
	{ "max" },
	{ "buyUpgrade", "u_statue" },
	{ "simulate", "pass", "decor" },
}
local stageInfo = {}
local function snapshot(index, label)
	save(string.format("stage_%02d", index), collect(plotReal, nil))
	local level = hs.data.businesses
	local income = server.require(RS.TinyEmpireShared.Economy).totalIncome(hs.data, hs.passes.x2)
	table.insert(stageInfo, { label = label, income = income })
end
snapshot(0, "")
for i, st in ipairs(steps) do
	hs.data.cash = 1e15
	hs.data.runEarned = 1e15
	local label = ""
	if st[1] == "max" then
		for _, b in ipairs(Config.Businesses) do
			for _ = 1, 4 do
				act(hero, "upgradeBusiness", b.id)
			end
		end
		label = "¡Todo a nivel 5!"
	else
		act(hero, st[1], st[2], st[3])
		if st[1] == "buyBusiness" then
			label = Config.BusinessById[st[2]].icon .. " " .. Config.BusinessById[st[2]].name
		elseif st[1] == "upgradeBusiness" then
			label = Config.BusinessById[st[2]].name .. " Nv." .. hs.data.businesses[st[2]]
		elseif st[1] == "buyExpansion" then
			label = Config.Expansions[st[2]].name
		elseif st[1] == "buyUpgrade" then
			label = Config.UpgradeById[st[2]].name
		else
			label = "Decoraciones Premium"
		end
	end
	snapshot(i, label)
end
save("stages", { count = #steps + 1, info = stageInfo, plotCenter = { hs.plot.def.cframe.Position.X, hs.plot.def.cframe.Position.Z } })
print(string.format("Exportado: %d etapas, %d coches, %d peatones (errores: %d)", #steps + 1, #dyn.cars, #dyn.walkers, #H.errors))
