--!nocheck
-- Graba (en datos) un video de fisicas y animaciones ejecutando el codigo REAL del
-- cliente y del servidor en el arnes, fotograma a fotograma (24 fps).
-- La fisica de piezas sueltas es una aproximacion (tools/sim.luau).
--   lune run tools/export_physics_video.luau build/TinyEmpireTycoon.rbxlx build/pvideo

local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local H = require("../tests/harness")
local Sim = require("./sim")

local Vector3 = roblox.Vector3
local CFrame = H.CFrame
local FPS = 24
local DT = 1 / FPS

local placePath = process.args[1] or "build/TinyEmpireTycoon.rbxlx"
local outDir = process.args[2] or "build/pvideo"
fs.writeDir(outDir)
for _, f in ipairs(fs.readDir(outDir)) do
	fs.removeFile(outDir .. "/" .. f)
end

local game = H.loadPlace(placePath)
H.setup({ studio = true })
Sim.install(H)
local server = H.newRealm("server", game)
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
server.runScript(SSS.TinyEmpireServer.Main)
H.connectRemotes(RS.TinyEmpireRemotes)
local GameService = server.require(SSS.TinyEmpireServer.Services.GameService)
local CrateService = server.require(SSS.TinyEmpireServer.Services.CrateService)
local Details = server.require(SSS.TinyEmpireServer.World.Details)
CrateService.RainInterval = 1e9 -- la lluvia la lanzamos nosotros

local hero = H.addPlayer("Tu", 1)
H.clientPlayer = hero
local client = H.newRealm("client", H.clientGame(hero))
local clientRoot = game:GetService("StarterPlayer").StarterPlayerScripts.TinyEmpireClient
client.runScript(clientRoot.Main)
H.advance(3, 0.1)
Sim.enablePhysics(H, game)

local Traffic = client.require(clientRoot.World.Traffic)
local hs = GameService.getState(hero)
local map = H.workspace.TinyEmpireMap

-- Cuerpo visible del jugador, soldado a su HumanoidRootPart
local character = H.customOf(hero).Character
local root = character.HumanoidRootPart
root.Size = Vector3.new(2, 5, 1)
root.Transparency = 1
root.Anchored = false
Sim.addBody(root)
local rng = {
	NextInteger = function(_, a, b)
		return math.random(a, b)
	end,
	NextNumber = function(_, a, b)
		a = a or 0
		b = b or 1
		return a + math.random() * (b - a)
	end,
}
math.randomseed(9)
local body = Details.person(character, root.CFrame * CFrame.new(0, -2.5, 0), rng, { shirt = roblox.Color3.fromRGB(255, 90, 160) })
for _, d in ipairs(body:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = false
		d.CanCollide = false
		local w = H.wrap(roblox.Instance.new("WeldConstraint"))
		w.Part0 = root
		w.Part1 = d
		w.Parent = root
		Sim.addWeld(w)
	end
end

local function placeHero(x, z, facing)
	local g = Sim.groundAt(x, z)
	local pos = Vector3.new(x, g + 2.5, z)
	local look = facing and CFrame.lookAt(pos, pos + facing) or CFrame.new(pos)
	root.CFrame = look
	root.AssemblyLinearVelocity = Vector3.zero
end

------------------------------------------------------------------------------
-- Exportacion de fotogramas
------------------------------------------------------------------------------

local MATS = { Neon = 1, Glass = 2, Foil = 3 }
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

local heroModelReal = H.unwrap(character)
local function isDynamic(real)
	local node = real
	while node do
		if node == heroModelReal then
			return true
		end
		local name = node.Name
		if name == "TE_Effect" or name == "Briefcase" or node:HasTag("TE_Car") or node:HasTag("TE_Walker") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function record(p)
	local t = get(p, "Transparency", 0)
	local ltm = get(p, "LocalTransparencyModifier", 0) or 0
	t = math.max(t, ltm)
	if t >= 0.95 then
		return nil
	end
	local c = get(p, "Color", nil)
	local mat = get(p, "Material", nil)
	local cf = p.CFrame
	return {
		{ cf:GetComponents() },
		{ p.Size.X, p.Size.Y, p.Size.Z },
		c and { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } or { 150, 150, 150 },
		shapeOf(p),
		mat and MATS[mat.Name] or 0,
		t,
		p:HasTag("TE_Window") and 1 or 0,
	}
end

local wsReal = H.place:GetService("Workspace")
local function allParts()
	local out = {}
	for _, d in ipairs(wsReal:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local sceneIndex = 0
local frameIndex = 0
local scene -- { name, target, radius, region = {...}, dynamic = {...} }

local function refreshLists()
	local region, dynamic = {}, {}
	for _, p in ipairs(allParts()) do
		local pos = p.CFrame.Position
		local dx, dz = pos.X - scene.target.X, pos.Z - scene.target.Z
		local dist = math.sqrt(dx * dx + dz * dz)
		if isDynamic(p) then
			if dist < 260 then
				table.insert(dynamic, p)
			end
		elseif dist < scene.radius then
			table.insert(region, p)
		end
	end
	scene.region, scene.dynamic = region, dynamic
end

local function beginScene(name, title, target, radius)
	sceneIndex += 1
	frameIndex = 0
	scene = { name = name, target = target, radius = radius }
	-- Base estatica: todo lo que no es dinamico ni esta en la region animada
	local base = {}
	for _, p in ipairs(allParts()) do
		if not isDynamic(p) then
			local pos = p.CFrame.Position
			local dx, dz = pos.X - target.X, pos.Z - target.Z
			if math.sqrt(dx * dx + dz * dz) >= radius then
				local r = record(p)
				if r then
					table.insert(base, r)
				end
			end
		end
	end
	fs.writeFile(string.format("%s/s%02d_base.json", outDir, sceneIndex), serde.encode("json", { parts = base, title = title }))
	refreshLists()
	print(string.format("Escena %d (%s): %d piezas base", sceneIndex, name, #base))
end

local function capture(camPos, camTarget, label, fov)
	if frameIndex % 12 == 0 then
		refreshLists()
	end
	local parts = {}
	for _, list in ipairs({ scene.region, scene.dynamic }) do
		for _, p in ipairs(list) do
			local ok, r = pcall(function()
				return p.Parent and record(p)
			end)
			if ok and r then
				table.insert(parts, r)
			end
		end
	end
	frameIndex += 1
	fs.writeFile(string.format("%s/s%02d_f%04d.json", outDir, sceneIndex, frameIndex), serde.encode("json", {
		cam = { camPos.X, camPos.Y, camPos.Z, camTarget.X, camTarget.Y, camTarget.Z, fov or 60 },
		label = label,
		parts = parts,
	}))
end

local function tick()
	H.advance(DT, DT)
end

local function lerpV(a, b, t)
	return a + (b - a) * t
end

------------------------------------------------------------------------------
-- ESCENA 1: semaforos (frenado, cola y arranque)
------------------------------------------------------------------------------
do
	local inter = nil
	for _, it in ipairs(Traffic._intersections) do
		local p = Traffic._sample(it.s)
		if math.abs(p.X) < 1 and p.Z > 0 then
			inter = it
		end
	end
	-- Esperar a que el semaforo del anillo este en verde (ciclo 0.28)
	local guard = 0
	while guard < 2000 do
		local t = Traffic._time or 0
		local cycle = (t / 12 + inter.phase) % 1
		if math.abs(cycle - 0.28) < 0.004 then
			break
		end
		tick()
		guard += 1
	end
	-- Colocar coches acercandose por ambos carriles
	local L = Traffic._length
	local byLane = { [1] = {}, [-1] = {} }
	for _, c in ipairs(Traffic._cars) do
		table.insert(byLane[c.lane], c)
	end
	for lane, list in pairs(byLane) do
		for i = 1, math.min(3, #list) do
			local c = list[i]
			c.s = (inter.s - lane * (55 + i * 32)) % L
			c.v = c.cruise
			c.stopping, c.committed = nil, nil
		end
	end
	placeHero(40, 120, Vector3.new(0, 0, 1))
	local center = Traffic._sample(inter.s)
	beginScene("traffic", "Semáforos: los coches frenan en rojo y arrancan en verde", center, 75)
	local n = 15 * FPS
	for f = 1, n do
		tick()
		local u = f / n
		local camPos = Vector3.new(-34 + 22 * u, 40 - 6 * u, center.Z - 46)
		capture(camPos, center + Vector3.new(4, 0, 2), nil, 56)
	end
end

------------------------------------------------------------------------------
-- ESCENA 2: un coche frena ante el jugador
------------------------------------------------------------------------------
do
	local L = Traffic._length
	local target = Vector3.new(-120, 0, 185)
	local bestS, best = 0, math.huge
	for s = 0, L, 0.5 do
		local p = Traffic._sample(s)
		local d = (p - target).Magnitude
		if d < best then
			best, bestS = d, s
		end
	end
	local _, dir = Traffic._sample(bestS)
	local car = nil
	for _, c in ipairs(Traffic._cars) do
		if c.lane == 1 then
			car = c
		end
	end
	-- el coche va en sentido +s; coloca al jugador 40 studs por delante en su carril
	car.s = (bestS - 70) % L
	car.v = car.cruise
	car.stopping, car.committed = nil, nil
	local carPos = Traffic._sample(bestS)
	local right = dir:Cross(Vector3.yAxis)
	local heroPos = carPos + right * 5
	placeHero(heroPos.X, heroPos.Z, -dir)
	beginScene("brake", "Frenan ante los jugadores que cruzan", heroPos, 70)
	local n = 9 * FPS
	for f = 1, n do
		local tsec = f / FPS
		if tsec > 4.5 and tsec < 6.5 then
			-- el jugador se aparta de la calzada
			local p = root.CFrame.Position
			local side = -right
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(side.X * 9, v.Y, side.Z * 9)
			local _ = p
		elseif tsec >= 6.5 then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		end
		tick()
		local camPos = heroPos - right * 13 + dir * 20 + Vector3.new(0, 9, 0)
		capture(camPos, heroPos - dir * 12 + Vector3.new(0, 2, 0), nil, 58)
	end
end

------------------------------------------------------------------------------
-- ESCENA 3: plaza con peatones, banderas y arboles al viento
------------------------------------------------------------------------------
do
	placeHero(-40, -20, Vector3.new(1, 0, 0))
	beginScene("plaza", "Peatones que pasean, se paran y dan la vuelta · banderas y árboles al viento", Vector3.new(14, 0, 30), 70)
	local n = 8 * FPS
	for f = 1, n do
		tick()
		local u = f / n
		local camPos = lerpV(Vector3.new(-6, 20, -14), Vector3.new(4, 18, -10), u)
		capture(camPos, Vector3.new(24, 7, 42), nil, 60)
	end
end

------------------------------------------------------------------------------
-- ESCENA 4: lluvia de maletines con fisica y monedas al recogerlos
------------------------------------------------------------------------------
do
	for _, c in ipairs(map.Crates:GetChildren()) do
		c:Destroy()
	end
	placeHero(0, -30, Vector3.new(0, 0, 1))
	beginScene("rain", "Lluvia de maletines: caen, rebotan y sueltan monedas físicas", Vector3.new(0, 0, 5), 75)
	CrateService.rain()
	local n = 11 * FPS
	local collected = 0
	for f = 1, n do
		local tsec = f / FPS
		-- A partir de 4.5 s el jugador corre a por el maletin mas cercano
		if tsec > 4.5 then
			local best, bestD = nil, math.huge
			for _, c in ipairs(map.Crates:GetChildren()) do
				local b = c:FindFirstChild("Body")
				if b then
					local d = (b.Position - root.Position).Magnitude
					if d < bestD then
						best, bestD = c, d
					end
				end
			end
			if best then
				local to = best.Body.Position - root.Position
				local flat = Vector3.new(to.X, 0, to.Z)
				local v = root.AssemblyLinearVelocity
				if flat.Magnitude > 2.5 then
					local dir = flat.Unit
					root.AssemblyLinearVelocity = Vector3.new(dir.X * 26, v.Y, dir.Z * 26)
					root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
				else
					root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
					H.touch(hero, best.Touch)
					collected += 1
				end
			end
		end
		tick()
		local u = f / n
		local camPos = lerpV(Vector3.new(-16, 32, -56), Vector3.new(8, 28, -50), u)
		capture(camPos, Vector3.new(0, 2, 8), nil, 58)
	end
	print("maletines recogidos: " .. collected)
end

------------------------------------------------------------------------------
-- ESCENA 5: trampolin
------------------------------------------------------------------------------
do
	placeHero(60, 14, Vector3.new(-1, 0, -0.8))
	beginScene("trampoline", "Trampolines con lona de muelle: ¡salta hasta el cielo!", Vector3.new(44, 0, 0), 60)
	local n = 8 * FPS
	for f = 1, n do
		local tsec = f / FPS
		local to = Vector3.new(44, 0, 0) - root.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		local v = root.AssemblyLinearVelocity
		if tsec < 2.2 and flat.Magnitude > 1 then
			local dir = flat.Unit
			root.AssemblyLinearVelocity = Vector3.new(dir.X * 12, v.Y, dir.Z * 12)
		elseif tsec < 2.2 then
			root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		end
		tick()
		local y = root.Position.Y
		local camPos = Vector3.new(58, 12 + y * 0.75, -16)
		capture(camPos, Vector3.new(44, 3 + y * 0.85, 0), nil, 66)
	end
end

------------------------------------------------------------------------------
-- ESCENA 6: construccion animada con escombros y monedas
------------------------------------------------------------------------------
do
	local plotCF = hs.plot.def.cframe
	local center = plotCF.Position
	placeHero(center.X, center.Z - 52, Vector3.new(0, 0, 1))
	beginScene("build", "Las obras crecen planta a planta, con escombros y monedas", center + Vector3.new(0, 0, -22), 70)
	hs.data.cash = 1e15
	hs.data.runEarned = 1e15
	local steps = {
		{ 0.5, "buyBusiness", "lemonade" },
		{ 2.0, "buyBusiness", "foodtruck" },
		{ 3.5, "buyBusiness", "bakery" },
		{ 5.0, "buyBusiness", "cafe" },
		{ 6.5, "upgradeBusiness", "lemonade" },
		{ 7.5, "upgradeBusiness", "lemonade" },
		{ 8.5, "upgradeBusiness", "bakery" },
		{ 9.5, "upgradeBusiness", "bakery" },
		{ 10.5, "upgradeBusiness", "cafe" },
	}
	local n = 13 * FPS
	local k = 1
	for f = 1, n do
		local tsec = f / FPS
		while steps[k] and tsec >= steps[k][1] do
			RS.TinyEmpireRemotes.Action.OnServerEvent:Fire(hero, steps[k][2], steps[k][3])
			k += 1
		end
		tick()
		local u = f / n
		local a = math.rad(-25 + 40 * u)
		local tgt = center + Vector3.new(0, 4, -26)
		local camPos = tgt + Vector3.new(math.sin(a) * 48, 22, -math.cos(a) * 48)
		capture(camPos, tgt, nil, 60)
	end
end

fs.writeFile(outDir .. "/scenes.json", serde.encode("json", { count = sceneIndex, fps = FPS }))
print(string.format("Listo: %d escenas (errores: %d)", sceneIndex, #H.errors))
for i = 1, math.min(5, #H.errors) do
	print(H.errors[i])
end
