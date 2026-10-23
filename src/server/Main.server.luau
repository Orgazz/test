--!nonstrict
-- Tiny Empire Tycoon :: arranque del servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local World = script.Parent.World
local Services = script.Parent.Services

local WorldBuilder = require(World.WorldBuilder)
local PlotService = require(Services.PlotService)
local GameService = require(Services.GameService)
local DataService = require(Services.DataService)
local CrateService = require(Services.CrateService)
local DayNightService = require(Services.DayNightService)
local LeaderboardService = require(Services.LeaderboardService)

-- Remotos
local remotes = Instance.new("Folder")
remotes.Name = "TinyEmpireRemotes"
for _, name in ipairs({ "Action", "State", "Tick", "Notify", "Effect" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end

-- Mundo
local map, plotDefs = WorldBuilder.build()
PlotService.init(plotDefs, map.Plots, GameService.onPad)

-- Los clientes esperan a que exista la carpeta de remotos (mundo listo)
remotes.Parent = ReplicatedStorage

DayNightService.start()
DataService.start()
GameService.init(remotes)
CrateService.init(map, GameService.collectCrate)
LeaderboardService.start(map, GameService.getStates)

Players.CharacterAutoLoads = true
print(string.format("[TinyEmpire] Servidor listo: %d parcelas creadas.", #plotDefs))
