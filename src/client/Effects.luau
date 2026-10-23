--!nonstrict
-- Efectos de pantalla: confeti, dinero volando hacia el contador y destellos.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("TinyEmpireShared").Format)
local Theme = require(script.Parent.UI.Theme)

local Effects = {}

local gui
local layer

local CONFETTI = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(190, 120, 255),
}

function Effects.init(screenGui)
	gui = screenGui
	layer = Instance.new("Frame")
	layer.Name = "Effects"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ZIndex = 80
	layer.Parent = gui
end

function Effects.confetti(count)
	count = count or 60
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		piece.Position = UDim2.new(math.random(), 0, -0.05, 0)
		piece.BackgroundColor3 = CONFETTI[math.random(#CONFETTI)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 81
		piece.Parent = layer
		local duration = 1.6 + math.random() * 1.4
		local goal = {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.25, 0, 1.05, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
		}
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), goal):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

-- Texto "+$X" grande en el centro que vuela hacia el contador
function Effects.cashBurst(amount, target)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromOffset(360, 70)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+" .. Format.cash(amount)
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.ZIndex = 82
	label.Parent = layer
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 70, 30)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- Monedas
	for _ = 1, 10 do
		local coin = Instance.new("TextLabel")
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.new(0.5, math.random(-120, 120), 0.45, math.random(-60, 60))
		coin.Size = UDim2.fromOffset(34, 34)
		coin.BackgroundTransparency = 1
		coin.TextScaled = true
		coin.Text = "🪙"
		coin.ZIndex = 82
		coin.Parent = layer
		task.delay(0.3 + math.random() * 0.3, function()
			TweenService:Create(coin, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, -100, 0, 40), TextTransparency = 0.6 }):Play()
			task.wait(0.62)
			coin:Destroy()
		end)
	end
	task.delay(0.9, function()
		TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, -100, 0, 40), TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.wait(0.55)
		label:Destroy()
		if target then
			Theme.pop(target)
		end
		Theme.play("coin")
	end)
end

-- Destello de color en los bordes de la pantalla
function Effects.flash(color)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.ZIndex = 79
	f.Parent = layer
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 26
	stroke.Color = color
	stroke.Transparency = 0.3
	stroke.Parent = f
	TweenService:Create(stroke, TweenInfo.new(0.7), { Transparency = 1, Thickness = 4 }):Play()
	task.delay(0.75, function()
		f:Destroy()
	end)
end

return Effects
