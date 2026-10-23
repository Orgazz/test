--!nonstrict
-- Ventanas: Imperio (negocios, mejoras, expansion), Retos y Tienda.

local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TinyEmpireShared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Theme = require(script.Parent.Theme)
local Store = require(script.Parent.Parent.Store)

local C = Theme.C
local new = Theme.new

local Panels = {}

local gui
local actions -- callbacks hacia Main
local windows = {} -- [key] = window
local openKey = nil
local refreshers = {} -- funciones de refresco por ventana

------------------------------------------------------------------------------
-- Ventana generica con pestanas
------------------------------------------------------------------------------

local function makeWindow(key, title, color, tabNames)
	local shade = new("TextButton", {
		Name = key .. "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local frame = Theme.panel({
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(720, 520),
		BackgroundColor3 = C.bg,
		Active = true,
		Parent = shade,
		Radius = 22,
	})
	Theme.stroke(color, 4).Parent = frame
	new("UIScale", { Parent = frame })
	-- Cabecera
	local header = Theme.panel({ Name = "Header", Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = color, Parent = frame, Radius = 20 })
	Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 195), 90).Parent = header
	local titleLabel = Theme.label({ Text = title, Size = UDim2.new(1, -140, 0, 44), Position = UDim2.fromOffset(20, 9), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 34, Parent = header })
	Theme.textStroke(color:Lerp(Color3.new(0, 0, 0), 0.5), 2.5).Parent = titleLabel
	Theme.button({
		Text = "✕",
		Size = UDim2.fromOffset(48, 44),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Color = C.red,
		MaxText = 26,
		Parent = header,
		OnClick = function()
			Panels.close()
		end,
	})
	-- Pestanas
	local tabBar = new("Frame", { Name = "Tabs", Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 70), BackgroundTransparency = 1, Parent = frame })
	Theme.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left).Parent = tabBar
	local pages = {}
	local tabButtons = {}
	local win = { shade = shade, frame = frame, pages = pages, tabs = tabButtons, color = color, current = nil }
	local function select(name)
		win.current = name
		for n, page in pairs(pages) do
			page.Visible = n == name
		end
		for n, b in pairs(tabButtons) do
			Theme.setButton(b, b.Label.Text, n == name and color or C.bg3)
		end
	end
	win.select = select
	for i, name in ipairs(tabNames) do
		local page = new("ScrollingFrame", {
			Name = name,
			Size = UDim2.new(1, -24, 1, -128),
			Position = UDim2.fromOffset(12, 118),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = color,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = i == 1,
			Parent = frame,
		})
		Theme.list(10).Parent = page
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = page })
		pages[name] = page
		if #tabNames > 1 then
			tabButtons[name] = Theme.button({
				Text = name,
				Size = UDim2.fromOffset(150, 40),
				Color = i == 1 and color or C.bg3,
				MaxText = 20,
				LayoutOrder = i,
				Parent = tabBar,
				OnClick = function()
					select(name)
				end,
			})
		end
	end
	if #tabNames <= 1 then
		for _, page in pairs(pages) do
			page.Position = UDim2.fromOffset(12, 74)
			page.Size = UDim2.new(1, -24, 1, -84)
		end
	end
	win.current = tabNames[1]
	windows[key] = win
	return win
end

local function card(parent, height, order, accent)
	local f = Theme.panel({ Size = UDim2.new(1, -4, 0, height), BackgroundColor3 = C.bg2, LayoutOrder = order, Parent = parent, Radius = 14 })
	Theme.stroke(accent or C.bg3, 2).Parent = f
	return f
end

local function iconBox(parent, icon, color, size)
	local box = Theme.panel({ Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = color, Parent = parent, Radius = 14 })
	Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 180), 120).Parent = box
	Theme.label({ Name = "Emoji", Text = icon, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), MaxText = 48, Parent = box })
	return box
end

-- Usa la imagen oficial del pase/producto (subida en el Creator Dashboard) si existe
local iconCache = {}
local function useStoreIcon(box, assetId, infoType)
	if not assetId or assetId <= 0 or box:GetAttribute("IconLoaded") then
		return
	end
	box:SetAttribute("IconLoaded", true)
	task.spawn(function()
		local image = iconCache[assetId]
		if not image then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(assetId, infoType)
			end)
			if ok and info and info.IconImageAssetId and info.IconImageAssetId > 0 then
				image = "rbxassetid://" .. info.IconImageAssetId
				iconCache[assetId] = image
			end
		end
		if image and box.Parent then
			new("ImageLabel", {
				Name = "StoreIcon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
				Parent = box,
			})
			Theme.corner(14).Parent = box.StoreIcon
			box.Emoji.Visible = false
		end
	end)
end

local function sectionHeader(parent, text, order, color)
	local l = Theme.label({ Text = text, Size = UDim2.new(1, -4, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or C.gold, LayoutOrder = order, MaxText = 24, Parent = parent })
	return l
end

local function stars(level)
	local s = ""
	for i = 1, Config.MaxBusinessLevel do
		s ..= (i <= level) and "★" or "☆"
	end
	return s
end

------------------------------------------------------------------------------
-- IMPERIO
------------------------------------------------------------------------------

local function buildEmpire()
	local win = makeWindow("empire", "🏛️ Tu Imperio", C.blue, { "Negocios", "Mejoras", "Expansión" })
	local bizCards = {}
	for i, b in ipairs(Config.Businesses) do
		local f = card(win.pages["Negocios"], 92, i)
		iconBox(f, b.icon, b.color, 72)
		local name = Theme.label({ Text = b.name, Size = UDim2.new(1, -280, 0, 28), Position = UDim2.fromOffset(94, 8), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = f })
		local starsLabel = Theme.label({ Text = "", Size = UDim2.fromOffset(120, 22), Position = UDim2.fromOffset(94, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, Font = Theme.Bold, MaxText = 20, Parent = f })
		local info = Theme.label({ Text = "", Size = UDim2.new(1, -280, 0, 22), Position = UDim2.fromOffset(94, 60), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, Font = Theme.Bold, MaxText = 17, Parent = f })
		local btn = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(170, 52),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			MaxText = 20,
			Parent = f,
			OnClick = function()
				local st = Store.state and Economy.businessState(Store.state, b.id)
				if st == "owned" then
					actions.fire("upgradeBusiness", b.id)
				else
					actions.fire("buyBusiness", b.id)
				end
			end,
		})
		bizCards[b.id] = { frame = f, name = name, stars = starsLabel, info = info, btn = btn }
	end

	local upCards = {}
	local order = 0
	for _, tier in ipairs(Config.UpgradeTiers) do
		order += 1
		local header = sectionHeader(win.pages["Mejoras"], "Nivel " .. tier.tier .. " · " .. tier.name, order, C.purple)
		local grid = new("Frame", { Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 0.5, Parent = win.pages["Mejoras"] })
		order += 1
		grid.LayoutOrder = order
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 112), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		for _, u in ipairs(Config.Upgrades) do
			if u.tier == tier.tier then
				local f = Theme.panel({ BackgroundColor3 = C.bg2, LayoutOrder = u.order, Parent = grid, Radius = 14 })
				Theme.stroke(C.bg3, 2).Parent = f
				iconBox(f, u.icon, C.purple, 52)
				Theme.label({ Text = u.name, Size = UDim2.new(1, -78, 0, 24), Position = UDim2.fromOffset(70, 8), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 19, Parent = f })
				Theme.label({ Text = u.desc, Size = UDim2.new(1, -78, 0, 32), Position = UDim2.fromOffset(70, 32), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.muted, Font = Theme.Bold, TextWrapped = true, MaxText = 14, Parent = f })
				local btn = Theme.button({
					Text = "",
					Size = UDim2.new(1, -20, 0, 36),
					Position = UDim2.new(0, 10, 1, -44),
					MaxText = 18,
					Parent = f,
					OnClick = function()
						actions.fire("buyUpgrade", u.id)
					end,
				})
				upCards[u.id] = { frame = f, btn = btn }
			end
		end
		local _ = header
	end

	-- Expansion y franquicia
	local expCards = {}
	for i, exp in ipairs(Config.Expansions) do
		local f = card(win.pages["Expansión"], 96, i, C.gold)
		iconBox(f, i == 1 and "🏪" or "🏙️", C.gold, 76)
		Theme.label({ Text = exp.name, Size = UDim2.new(1, -290, 0, 30), Position = UDim2.fromOffset(98, 10), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = f })
		local names = {}
		for _, b in ipairs(Config.Businesses) do
			if b.zone == i + 1 then
				table.insert(names, b.icon .. " " .. b.name)
			end
		end
		Theme.label({ Text = "Desbloquea: " .. table.concat(names, ", "), Size = UDim2.new(1, -290, 0, 40), Position = UDim2.fromOffset(98, 44), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextColor3 = C.muted, Font = Theme.Bold, MaxText = 15, Parent = f })
		local btn = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(170, 52),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			MaxText = 20,
			Parent = f,
			OnClick = function()
				actions.fire("buyExpansion", i)
			end,
		})
		expCards[i] = { btn = btn }
	end
	local fr = card(win.pages["Expansión"], 120, 10, C.purple)
	iconBox(fr, "🌟", C.purple, 76)
	Theme.label({ Text = "Franquicia", Size = UDim2.new(1, -290, 0, 30), Position = UDim2.fromOffset(98, 10), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = fr })
	local frInfo = Theme.label({ Text = "", Size = UDim2.new(1, -290, 0, 66), Position = UDim2.fromOffset(98, 44), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextColor3 = C.muted, Font = Theme.Bold, MaxText = 15, Parent = fr })
	local frBtn = Theme.button({
		Text = "",
		Size = UDim2.fromOffset(170, 52),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		MaxText = 20,
		Parent = fr,
		OnClick = function()
			actions.confirm("🌟 ¿Abrir una franquicia?", "Reinicias negocios, mejoras y dinero a cambio de un bonus PERMANENTE de ingresos. Los objetivos y retos se mantienen.", function()
				actions.fire("franchise")
			end)
		end,
	})

	refreshers.empire = function(state)
		local x2 = state.passes and state.passes.x2
		for _, b in ipairs(Config.Businesses) do
			local c = bizCards[b.id]
			local st, reason = Economy.businessState(state, b.id)
			local level = state.businesses[b.id] or 0
			if st == "owned" then
				c.stars.Text = stars(level)
				local income = Economy.businessIncome(state, b.id, x2)
				local cost = Economy.levelUpCost(b.id, level)
				if cost then
					local nextIncome = Economy.baseIncomeAt(b.id, level + 1) * Economy.businessMultiplier(state, b.id) * Economy.globalMultiplier(state, x2)
					c.info.Text = string.format("💰 %s/s  →  %s/s", Format.cash(income), Format.cash(nextIncome))
					Theme.setButton(c.btn, "⬆️ " .. Format.cash(cost), state.cash >= cost and C.blue or C.greyDark)
				else
					c.info.Text = string.format("💰 %s/s  ·  ¡Nivel máximo!", Format.cash(income))
					Theme.setButton(c.btn, "⭐ MÁX", C.gold)
				end
				c.frame.UIStroke.Color = C.bg3
			elseif st == "available" then
				c.stars.Text = "Nuevo negocio"
				local income = Economy.baseIncomeAt(b.id, 1) * Economy.businessMultiplier(state, b.id) * Economy.globalMultiplier(state, x2)
				c.info.Text = string.format("💰 %s/s  ·  %s", Format.cash(income), b.desc)
				Theme.setButton(c.btn, b.cost == 0 and "¡GRATIS!" or ("🔨 " .. Format.cash(b.cost)), state.cash >= b.cost and C.green or C.greyDark)
				c.frame.UIStroke.Color = state.cash >= b.cost and C.green or C.bg3
			else
				c.stars.Text = "🔒 Bloqueado"
				c.info.Text = reason or ""
				Theme.setButton(c.btn, "🔒", C.grey)
				c.frame.UIStroke.Color = C.bg3
			end
		end
		for _, u in ipairs(Config.Upgrades) do
			local c = upCards[u.id]
			local st, reason = Economy.upgradeState(state, u.id)
			if st == "owned" then
				Theme.setButton(c.btn, "✔ Comprada", C.greenDark)
				c.frame.UIStroke.Color = C.green
			elseif st == "available" then
				Theme.setButton(c.btn, Format.cash(u.cost), state.cash >= u.cost and C.purple or C.greyDark)
				c.frame.UIStroke.Color = state.cash >= u.cost and C.purple or C.bg3
			else
				Theme.setButton(c.btn, "🔒 " .. (reason or ""), C.grey)
				c.frame.UIStroke.Color = C.bg3
			end
		end
		for i, exp in ipairs(Config.Expansions) do
			local st, reason = Economy.expansionState(state, i)
			local btn = expCards[i].btn
			if st == "owned" then
				Theme.setButton(btn, "✔ Desbloqueado", C.greenDark)
			elseif st == "available" then
				Theme.setButton(btn, "🚧 " .. Format.cash(exp.cost), state.cash >= exp.cost and C.gold or C.greyDark)
			else
				Theme.setButton(btn, "🔒 " .. (reason or ""), C.grey)
			end
		end
		local bonusNow = (state.franchises or 0) * Config.Franchise.bonusPerFranchise
		frInfo.Text = string.format(
			"Requiere Torre Corporativa y %s ganados en esta partida. Cada franquicia da %s de ingresos para siempre. Bonus actual: %s.",
			Format.cash(Config.Franchise.needEarned),
			Format.percent(Config.Franchise.bonusPerFranchise),
			Format.percent(bonusNow)
		)
		if state.canFranchise then
			Theme.setButton(frBtn, "🌟 Franquiciar", C.purple)
		else
			Theme.setButton(frBtn, "🔒 Bloqueado", C.grey)
		end
	end
end

------------------------------------------------------------------------------
-- RETOS
------------------------------------------------------------------------------

local function buildChallenges()
	local win = makeWindow("challenges", "🎯 Retos y Objetivos", C.pink, { "Diarios", "Objetivos" })
	local page = win.pages["Diarios"]
	local resetLabel = sectionHeader(page, "", 0, C.pink)
	local dailyCards = {}
	for i = 1, Config.DailyCount do
		local f = card(page, 100, i)
		iconBox(f, "📅", C.pink, 70)
		local text = Theme.label({ Text = "", Size = UDim2.new(1, -290, 0, 28), Position = UDim2.fromOffset(92, 10), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 21, Parent = f })
		local bar = Theme.progressBar({ Size = UDim2.new(1, -290, 0, 18), Position = UDim2.fromOffset(92, 44), Color = C.pink, Parent = f })
		local prog = Theme.label({ Text = "", Size = UDim2.new(1, -290, 0, 18), Position = UDim2.fromOffset(92, 44), Font = Theme.Bold, ZIndex = 3, MaxText = 14, Parent = f })
		local reward = Theme.label({ Text = "", Size = UDim2.new(1, -290, 0, 20), Position = UDim2.fromOffset(92, 68), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, Font = Theme.Bold, MaxText = 16, Parent = f })
		local btn = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(170, 52),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			MaxText = 20,
			Parent = f,
			OnClick = function()
				actions.fire("claimDaily", i)
			end,
		})
		dailyCards[i] = { text = text, bar = bar, prog = prog, reward = reward, btn = btn, frame = f }
	end
	local bonusLabel = Theme.label({ Text = "🔥 Completa los 3 retos para ganar un BONUS igual a la suma de sus premios.", Size = UDim2.new(1, -4, 0, 40), TextWrapped = true, Font = Theme.Bold, TextColor3 = C.gold, LayoutOrder = 10, MaxText = 17, Parent = page })

	local goalsPage = win.pages["Objetivos"]
	sectionHeader(goalsPage, "Completa objetivos para hacer crecer tu imperio", 0, C.blue)
	local goalRows = {}
	for i, goal in ipairs(Config.Goals) do
		local f = card(goalsPage, 64, i)
		local icon = Theme.label({ Text = "🔒", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 10), MaxText = 32, Parent = f })
		local text = Theme.label({ Text = goal.text, Size = UDim2.new(1, -280, 0, 26), Position = UDim2.fromOffset(62, 6), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = f })
		local sub = Theme.label({ Text = "Premio: " .. Format.cash(goal.reward), Size = UDim2.new(1, -280, 0, 20), Position = UDim2.fromOffset(62, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, Font = Theme.Bold, MaxText = 15, Parent = f })
		local btn = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(170, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			MaxText = 18,
			Parent = f,
			OnClick = function()
				actions.fire("claimGoal")
			end,
		})
		goalRows[i] = { icon = icon, text = text, sub = sub, btn = btn, frame = f }
	end

	refreshers.challenges = function(state)
		resetLabel.Text = "⏰ Nuevos retos en " .. Format.time(state.dailyReset or 0)
		local list = state.daily and state.daily.list or {}
		for i, c in ipairs(dailyCards) do
			local d = list[i]
			if d then
				c.frame.Visible = true
				c.text.Text = d.text
				Theme.setProgress(c.bar, d.progress / d.target)
				if d.kind == "earn" then
					c.prog.Text = Format.cash(d.progress) .. " / " .. Format.cash(d.target)
				else
					c.prog.Text = string.format("%d / %d", math.floor(d.progress), d.target)
				end
				c.reward.Text = "🎁 Premio: " .. Format.cash(d.reward)
				if d.claimed then
					Theme.setButton(c.btn, "✔ Reclamado", C.greenDark)
					c.frame.UIStroke.Color = C.bg3
				elseif d.progress >= d.target then
					Theme.setButton(c.btn, "🎁 Reclamar", C.green)
					c.frame.UIStroke.Color = C.green
				else
					Theme.setButton(c.btn, "En progreso", C.greyDark)
					c.frame.UIStroke.Color = C.bg3
				end
			else
				c.frame.Visible = false
			end
		end
		if state.daily and state.daily.bonusClaimed then
			bonusLabel.Text = "🔥 ¡Bonus diario conseguido! Vuelve mañana para más retos."
		end
		local current, currentIndex = Economy.currentGoal(state)
		for i, goal in ipairs(Config.Goals) do
			local row = goalRows[i]
			if state.goalsClaimed[goal.id] then
				row.icon.Text = "✅"
				Theme.setButton(row.btn, "✔ Hecho", C.greenDark)
				row.frame.UIStroke.Color = C.bg3
			elseif current and i == currentIndex then
				local p = Economy.goalProgress(state, goal)
				row.icon.Text = "🎯"
				if p >= goal.target then
					Theme.setButton(row.btn, "🎁 Reclamar", C.green)
					row.frame.UIStroke.Color = C.green
				else
					Theme.setButton(row.btn, string.format("%d / %d", math.min(p, goal.target), goal.target), C.blue)
					row.frame.UIStroke.Color = C.blue
				end
			else
				row.icon.Text = "🔒"
				Theme.setButton(row.btn, "Próximamente", C.grey)
				row.frame.UIStroke.Color = C.bg3
			end
		end
	end
end

------------------------------------------------------------------------------
-- TIENDA
------------------------------------------------------------------------------

local function buildShop()
	local win = makeWindow("shop", "🛒 Tienda", C.gold, { "Tienda" })
	local page = win.pages["Tienda"]
	local note = Theme.label({
		Text = "",
		Size = UDim2.new(1, -4, 0, 36),
		TextWrapped = true,
		Font = Theme.Bold,
		TextColor3 = C.muted,
		LayoutOrder = 0,
		MaxText = 15,
		Parent = page,
	})
	sectionHeader(page, "⭐ Pases (para siempre)", 1, C.gold)
	local passCards = {}
	for i, key in ipairs(Config.GamePassOrder) do
		local p = Config.GamePasses[key]
		local f = card(page, 100, 1 + i, C.gold)
		local passIcon = iconBox(f, p.icon, C.gold, 76)
		useStoreIcon(passIcon, p.id, Enum.InfoType.GamePass)
		Theme.label({ Text = p.name, Size = UDim2.new(1, -300, 0, 28), Position = UDim2.fromOffset(98, 10), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 23, Parent = f })
		Theme.label({ Text = p.desc, Size = UDim2.new(1, -300, 0, 48), Position = UDim2.fromOffset(98, 42), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextColor3 = C.muted, Font = Theme.Bold, MaxText = 15, Parent = f })
		local btn = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(180, 50),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			MaxText = 20,
			Parent = f,
			OnClick = function()
				local state = Store.state
				if state and state.passes[key] then
					if key == "decor" or key == "theme" then
						actions.fire("setting", key, state.settings[key] == false)
					end
					return
				end
				actions.buyPass(key)
			end,
		})
		passCards[key] = { btn = btn }
	end
	sectionHeader(page, "💵 Paquetes de efectivo", 5, C.green)
	local productCards = {}
	for i, key in ipairs(Config.ProductOrder) do
		local p = Config.Products[key]
		local f = card(page, 92, 5 + i, C.green)
		local productIcon = iconBox(f, p.icon, C.green, 70)
		useStoreIcon(productIcon, p.id, Enum.InfoType.Product)
		Theme.label({ Text = p.name, Size = UDim2.new(1, -300, 0, 28), Position = UDim2.fromOffset(92, 10), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 23, Parent = f })
		local amount = Theme.label({ Text = "", Size = UDim2.new(1, -300, 0, 40), Position = UDim2.fromOffset(92, 42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.green, MaxText = 26, Parent = f })
		local btn = Theme.button({
			Text = "",
			Size = UDim2.fromOffset(180, 50),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Color = C.green,
			MaxText = 20,
			Parent = f,
			OnClick = function()
				actions.buyProduct(key)
			end,
		})
		productCards[key] = { amount = amount, btn = btn }
	end
	Theme.label({
		Text = "Las compras solo mejoran TU parcela y nunca afectan a otros jugadores. Todo el progreso principal se puede conseguir gratis jugando. 💚",
		Size = UDim2.new(1, -4, 0, 44),
		TextWrapped = true,
		Font = Theme.Bold,
		TextColor3 = C.muted,
		LayoutOrder = 20,
		MaxText = 15,
		Parent = page,
	})

	refreshers.shop = function(state)
		if state.simulation then
			note.Text = "🧪 Modo Studio: los artículos sin ID real se simulan para que puedas probarlos."
		else
			note.Text = "Apoya el juego y consigue extras cosméticos o atajos opcionales."
		end
		for key, c in pairs(passCards) do
			local p = Config.GamePasses[key]
			if state.passes[key] then
				if key == "decor" or key == "theme" then
					local on = state.settings[key] ~= false
					Theme.setButton(c.btn, on and "✔ Activado" or "Desactivado", on and C.greenDark or C.greyDark)
				else
					Theme.setButton(c.btn, "✔ Activo", C.greenDark)
				end
			elseif (p.id or 0) > 0 or state.simulation then
				Theme.setButton(c.btn, "R$ " .. p.price, C.gold)
			else
				Theme.setButton(c.btn, "Próximamente", C.grey)
			end
		end
		for key, c in pairs(productCards) do
			local p = Config.Products[key]
			c.amount.Text = "+" .. Format.cash(Economy.productReward(state, key, state.passes.x2))
			if (p.id or 0) > 0 or state.simulation then
				Theme.setButton(c.btn, "R$ " .. p.price, C.green)
			else
				Theme.setButton(c.btn, "Próximamente", C.grey)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Confirmacion
------------------------------------------------------------------------------

function Panels.confirm(title, body, onYes)
	local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, ZIndex = 60, Parent = gui })
	local f = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 250), BackgroundColor3 = C.bg, ZIndex = 61, Parent = shade, Radius = 20 })
	Theme.stroke(C.purple, 4).Parent = f
	Theme.label({ Text = title, Size = UDim2.new(1, -30, 0, 40), Position = UDim2.fromOffset(15, 14), TextColor3 = C.purple, ZIndex = 62, MaxText = 28, Parent = f })
	Theme.label({ Text = body, Size = UDim2.new(1, -40, 0, 100), Position = UDim2.fromOffset(20, 60), TextWrapped = true, Font = Theme.Bold, ZIndex = 62, MaxText = 19, Parent = f })
	local yes = Theme.button({ Text = "Sí", Size = UDim2.fromOffset(180, 48), Position = UDim2.new(0.5, 10, 1, -64), Color = C.purple, Parent = f, OnClick = function()
		shade:Destroy()
		onYes()
	end })
	local no = Theme.button({ Text = "Cancelar", Size = UDim2.fromOffset(180, 48), Position = UDim2.new(0.5, -190, 1, -64), Color = C.greyDark, Parent = f, OnClick = function()
		shade:Destroy()
	end })
	for _, b in ipairs({ yes, no }) do
		b.ZIndex = 62
		b.Label.ZIndex = 63
	end
	Theme.pop(f)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function Panels.open(key, tab)
	if openKey == key and not tab then
		Panels.close()
		return
	end
	Panels.close()
	local win = windows[key]
	if not win then
		return
	end
	openKey = key
	win.shade.Visible = true
	if tab and win.pages[tab] then
		win.select(tab)
	end
	local scale = win.frame:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.7
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if Store.state and refreshers[key] then
		refreshers[key](Store.state)
	end
	if actions.onOpen then
		actions.onOpen(key)
	end
end

function Panels.close()
	if openKey and windows[openKey] then
		windows[openKey].shade.Visible = false
	end
	openKey = nil
end

function Panels.isOpen(key)
	return openKey == key
end

function Panels.refresh(state)
	if openKey and refreshers[openKey] then
		refreshers[openKey](state)
	end
end

function Panels.init(screenGui, callbacks)
	gui = screenGui
	actions = callbacks
	actions.confirm = Panels.confirm
	buildEmpire()
	buildChallenges()
	buildShop()
	for _, win in pairs(windows) do
		win.shade.Activated:Connect(function()
			Panels.close()
		end)
	end
	Store.Ticked:Connect(function()
		if Store.state then
			Panels.refresh(Store.state)
		end
	end)
end

return Panels
