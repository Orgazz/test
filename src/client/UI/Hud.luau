--!nonstrict
-- HUD principal: dinero, ingresos, nivel, menu lateral, objetivo actual,
-- notificaciones, tutorial y ventanas emergentes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TinyEmpireShared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Theme = require(script.Parent.Theme)
local Store = require(script.Parent.Parent.Store)

local C = Theme.C
local new = Theme.new

local Hud = {}

local player = Players.LocalPlayer
local gui
local refs: any = {}
local menuButtons = {}
local displayedCash = 0

function Hud.gui()
	return gui
end

local function autoScale(screen)
	local scale = new("UIScale", { Parent = screen })
	local function update()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vp = cam.ViewportSize
		scale.Scale = math.clamp(math.min(vp.Y / 820, vp.X / 1280), 0.55, 1.15)
	end
	update()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(update)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

------------------------------------------------------------------------------
-- Barra superior
------------------------------------------------------------------------------

local function buildTopBar()
	local top = new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(560, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})

	-- Dinero
	local cash = Theme.panel({ Name = "Cash", Size = UDim2.fromOffset(270, 74), BackgroundColor3 = C.bg, LayoutOrder = 1, Parent = top, Radius = 18 })
	Theme.stroke(C.green, 3).Parent = cash
	Theme.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 215), 90).Parent = cash
	Theme.label({ Text = "💰", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(8, 9), MaxText = 44, Parent = cash })
	refs.cashLabel = Theme.label({ Name = "Amount", Text = "$0", Size = UDim2.new(1, -72, 0, 42), Position = UDim2.fromOffset(64, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.white, MaxText = 38, Parent = cash })
	Theme.textStroke(Color3.fromRGB(20, 60, 30), 2.5).Parent = refs.cashLabel
	refs.incomeLabel = Theme.label({ Name = "Income", Text = "+$0/s", Size = UDim2.new(1, -72, 0, 24), Position = UDim2.fromOffset(65, 44), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.green, MaxText = 22, Parent = cash })
	refs.cashPanel = cash

	-- Nivel de imperio
	local lvl = Theme.panel({ Name = "Level", Size = UDim2.fromOffset(270, 74), BackgroundColor3 = C.bg, LayoutOrder = 2, Parent = top, Radius = 18 })
	Theme.stroke(C.gold, 3).Parent = lvl
	Theme.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 215), 90).Parent = lvl
	Theme.label({ Text = "⭐", Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(10, 6), MaxText = 38, Parent = lvl })
	refs.levelLabel = Theme.label({ Text = "Nivel 1", Size = UDim2.new(1, -70, 0, 26), Position = UDim2.fromOffset(60, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, MaxText = 24, Parent = lvl })
	refs.titleLabel = Theme.label({ Text = "Emprendedor", Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(60, 31), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, Font = Theme.Bold, MaxText = 16, Parent = lvl })
	refs.levelBar = Theme.progressBar({ Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 54), Color = C.gold, Parent = lvl })
	refs.levelNext = Theme.label({ Text = "", Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 54), TextColor3 = C.white, Font = Theme.Bold, MaxText = 10, ZIndex = 3, Parent = lvl })
end

------------------------------------------------------------------------------
-- Menu lateral
------------------------------------------------------------------------------

local function buildMenu(handlers)
	local menu = new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.56, 0),
		Size = UDim2.fromOffset(92, 470),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.list(10).Parent = menu
	local items = {
		{ key = "empire", icon = "🏛️", text = "Imperio", color = C.blue },
		{ key = "challenges", icon = "🎯", text = "Retos", color = C.pink },
		{ key = "shop", icon = "🛒", text = "Tienda", color = C.gold },
		{ key = "plot", icon = "🏠", text = "Parcela", color = C.green },
		{ key = "plaza", icon = "⛲", text = "Plaza", color = C.purple },
	}
	for i, item in ipairs(items) do
		local btn = new("TextButton", {
			Name = item.key,
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = item.color,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			Parent = menu,
		})
		Theme.corner(20).Parent = btn
		Theme.stroke(item.color:Lerp(Color3.new(0, 0, 0), 0.35), 3).Parent = btn
		Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200), 90).Parent = btn
		Theme.label({ Text = item.icon, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 6), MaxText = 40, Parent = btn })
		local l = Theme.label({ Text = item.text, Size = UDim2.new(1, -6, 0, 22), Position = UDim2.fromOffset(3, 54), MaxText = 18, Parent = btn })
		Theme.textStroke(item.color:Lerp(Color3.new(0, 0, 0), 0.5), 2).Parent = l
		local badge = new("Frame", {
			Name = "Badge",
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(1, -18, 0, -8),
			BackgroundColor3 = C.red,
			Visible = false,
			ZIndex = 5,
			Parent = btn,
		})
		Theme.corner(13).Parent = badge
		Theme.stroke(C.white, 2).Parent = badge
		Theme.label({ Text = "!", Size = UDim2.fromScale(1, 1), ZIndex = 6, MaxText = 20, Parent = badge })
		local scale = new("UIScale", { Parent = btn })
		btn.MouseEnter:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
		btn.Activated:Connect(function()
			Theme.play("click")
			scale.Scale = 0.9
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			if handlers[item.key] then
				handlers[item.key]()
			end
		end)
		menuButtons[item.key] = btn
	end
end

function Hud.setBadge(key, visible)
	local btn = menuButtons[key]
	if btn then
		btn.Badge.Visible = visible
	end
end

function Hud.menuButton(key)
	return menuButtons[key]
end

------------------------------------------------------------------------------
-- Objetivo actual (derecha)
------------------------------------------------------------------------------

local function buildGoal(onClaim)
	local card = Theme.panel({
		Name = "Goal",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.56, 0),
		Size = UDim2.fromOffset(270, 128),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.08,
		Parent = gui,
	})
	Theme.stroke(C.blue, 2.5).Parent = card
	Theme.label({ Text = "🎯 OBJETIVO DE EXPANSIÓN", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.blue, MaxText = 16, Parent = card })
	refs.goalText = Theme.label({ Text = "", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 30), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Bold, MaxText = 18, Parent = card })
	refs.goalBar = Theme.progressBar({ Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 60), Color = C.blue, Parent = card })
	refs.goalProgress = Theme.label({ Text = "", Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 60), Font = Theme.Bold, MaxText = 12, ZIndex = 3, Parent = card })
	refs.goalButton = Theme.button({ Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 82), Color = C.grey, MaxText = 20, Parent = card, OnClick = onClaim })
	refs.goalCard = card
end

------------------------------------------------------------------------------
-- Notificaciones
------------------------------------------------------------------------------

local function buildToasts()
	local holder = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 94),
		Size = UDim2.fromOffset(460, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.list(6).Parent = holder
	refs.toasts = holder
end

function Hud.toast(text, color)
	color = color or C.blue
	local holder = refs.toasts
	if not holder then
		return
	end
	local count = 0
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("Frame") then
			count += 1
		end
	end
	if count >= 4 then
		for _, c in ipairs(holder:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
	local toast = Theme.panel({
		Size = UDim2.fromOffset(440, 42),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		LayoutOrder = math.floor(os.clock() * 100) % 1000000000,
		Parent = holder,
		Radius = 12,
	})
	Theme.stroke(color, 2.5).Parent = toast
	local accent = new("Frame", { Size = UDim2.new(0, 8, 1, -12), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = color, Parent = toast })
	Theme.corner(4).Parent = accent
	local label = Theme.label({ Text = text, Size = UDim2.new(1, -34, 1, -10), Position = UDim2.fromOffset(24, 5), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Bold, MaxText = 18, Parent = toast })
	Theme.pop(toast)
	task.delay(3.6, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			TweenService:Create(toast.UIStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			TweenService:Create(accent, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

------------------------------------------------------------------------------
-- Tutorial (tarjeta inferior)
------------------------------------------------------------------------------

local function buildTutorial(onSkip)
	local card = Theme.panel({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(560, 92),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
		Radius = 18,
	})
	Theme.stroke(C.gold, 3).Parent = card
	refs.tutStep = Theme.label({ Text = "PASO 1/7", Size = UDim2.fromOffset(120, 20), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, MaxText = 16, Parent = card })
	refs.tutText = Theme.label({ Text = "", Size = UDim2.new(1, -130, 0, 54), Position = UDim2.fromOffset(14, 30), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Bold, TextWrapped = true, MaxText = 20, Parent = card })
	Theme.button({ Text = "Saltar", Size = UDim2.fromOffset(92, 34), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Color = C.greyDark, MaxText = 18, Parent = card, OnClick = onSkip })
	refs.tutCard = card
end

function Hud.setTutorial(stepIndex, total, text)
	local card = refs.tutCard
	if not text then
		card.Visible = false
		return
	end
	local changed = refs.tutText.Text ~= text
	card.Visible = true
	refs.tutStep.Text = string.format("PASO %d/%d", stepIndex, total)
	refs.tutText.Text = text
	if changed then
		Theme.pop(card)
	end
end

------------------------------------------------------------------------------
-- Ventana de ganancias offline / mensajes grandes
------------------------------------------------------------------------------

function Hud.modal(title, body, buttonText, color)
	local shade = new("Frame", {
		Name = "Modal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 50,
		Parent = gui,
	})
	local card = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 250),
		BackgroundColor3 = C.bg,
		ZIndex = 51,
		Parent = shade,
		Radius = 22,
	})
	Theme.stroke(color or C.gold, 4).Parent = card
	Theme.label({ Text = title, Size = UDim2.new(1, -30, 0, 46), Position = UDim2.fromOffset(15, 16), TextColor3 = color or C.gold, ZIndex = 52, MaxText = 34, Parent = card })
	Theme.label({ Text = body, Size = UDim2.new(1, -40, 0, 100), Position = UDim2.fromOffset(20, 68), Font = Theme.Bold, TextWrapped = true, ZIndex = 52, MaxText = 24, Parent = card })
	local btn = Theme.button({
		Text = buttonText or "¡Genial!",
		Size = UDim2.fromOffset(200, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Color = C.green,
		Parent = card,
		OnClick = function()
			shade:Destroy()
		end,
	})
	btn.ZIndex = 52
	btn.Label.ZIndex = 53
	Theme.pop(card)
	return shade
end

------------------------------------------------------------------------------
-- Actualizacion
------------------------------------------------------------------------------

local function refreshGoal(state)
	local goal = Economy.currentGoal(state)
	if not goal then
		refs.goalText.Text = "¡Todos los objetivos completados! 🏆"
		Theme.setProgress(refs.goalBar, 1)
		refs.goalProgress.Text = ""
		Theme.setButton(refs.goalButton, "Completado", C.grey)
		Hud.setBadge("challenges", false)
		return false
	end
	local progress = Economy.goalProgress(state, goal)
	local done = progress >= goal.target
	refs.goalText.Text = goal.text
	Theme.setProgress(refs.goalBar, progress / goal.target, true)
	refs.goalProgress.Text = string.format("%d / %d", math.min(progress, goal.target), goal.target)
	if done then
		Theme.setButton(refs.goalButton, "🎁 Reclamar " .. Format.cash(goal.reward), C.green)
	else
		Theme.setButton(refs.goalButton, "Premio: " .. Format.cash(goal.reward), C.greyDark)
	end
	return done
end

local function refreshLevel()
	local state = Store.state
	if not state then
		return
	end
	local level, info, nextInfo, progress = Economy.empireLevel(state.runEarned)
	refs.levelLabel.Text = "Nivel " .. level
	refs.titleLabel.Text = info.title
	Theme.setProgress(refs.levelBar, progress)
	if nextInfo then
		refs.levelNext.Text = Format.cash(state.runEarned) .. " / " .. Format.cash(nextInfo.need)
	else
		refs.levelNext.Text = "¡NIVEL MÁXIMO!"
	end
	if refs.lastLevel and level > refs.lastLevel then
		Hud.toast("⭐ ¡Nivel de imperio " .. level .. ": " .. info.title .. "!", C.gold)
		Theme.play("levelup")
		Theme.pop(refs.levelLabel.Parent)
	end
	refs.lastLevel = level
end

function Hud.refresh(state)
	local goalDone = refreshGoal(state)
	local dailyReady = false
	if state.daily then
		for _, c in ipairs(state.daily.list) do
			if not c.claimed and c.progress >= c.target then
				dailyReady = true
			end
		end
	end
	Hud.setBadge("challenges", goalDone or dailyReady)
	-- Algo asequible en el menu Imperio
	local affordable = false
	for _, u in ipairs(Config.Upgrades) do
		if Economy.upgradeState(state, u.id) == "available" and state.cash >= u.cost then
			affordable = true
			break
		end
	end
	Hud.setBadge("empire", affordable)
	refreshLevel()
end

function Hud.init(handlers)
	gui = new("ScreenGui", {
		Name = "TinyEmpireHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	autoScale(gui)
	buildTopBar()
	buildMenu(handlers)
	buildGoal(handlers.claimGoal)
	buildToasts()
	buildTutorial(handlers.skipTutorial)

	-- Contador animado de dinero
	RunService.RenderStepped:Connect(function(dt)
		local target = Store.cash
		if math.abs(target - displayedCash) < 0.5 then
			displayedCash = target
		else
			displayedCash += (target - displayedCash) * math.min(1, dt * 8)
		end
		refs.cashLabel.Text = Format.cash(displayedCash)
	end)
	Store.Ticked:Connect(function()
		refs.incomeLabel.Text = "+" .. Format.cash(Store.income) .. "/s"
		refreshLevel()
		if Store.state then
			Hud.refresh(Store.state)
		end
	end)
end

-- Pequeno rebote del contador al ganar dinero
function Hud.bumpCash()
	if refs.cashPanel then
		Theme.pop(refs.cashPanel)
	end
end

function Hud.cashPanel()
	return refs.cashPanel
end

return Hud
