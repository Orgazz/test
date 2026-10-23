--!nonstrict
-- Pantalla de carga animada: skyline que crece, titulo con rebote y consejos.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "TinyEmpireIntro"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 120)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 80, 170)),
})
grad.Rotation = 90
grad.Parent = bg

-- Sol
local sun = Instance.new("Frame")
sun.AnchorPoint = Vector2.new(0.5, 0.5)
sun.Position = UDim2.fromScale(0.78, 0.3)
sun.Size = UDim2.fromScale(0.14, 0.14)
sun.BackgroundColor3 = Color3.fromRGB(255, 230, 140)
sun.BorderSizePixel = 0
sun.Parent = bg
local sunRatio = Instance.new("UIAspectRatioConstraint")
sunRatio.Parent = sun
local sunCorner = Instance.new("UICorner")
sunCorner.CornerRadius = UDim.new(1, 0)
sunCorner.Parent = sun

-- Skyline: edificios que crecen desde abajo
local colors = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 200, 90),
	Color3.fromRGB(110, 210, 160),
	Color3.fromRGB(150, 130, 255),
	Color3.fromRGB(90, 190, 240),
	Color3.fromRGB(255, 150, 90),
}
local skyline = Instance.new("Frame")
skyline.AnchorPoint = Vector2.new(0, 1)
skyline.Position = UDim2.fromScale(0, 1)
skyline.Size = UDim2.fromScale(1, 0.42)
skyline.BackgroundTransparency = 1
skyline.Parent = bg
local rng = Random.new(5)
local x = 0
local i = 0
while x < 1 do
	i += 1
	local w = rng:NextNumber(0.045, 0.09)
	local h = rng:NextNumber(0.35, 1)
	local b = Instance.new("Frame")
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.fromScale(x, 1)
	b.Size = UDim2.fromScale(w, 0)
	b.BackgroundColor3 = colors[(i % #colors) + 1]
	b.BorderSizePixel = 0
	b.Parent = skyline
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
	-- Ventanas
	for r = 1, 4 do
		for col = 1, 2 do
			local win = Instance.new("Frame")
			win.Size = UDim2.fromScale(0.22, 0.06)
			win.Position = UDim2.fromScale(0.18 + (col - 1) * 0.42, 0.08 + (r - 1) * 0.14)
			win.BackgroundColor3 = Color3.fromRGB(255, 245, 200)
			win.BackgroundTransparency = 0.15
			win.BorderSizePixel = 0
			win.Parent = b
		end
	end
	task.delay(i * 0.05, function()
		TweenService:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(w, h) }):Play()
	end)
	x += w + 0.008
end

-- Titulo letra a letra
local titleHolder = Instance.new("Frame")
titleHolder.AnchorPoint = Vector2.new(0.5, 0.5)
titleHolder.Position = UDim2.fromScale(0.5, 0.3)
titleHolder.Size = UDim2.fromScale(0.8, 0.16)
titleHolder.BackgroundTransparency = 1
titleHolder.Parent = bg
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = titleHolder
local text = "TINY EMPIRE"
local letterColors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255) }
for k = 1, #text do
	local ch = text:sub(k, k)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = k
	l.Size = UDim2.fromScale(ch == " " and 0.04 or 0.075, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = ch
	l.TextColor3 = letterColors[(k % 2) + 1]
	l.TextTransparency = 1
	l.Parent = titleHolder
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(60, 40, 90)
	st.Transparency = 1
	st.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = l
	task.delay(0.3 + k * 0.06, function()
		TweenService:Create(l, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		TweenService:Create(st, TweenInfo.new(0.25), { Transparency = 0 }):Play()
		TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end
local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0.5)
sub.Position = UDim2.fromScale(0.5, 0.42)
sub.Size = UDim2.fromScale(0.5, 0.07)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.FredokaOne
sub.TextScaled = true
sub.Text = "✦ T Y C O O N ✦"
sub.TextColor3 = Color3.fromRGB(255, 255, 255)
sub.Parent = bg
local subStroke = Instance.new("UIStroke")
subStroke.Thickness = 3
subStroke.Color = Color3.fromRGB(60, 40, 90)
subStroke.Parent = sub

-- Barra de carga y consejos
local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.Position = UDim2.fromScale(0.5, 0.52)
barBg.Size = UDim2.fromScale(0.36, 0.028)
barBg.BackgroundColor3 = Color3.fromRGB(40, 35, 70)
barBg.BorderSizePixel = 0
barBg.Parent = bg
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barBg
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.02, 1)
fill.BackgroundColor3 = Color3.fromRGB(110, 235, 130)
fill.BorderSizePixel = 0
fill.Parent = barBg
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.Position = UDim2.fromScale(0.5, 0.58)
tip.Size = UDim2.fromScale(0.6, 0.04)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.GothamBold
tip.TextScaled = true
tip.TextColor3 = Color3.fromRGB(255, 255, 255)
tip.Parent = bg
local tips = {
	"Construyendo tu ciudad...",
	"💡 Pisa los botones verdes para abrir negocios",
	"💡 Los botones azules suben de nivel tus negocios",
	"💡 Recoge maletines 💼 en la plaza central",
	"💡 Completa los retos diarios para ganar premios",
}

local finished = false
task.spawn(function()
	local k = 1
	while not finished do
		tip.Text = tips[k]
		k = (k % #tips) + 1
		task.wait(1.6)
	end
end)

local start = os.clock()
local function progress(alpha)
	TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.max(0.02, alpha), 1) }):Play()
end
progress(0.15)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
progress(0.45)
ReplicatedStorage:WaitForChild("TinyEmpireRemotes", 60)
progress(0.75)
workspace:WaitForChild("TinyEmpireMap", 60)
playerGui:WaitForChild("TinyEmpireHUD", 30)
progress(1)
local elapsed = os.clock() - start
if elapsed < 2.8 then
	task.wait(2.8 - elapsed)
end
finished = true

-- Salida: todo se desvanece
for _, d in ipairs(gui:GetDescendants()) do
	if d:IsA("GuiObject") then
		TweenService:Create(d, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end
end
TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
task.wait(0.7)
gui:Destroy()
