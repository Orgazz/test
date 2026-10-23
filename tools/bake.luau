--!nocheck
-- Genera el mapa con los scripts reales y lo guarda dentro del .rbxlx, para que
-- al abrir el archivo en Roblox Studio la ciudad ya se vea en modo edicion.
-- (Al pulsar Play el servidor lo vuelve a construir igual.)
--   lune run tools/bake.luau build/TinyEmpireTycoon.rbxlx TinyEmpireTycoon.rbxlx

local process = require("@lune/process")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local H = require("../tests/harness")

local input = process.args[1] or "build/TinyEmpireTycoon.rbxlx"
local output = process.args[2] or "TinyEmpireTycoon.rbxlx"

local game = H.loadPlace(input)
H.setup({ studio = true })
local server = H.newRealm("server", game)
local SSS = game:GetService("ServerScriptService")
local World = SSS.TinyEmpireServer.World
local WorldBuilder = server.require(World.WorldBuilder)
local PlotBuilder = server.require(World.PlotBuilder)

local map, defs = WorldBuilder.build()
for _, def in ipairs(defs) do
	local plot, pads = PlotBuilder.create(map.Plots, def)
	PlotBuilder.buildZones(plot, def, 0)
	for _, pad in pairs(pads) do
		PlotBuilder.setPadVisible(pad.model, false)
	end
end
map:SetAttribute("Prebuilt", true)

-- Quitar restos del arnes
local ws = H.place:GetService("Workspace")
for _, c in ipairs(ws:GetChildren()) do
	if c.ClassName == "Camera" then
		c:Destroy()
	end
end
local cam = roblox.Instance.new("Camera")
cam.Name = "Camera"
cam.CFrame = roblox.CFrame.new(roblox.Vector3.new(170, 120, -60)) * roblox.CFrame.fromEulerAnglesYXZ(math.rad(-32), math.rad(150), 0)
cam.Parent = ws
ws.CurrentCamera = cam

if #H.errors > 0 then
	error("errores al hornear el mapa")
end
fs.writeFile(output, roblox.serializePlace(H.place, output:sub(-6) == ".rbxlx"))
print(string.format("Mapa horneado en %s (%d piezas)", output, #map:GetDescendants()))
