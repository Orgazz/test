--!nocheck
-- Arranca el servidor en el arnes, crea parcelas con distintos niveles de progreso
-- y exporta todas las piezas visibles a JSON para renderizar vistas previas.
--   lune run tools/export_scene.luau build/TinyEmpireTycoon.rbxlx build/scene.json

local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local H = require("../tests/harness")

local placePath = process.args[1] or "build/TinyEmpireTycoon.rbxlx"
local outPath = process.args[2] or "build/scene.json"

local game = H.loadPlace(placePath)
H.setup({ studio = true })
local server = H.newRealm("server", game)
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
server.runScript(SSS.TinyEmpireServer.Main)
H.connectRemotes(RS.TinyEmpireRemotes)
local GameService = server.require(SSS.TinyEmpireServer.Services.GameService)
local Config = server.require(RS.TinyEmpireShared.Config)

local function act(p, ...)
	RS.TinyEmpireRemotes.Action.OnServerEvent:Fire(p, ...)
	H.advance(0.15, 0.15)
end

-- Jugador 1: imperio completo con extras premium
local p1 = H.addPlayer("Magnate", 1)
H.advance(2)
local s1 = GameService.getState(p1)
s1.data.runEarned = 1e12
s1.data.cash = 1e13
act(p1, "buyExpansion", 1)
act(p1, "buyExpansion", 2)
for _, b in ipairs(Config.Businesses) do
	act(p1, "buyBusiness", b.id)
	for _ = 1, 4 do
		act(p1, "upgradeBusiness", b.id)
	end
end
for _, u in ipairs(Config.Upgrades) do
	act(p1, "buyUpgrade", u.id)
end
act(p1, "simulate", "pass", "decor")

-- Jugador 2: tema dorado y progreso medio
local p2 = H.addPlayer("Dorada", 2)
H.advance(2)
local s2 = GameService.getState(p2)
s2.data.runEarned = 5e6
s2.data.cash = 5e7
act(p2, "buyExpansion", 1)
for i, b in ipairs(Config.Businesses) do
	if i <= 7 then
		act(p2, "buyBusiness", b.id)
		for _ = 1, (i % 3) + 1 do
			act(p2, "upgradeBusiness", b.id)
		end
	end
end
act(p2, "simulate", "pass", "theme")

-- Jugador 3: recien empezado
local p3 = H.addPlayer("Novato", 3)
H.advance(2)
act(p3, "buyBusiness", "lemonade")
H.advance(60)
act(p3, "buyBusiness", "foodtruck")

-- Jugadores 4-5 en otros barrios
for i = 4, 8 do
	local p = H.addPlayer("Jugador" .. i, i)
	H.advance(2)
	local s = GameService.getState(p)
	s.data.runEarned = 10 ^ (i - 1)
	s.data.cash = 10 ^ (i)
	if i >= 6 then
		act(p, "buyExpansion", 1)
	end
	for k, b in ipairs(Config.Businesses) do
		if k <= i - 1 then
			act(p, "buyBusiness", b.id)
			act(p, "upgradeBusiness", b.id)
		end
	end
end
H.advance(5)

local parts = {}
local function shapeOf(real)
	if real.ClassName == "WedgePart" then
		return "Wedge"
	end
	local ok, shape = pcall(function()
		return real.Shape
	end)
	if ok and shape then
		return shape.Name
	end
	return "Block"
end
local function get(real, prop, default)
	local ok, v = pcall(function()
		return real[prop]
	end)
	if ok and v ~= nil then
		return v
	end
	return default
end
for _, d in ipairs(H.place:GetService("Workspace"):GetDescendants()) do
	if d:IsA("BasePart") then
		local transparency = get(d, "Transparency", 0)
		if transparency < 0.95 then
			local cf = d.CFrame
			local c = get(d, "Color", nil)
			local mat = get(d, "Material", nil)
			table.insert(parts, {
				cf = { cf:GetComponents() },
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				color = c and { c.R, c.G, c.B } or { 0.6, 0.6, 0.6 },
				shape = shapeOf(d),
				t = transparency,
				m = mat and mat.Name or "Plastic",
				name = d.Name,
			})
		end
	end
end
fs.writeFile(outPath, serde.encode("json", { parts = parts }))
print(string.format("Exportadas %d piezas a %s (errores: %d)", #parts, outPath, #H.errors))
