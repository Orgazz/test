--!nonstrict
-- Tutorial guiado: texto en pantalla + haz de luz desde el jugador hasta el objetivo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(script.Parent.UI.Hud)
local Shared = ReplicatedStorage:WaitForChild("TinyEmpireShared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local TRUCK_COST = Format.cash(Config.BusinessById.foodtruck.cost)

local Tutorial = {}

local player = Players.LocalPlayer
local map
local beam, attach0, attach1, marker
local currentTarget = nil
local highlightTween = nil

Tutorial.Steps = {
	{ text = "👋 ¡Bienvenido a tu parcela! Pisa el botón verde ⬇ para abrir tu Puesto de Limonada (¡gratis!).", pad = "lemonade" },
	{ text = "💰 Tus negocios ganan dinero solos cada segundo. ¡Reúne " .. TRUCK_COST .. " para tu siguiente negocio!" },
	{ text = "🌮 ¡Ya tienes " .. TRUCK_COST .. "! Pisa el botón del Food Truck para comprarlo.", pad = "foodtruck" },
	{ text = "⬆️ Sube de nivel un negocio: pisa su botón azul o usa el menú 🏛️ Imperio.", pad = "lemonade" },
	{ text = "✨ Abre 🏛️ Imperio → Mejoras y compra 'Letrero Llamativo' (+10% de ingresos).", menu = "empire" },
	{ text = "🎯 Abre el menú 🎯 Retos: tienes retos diarios y objetivos de expansión con premios.", menu = "challenges" },
	{ text = "⛲ Visita la plaza central (botón ⛲ Plaza) y recoge maletines 💼 llenos de dinero.", plaza = true, menu = "plaza" },
}

local function ensureBeam()
	if beam and beam.Parent then
		return
	end
	attach1 = Instance.new("Attachment")
	attach1.Name = "TutorialTarget"
	local holder = Instance.new("Part")
	holder.Name = "TutorialAnchor"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.5, 0.5, 0.5)
	holder.Parent = workspace
	attach1.Parent = holder
	beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment1 = attach1
	beam.Width0 = 1.6
	beam.Width1 = 1.6
	beam.FaceCamera = true
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(120, 255, 140))
	beam.Transparency = NumberSequence.new(0.15)
	beam.Segments = 20
	beam.CurveSize0 = 6
	beam.Parent = holder
	marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(80, 80)
	marker.StudsOffset = Vector3.new(0, 6, 0)
	marker.AlwaysOnTop = true
	marker.Parent = holder
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Text = "⬇️"
	arrow.TextScaled = true
	arrow.Parent = marker
	TweenService:Create(marker, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
end

local function attachToCharacter()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	if not attach0 or attach0.Parent ~= root then
		attach0 = Instance.new("Attachment")
		attach0.Name = "TutorialSource"
		attach0.Parent = root
	end
	beam.Attachment0 = attach0
	return true
end

local function setTarget(position)
	currentTarget = position
	if not position then
		if beam then
			beam.Parent.Parent = nil
		end
		return
	end
	ensureBeam()
	beam.Parent.Parent = workspace
	beam.Parent.CFrame = CFrame.new(position)
	attachToCharacter()
end

local function highlightMenu(key)
	if highlightTween then
		highlightTween:Cancel()
		highlightTween = nil
	end
	for _, k in ipairs({ "empire", "challenges", "plaza" }) do
		local btn = Hud.menuButton(k)
		if btn then
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = 3
			end
		end
	end
	if key then
		local btn = Hud.menuButton(key)
		local stroke = btn and btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 3
			highlightTween = TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 8 })
			highlightTween:Play()
		end
	end
end

function Tutorial.update(state)
	local step = state.tutorial or 99
	local def = Tutorial.Steps[step]
	if not def then
		Hud.setTutorial(nil)
		setTarget(nil)
		highlightMenu(nil)
		return
	end
	Hud.setTutorial(step, #Tutorial.Steps, def.text)
	highlightMenu(def.menu)
	local target = nil
	if def.pad and state.plotIndex then
		local plot = map.Plots:FindFirstChild("Plot" .. state.plotIndex)
		local pad = plot and plot.Pads:FindFirstChild("Pad_" .. def.pad)
		local button = pad and pad:FindFirstChild("Button")
		if button then
			target = button.Position + Vector3.new(0, 1, 0)
		end
	elseif def.plaza then
		target = Vector3.new(0, 10, 0)
	end
	setTarget(target)
end

function Tutorial.init(worldMap)
	map = worldMap
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		if currentTarget and beam then
			attachToCharacter()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if currentTarget and beam and beam.Attachment0 == nil then
			attachToCharacter()
		end
	end)
end

return Tutorial
