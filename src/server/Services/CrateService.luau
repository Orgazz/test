--!nonstrict
-- Maletines de bonificacion que aparecen en la plaza central.
-- Dan dinero proporcional al ingreso de quien los recoge (no quitan nada a nadie).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent.World.Kit)
local Config = require(ReplicatedStorage.TinyEmpireShared.Config)

local CrateService = {}

local folder = nil
local onCollect = nil -- function(player, position)
local rng = Random.new()

local function spawnCrate()
	local active = #folder:GetChildren()
	if active >= Config.Crates.maxActive then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(14, 46)
	local pos = Vector3.new(math.cos(a) * r, 2.6, math.sin(a) * r)
	local m = Instance.new("Model")
	m.Name = "Briefcase"
	local cf = CFrame.new(pos)
	local body = Kit.box(m, "Body", Vector3.new(3, 2.2, 1), cf, Color3.fromRGB(140, 85, 45), Enum.Material.SmoothPlastic, { CanCollide = false })
	Kit.box(m, "Band", Vector3.new(3.05, 0.4, 1.05), cf, Color3.fromRGB(255, 205, 60), Enum.Material.Foil, { CanCollide = false })
	Kit.box(m, "Handle", Vector3.new(1.2, 0.5, 0.3), cf * CFrame.new(0, 1.3, 0), Color3.fromRGB(255, 205, 60), Enum.Material.Foil, { CanCollide = false })
	local glow = Kit.ball(m, "Glow", 4.5, cf, Color3.fromRGB(255, 230, 120), Enum.Material.Neon, { Transparency = 0.8, CanCollide = false, CastShadow = false })
	Kit.sparkles(body, Color3.fromRGB(255, 230, 120), 8)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Range = 10
	light.Brightness = 2
	light.Parent = glow
	local _, label = Kit.billboard(body, "💼", UDim2.fromOffset(60, 60), Vector3.new(0, 3, 0), Color3.new(1, 1, 1), 90)
	label.TextStrokeTransparency = 1
	m.WorldPivot = cf
	m:AddTag("TE_Spin")
	m:SetAttribute("SpinSpeed", 90)
	m:SetAttribute("SpinAxis", "Y")
	local taken = false
	local touch = Kit.box(m, "Touch", Vector3.new(6, 6, 6), cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
	touch.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		taken = true
		local ok = onCollect(player, pos)
		if ok then
			m:Destroy()
		else
			taken = false
		end
	end)
	m.Parent = folder
	task.delay(120, function()
		if m.Parent then
			m:Destroy()
		end
	end)
end

function CrateService.init(map, collectHandler)
	folder = map:FindFirstChild("Crates")
	onCollect = collectHandler
	task.spawn(function()
		task.wait(3)
		for _ = 1, 3 do
			spawnCrate()
		end
		while true do
			task.wait(Config.Crates.spawnInterval)
			spawnCrate()
		end
	end)
end

return CrateService
