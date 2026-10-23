--!nonstrict
-- Maletines de bonificacion que caen del cielo sobre la plaza central.
--  * Son piezas fisicas: caen, rebotan y ruedan; al asentarse se anclan y giran.
--  * Cada 5 minutos hay una "Lluvia de maletines" para todos los jugadores.
-- Dan dinero proporcional al ingreso de quien los recoge (no quitan nada a nadie).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent.World.Kit)
local Config = require(ReplicatedStorage.TinyEmpireShared.Config)

local CrateService = {}

local folder = nil
local onCollect = nil -- function(player, position): boolean
local onRain = nil -- function()
local rng = Random.new()

CrateService.RainInterval = 300
CrateService.RainCount = 8
CrateService.SettleTime = 3.5

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function spawnCrate(force)
	local active = #folder:GetChildren()
	if active >= Config.Crates.maxActive and not force then
		return
	end
	if active >= Config.Crates.maxActive + CrateService.RainCount * 2 then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(14, 46)
	local ground = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local startPos = ground + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(28, 40), rng:NextNumber(-4, 4))
	local m = Instance.new("Model")
	m.Name = "Briefcase"
	local cf = CFrame.new(startPos) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(-0.6, 0.6))
	local body = Kit.box(m, "Body", Vector3.new(3, 2.2, 1.2), cf, Color3.fromRGB(140, 85, 45), Enum.Material.SmoothPlastic)
	body.Anchored = false
	body.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.45, 0.55, 1, 1)
	local function attach(part)
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		weld(body, part)
		return part
	end
	attach(Kit.box(m, "Band", Vector3.new(3.05, 0.4, 1.25), cf, Color3.fromRGB(255, 205, 60), Enum.Material.Foil))
	attach(Kit.box(m, "Handle", Vector3.new(1.2, 0.5, 0.3), cf * CFrame.new(0, 1.35, 0), Color3.fromRGB(255, 205, 60), Enum.Material.Foil))
	local glow = attach(Kit.ball(m, "Glow", 4.5, cf, Color3.fromRGB(255, 230, 120), Enum.Material.Neon, { Transparency = 0.82, CastShadow = false }))
	glow.CanQuery = false
	Kit.sparkles(body, Color3.fromRGB(255, 230, 120), 8)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Range = 10
	light.Brightness = 2
	light.Parent = glow
	local _, label = Kit.billboard(body, "💼", UDim2.fromOffset(60, 60), Vector3.new(0, 3, 0), Color3.new(1, 1, 1), 90)
	label.TextStrokeTransparency = 1
	local touch = attach(Kit.box(m, "Touch", Vector3.new(6, 6, 6), cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1 }))
	touch.CanQuery = false
	m.PrimaryPart = body

	local taken = false
	touch.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		taken = true
		local ok = onCollect(player, body.Position)
		if ok then
			m:Destroy()
		else
			taken = false
		end
	end)
	m.Parent = folder
	-- Impulso inicial: cae girando
	body.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-8, 8), -10, rng:NextNumber(-8, 8))
	body.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-6, 6), rng:NextNumber(-4, 4))
	pcall(function()
		body:SetNetworkOwner(nil) -- el servidor simula: nadie puede teletransportarlo
	end)
	-- Al asentarse: anclar en pie, flotar y girar (lo anima el cliente)
	task.delay(CrateService.SettleTime, function()
		if not m.Parent then
			return
		end
		local p = body.Position
		if p.Y < -20 or p.Magnitude > 200 then
			m:Destroy() -- se salio de la plaza
			return
		end
		body.Anchored = true
		local rest = CFrame.new(p.X, math.max(p.Y, 1.7) + 0.9, p.Z)
		body.CFrame = rest
		m.WorldPivot = rest
		m:SetAttribute("SpinSpeed", 90)
		m:SetAttribute("SpinAxis", "Y")
		m:SetAttribute("BobHeight", 0.5)
		m:SetAttribute("BobSpeed", 1.2)
		m:AddTag("TE_Spin")
		m:AddTag("TE_Bob")
	end)
	task.delay(150, function()
		if m.Parent then
			m:Destroy()
		end
	end)
	return m
end

function CrateService.spawn(force)
	return spawnCrate(force)
end

-- Lluvia de maletines: varios a la vez durante unos segundos
function CrateService.rain()
	if onRain then
		onRain()
	end
	for i = 1, CrateService.RainCount do
		task.delay(i * 0.35, spawnCrate, true)
	end
end

function CrateService.init(map, collectHandler, rainHandler)
	folder = map:FindFirstChild("Crates")
	onCollect = collectHandler
	onRain = rainHandler
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
	task.spawn(function()
		while true do
			task.wait(CrateService.RainInterval)
			CrateService.rain()
		end
	end)
end

return CrateService
