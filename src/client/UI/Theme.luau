--!nonstrict
-- Estilo visual y constructores de interfaz reutilizables.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.Body = Enum.Font.GothamMedium
Theme.Bold = Enum.Font.GothamBold

Theme.C = {
	bg = Color3.fromRGB(28, 32, 48),
	bg2 = Color3.fromRGB(40, 46, 68),
	bg3 = Color3.fromRGB(54, 62, 90),
	text = Color3.fromRGB(245, 247, 255),
	muted = Color3.fromRGB(165, 175, 205),
	green = Color3.fromRGB(80, 215, 110),
	greenDark = Color3.fromRGB(40, 150, 75),
	blue = Color3.fromRGB(80, 160, 255),
	blueDark = Color3.fromRGB(45, 105, 200),
	gold = Color3.fromRGB(255, 200, 60),
	goldDark = Color3.fromRGB(205, 140, 20),
	red = Color3.fromRGB(240, 85, 85),
	redDark = Color3.fromRGB(170, 45, 45),
	purple = Color3.fromRGB(170, 110, 255),
	purpleDark = Color3.fromRGB(110, 60, 200),
	pink = Color3.fromRGB(255, 110, 170),
	grey = Color3.fromRGB(110, 115, 135),
	greyDark = Color3.fromRGB(75, 80, 98),
	white = Color3.new(1, 1, 1),
}

function Theme.new(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Theme.corner(radius)
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.stroke(color, thickness, transparency)
	return Theme.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(color, thickness)
	return Theme.new("UIStroke", {
		Color = color or Color3.fromRGB(20, 20, 30),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Theme.padding(all, top)
	return Theme.new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, top or all),
		PaddingBottom = UDim.new(0, top or all),
	})
end

function Theme.gradient(a, b, rotation)
	return Theme.new("UIGradient", {
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 90,
	})
end

function Theme.list(padding, direction, hAlign, vAlign)
	return Theme.new("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Theme.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.C.text,
		TextScaled = true,
		Text = "",
	}
	for k, v in pairs(props or {}) do
		if k ~= "MaxText" then
			defaults[k] = v
		end
	end
	local l = Theme.new("TextLabel", defaults)
	if defaults.TextScaled then
		Theme.new("UITextSizeConstraint", { MaxTextSize = props and props.MaxText or 40, Parent = l })
	end
	return l
end

function Theme.panel(props, children)
	local defaults = {
		BackgroundColor3 = Theme.C.bg,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props or {}) do
		if k ~= "Radius" then
			defaults[k] = v
		end
	end
	local f = Theme.new("Frame", defaults, children)
	Theme.corner(props and props.Radius or 14).Parent = f
	return f
end

------------------------------------------------------------------------------
-- Sonidos
------------------------------------------------------------------------------

local SOUNDS = {
	click = { id = "rbxasset://sounds/button.wav", volume = 0.5, pitch = 1.1 },
	success = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.5 },
	build = { id = "rbxasset://sounds/snap.wav", volume = 0.8, pitch = 0.9 },
	levelup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.25 },
	upgrade = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 0.8 },
	error = { id = "rbxasset://sounds/button.wav", volume = 0.6, pitch = 0.55 },
}
local soundCache = {}

function Theme.play(name)
	local def = SOUNDS[name]
	if not def then
		return
	end
	local s = soundCache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "TE_" .. name
		s.SoundId = def.id
		s.Volume = def.volume
		s.PlaybackSpeed = def.pitch
		s.Parent = SoundService
		soundCache[name] = s
	end
	SoundService:PlayLocalSound(s)
end

------------------------------------------------------------------------------
-- Boton con animacion
------------------------------------------------------------------------------

function Theme.button(props)
	local color = props.Color or Theme.C.green
	local dark = props.Dark or color:Lerp(Color3.new(0, 0, 0), 0.3)
	local btn = Theme.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Theme.corner(props.Radius or 12).Parent = btn
	local stroke = Theme.stroke(dark, 3)
	stroke.Parent = btn
	Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205), 90).Parent = btn
	local label = Theme.label({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "",
		TextColor3 = Theme.C.white,
		MaxText = props.MaxText or 28,
		Parent = btn,
	})
	Theme.padding(6, 4).Parent = label
	Theme.textStroke(dark, 2).Parent = label
	local scale = Theme.new("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1.03 }):Play()
	end)
	if props.OnClick then
		btn.Activated:Connect(function()
			Theme.play("click")
			props.OnClick()
		end)
	end
	return btn
end

-- Cambia color y texto de un boton creado con Theme.button
function Theme.setButton(btn, text, color, enabled)
	btn.Label.Text = text
	btn.BackgroundColor3 = color
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.3)
	btn.UIStroke.Color = dark
	btn.Label.UIStroke.Color = dark
	btn.Active = enabled ~= false
	btn.AutoButtonColor = false
end

function Theme.progressBar(props)
	local bar = Theme.new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.fromRGB(18, 20, 32),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Theme.corner(8).Parent = bar
	local fill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or Theme.C.green,
		Parent = bar,
	})
	Theme.corner(8).Parent = fill
	Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90).Parent = fill
	return bar
end

function Theme.setProgress(bar, alpha, animate)
	alpha = math.clamp(alpha or 0, 0, 1)
	local goal = UDim2.fromScale(alpha, 1)
	if animate then
		TweenService:Create(bar.Fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = goal }):Play()
	else
		bar.Fill.Size = goal
	end
end

function Theme.pop(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = guiObject })
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Theme
