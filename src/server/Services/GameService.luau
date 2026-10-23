--!nonstrict
-- Nucleo del juego: estado de cada jugador, economia automatica, acciones
-- validadas en el servidor, tutorial, objetivos y sincronizacion con el cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.TinyEmpireShared.Config)
local Economy = require(ReplicatedStorage.TinyEmpireShared.Economy)
local Format = require(ReplicatedStorage.TinyEmpireShared.Format)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ChallengeService = require(script.Parent.ChallengeService)
local MonetizationService = require(script.Parent.MonetizationService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local DayNightService = require(script.Parent.DayNightService)

local GameService = {}

local states = {} -- [Player] = state
local remotes = nil

local COLORS = {
	good = Color3.fromRGB(90, 220, 120),
	bad = Color3.fromRGB(255, 95, 95),
	info = Color3.fromRGB(110, 180, 255),
	gold = Color3.fromRGB(255, 205, 60),
	purple = Color3.fromRGB(190, 120, 255),
}

-- Pasos del tutorial (el cliente muestra texto y flecha guia)
GameService.TutorialSteps = 7
local TUTORIAL_DONE = 99

------------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------------

local function notify(player, text, color, sound)
	if remotes and player.Parent then
		remotes.Notify:FireClient(player, { text = text, color = color or COLORS.info, sound = sound })
	end
end

local function effect(player, payload)
	if remotes and player.Parent then
		remotes.Effect:FireClient(player, payload)
	end
end

local function hasX2(state)
	return state.passes.x2 == true
end

local function snapshot(state)
	local data = state.data
	local level, info, nextInfo, progress = Economy.empireLevel(data.runEarned)
	return {
		cash = data.cash,
		income = Economy.totalIncome(data, hasX2(state)),
		runEarned = data.runEarned,
		lifetimeEarned = data.lifetimeEarned,
		empireLevel = level,
		empireTitle = info.title,
		nextLevelNeed = nextInfo and nextInfo.need or nil,
		levelProgress = progress,
		businesses = data.businesses,
		upgrades = data.upgrades,
		expansions = data.expansions,
		franchises = data.franchises,
		goalsClaimed = data.goalsClaimed,
		tutorial = data.tutorial,
		daily = data.daily,
		dailyReset = ChallengeService.secondsUntilReset(),
		stats = data.stats,
		passes = state.passes,
		settings = data.settings,
		plotIndex = state.plot and state.plot.index or nil,
		simulation = MonetizationService.simulationAllowed(),
		persistent = DataService.isPersistent(state.player),
		canFranchise = Economy.canFranchise(data),
		crateReward = Economy.crateReward(data, hasX2(state)),
	}
end

local function markDirty(state)
	state.dirty = true
end

local function sync(state)
	if not state.ready or not state.player.Parent then
		return
	end
	remotes.State:FireClient(state.player, snapshot(state))
	state.dirty = false
end

local function earn(state, amount)
	local data = state.data
	data.cash += amount
	data.runEarned += amount
	data.lifetimeEarned += amount
	if ChallengeService.progress(state, "earn", amount) then
		notify(state.player, "🎯 ¡Reto diario completado! Reclámalo en Retos.", COLORS.gold, "success")
		markDirty(state)
	end
end

-- Gasto seguro: devuelve true si habia dinero suficiente
local function spend(state, amount)
	if amount < 0 or state.data.cash < amount then
		return false
	end
	state.data.cash -= amount
	return true
end

local function refreshVisuals(state)
	if state.plot then
		PlotService.updateIncomeAttributes(state.plot, state)
		PlotService.updatePads(state.plot, state)
		PlotService.updateStats(state.plot, state, Economy.totalIncome(state.data, hasX2(state)))
	end
end

------------------------------------------------------------------------------
-- Tutorial
------------------------------------------------------------------------------

local function checkTutorial(state)
	local data = state.data
	local step = data.tutorial
	if step >= TUTORIAL_DONE then
		return
	end
	local advanced = false
	local function advance(nextStep)
		data.tutorial = nextStep
		step = nextStep
		advanced = true
	end
	for _ = 1, 8 do
		local before = step
		if step == 1 and (data.businesses.lemonade or 0) > 0 then
			advance(2)
		elseif step == 2 and (data.cash >= Config.BusinessById.foodtruck.cost or (data.businesses.foodtruck or 0) > 0) then
			advance(3)
		elseif step == 3 and (data.businesses.foodtruck or 0) > 0 then
			advance(4)
		elseif step == 4 and Economy.maxBusinessLevel(data) >= 2 then
			advance(5)
		elseif step == 5 and Economy.upgradeCount(data) >= 1 then
			advance(6)
		elseif step == 6 and state.flags.openedChallenges then
			advance(7)
		elseif step == 7 and state.flags.visitedPlaza then
			advance(TUTORIAL_DONE)
			earn(state, 500)
			notify(state.player, "🎓 ¡Tutorial completado! +$500 de regalo.", COLORS.gold, "success")
			effect(state.player, { kind = "confetti" })
		end
		if step == before then
			break
		end
	end
	if advanced then
		markDirty(state)
	end
end

------------------------------------------------------------------------------
-- Acciones del jugador
------------------------------------------------------------------------------

local Actions = {}

function Actions.buyBusiness(state, id)
	if type(id) ~= "string" then
		return
	end
	local b = Config.BusinessById[id]
	if not b then
		return
	end
	local st, reason = Economy.businessState(state.data, id)
	if st == "owned" then
		Actions.upgradeBusiness(state, id)
		return
	end
	if st ~= "available" then
		notify(state.player, "🔒 " .. (reason or "Bloqueado"), COLORS.bad, "error")
		return
	end
	if not spend(state, b.cost) then
		notify(state.player, "💸 Te faltan " .. Format.cash(b.cost - state.data.cash), COLORS.bad, "error")
		return
	end
	state.data.businesses[id] = 1
	state.data.stats.builds += 1
	ChallengeService.progress(state, "builds", 1)
	if state.plot then
		PlotService.buildBusiness(state.plot, state, id, true)
		DayNightService.applyTo(state.plot.model.Buildings)
	end
	notify(state.player, b.icon .. " ¡Has abierto " .. b.name .. "!", COLORS.good, "build")
	effect(state.player, { kind = "build", id = id })
	refreshVisuals(state)
	checkTutorial(state)
	markDirty(state)
end

function Actions.upgradeBusiness(state, id)
	if type(id) ~= "string" then
		return
	end
	local b = Config.BusinessById[id]
	local level = state.data.businesses[id] or 0
	if not b or level <= 0 then
		return
	end
	local cost = Economy.levelUpCost(id, level)
	if not cost then
		notify(state.player, "⭐ " .. b.name .. " ya está al nivel máximo", COLORS.info)
		return
	end
	if not spend(state, cost) then
		notify(state.player, "💸 Te faltan " .. Format.cash(cost - state.data.cash), COLORS.bad, "error")
		return
	end
	state.data.businesses[id] = level + 1
	state.data.stats.levelUps += 1
	state.data.stats.builds += 1
	ChallengeService.progress(state, "levelUps", 1)
	ChallengeService.progress(state, "builds", 1)
	if state.plot then
		PlotService.buildBusiness(state.plot, state, id, true)
		DayNightService.applyTo(state.plot.model.Buildings)
	end
	notify(state.player, "⬆️ " .. b.name .. " sube a nivel " .. (level + 1) .. "!", COLORS.good, "levelup")
	effect(state.player, { kind = "levelup", id = id, level = level + 1 })
	refreshVisuals(state)
	checkTutorial(state)
	markDirty(state)
end

function Actions.buyUpgrade(state, id)
	if type(id) ~= "string" then
		return
	end
	local u = Config.UpgradeById[id]
	if not u then
		return
	end
	local st, reason = Economy.upgradeState(state.data, id)
	if st == "owned" then
		return
	end
	if st ~= "available" then
		notify(state.player, "🔒 " .. (reason or "Bloqueado"), COLORS.bad, "error")
		return
	end
	if not spend(state, u.cost) then
		notify(state.player, "💸 Te faltan " .. Format.cash(u.cost - state.data.cash), COLORS.bad, "error")
		return
	end
	state.data.upgrades[id] = true
	state.data.stats.upgrades += 1
	ChallengeService.progress(state, "upgrades", 1)
	if u.visual and state.plot then
		PlotService.rebuildExtras(state.plot, state)
	end
	notify(state.player, u.icon .. " Mejora comprada: " .. u.name, COLORS.purple, "upgrade")
	effect(state.player, { kind = "upgrade", id = id })
	refreshVisuals(state)
	checkTutorial(state)
	markDirty(state)
end

function Actions.buyExpansion(state, index)
	index = tonumber(index)
	if not index then
		return
	end
	local exp = Config.Expansions[index]
	if not exp then
		return
	end
	local st, reason = Economy.expansionState(state.data, index)
	if st == "owned" then
		return
	end
	if st ~= "available" then
		notify(state.player, "🔒 " .. (reason or "Bloqueado"), COLORS.bad, "error")
		return
	end
	if not spend(state, exp.cost) then
		notify(state.player, "💸 Te faltan " .. Format.cash(exp.cost - state.data.cash), COLORS.bad, "error")
		return
	end
	state.data.expansions = index
	if state.plot then
		PlotService.rebuildZones(state.plot, state)
	end
	notify(state.player, "🚧 ¡Has desbloqueado " .. exp.name .. "! Nuevos negocios disponibles.", COLORS.gold, "success")
	effect(state.player, { kind = "expansion", index = index })
	effect(state.player, { kind = "confetti" })
	refreshVisuals(state)
	markDirty(state)
end

function Actions.claimGoal(state)
	local goal = Economy.currentGoal(state.data)
	if not goal then
		return
	end
	if Economy.goalProgress(state.data, goal) < goal.target then
		notify(state.player, "🎯 Aún no has completado: " .. goal.text, COLORS.bad, "error")
		return
	end
	state.data.goalsClaimed[goal.id] = true
	earn(state, goal.reward)
	notify(state.player, "🏅 Objetivo cumplido: +" .. Format.cash(goal.reward), COLORS.gold, "success")
	effect(state.player, { kind = "confetti" })
	refreshVisuals(state)
	markDirty(state)
end

function Actions.claimDaily(state, index)
	index = tonumber(index)
	if not index then
		return
	end
	local reward, bonus = ChallengeService.claim(state, index)
	if reward <= 0 then
		return
	end
	earn(state, reward)
	notify(state.player, "🎯 Reto completado: +" .. Format.cash(reward), COLORS.gold, "success")
	if bonus > 0 then
		earn(state, bonus)
		notify(state.player, "🔥 ¡Bonus por los 3 retos!: +" .. Format.cash(bonus), COLORS.gold, "success")
		effect(state.player, { kind = "confetti" })
	end
	refreshVisuals(state)
	markDirty(state)
end

function Actions.franchise(state)
	local data = state.data
	if not Economy.canFranchise(data) then
		notify(state.player, "🏢 Necesitas la Torre Corporativa y " .. Format.cash(Config.Franchise.needEarned) .. " ganados.", COLORS.bad, "error")
		return
	end
	data.franchises += 1
	data.cash = 0
	data.runEarned = 0
	data.businesses = {}
	data.upgrades = {}
	data.expansions = 0
	if state.plot then
		PlotService.rebuildAll(state.plot, state)
	end
	notify(state.player, string.format("🌟 ¡Nueva franquicia! Bonus permanente: %s", Format.percent(data.franchises * Config.Franchise.bonusPerFranchise)), COLORS.gold, "success")
	effect(state.player, { kind = "confetti" })
	refreshVisuals(state)
	markDirty(state)
end

function Actions.teleport(state, target)
	local character = state.player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	if target == "plot" and state.plot then
		character:PivotTo(PlotService.spawnCFrame(state.plot))
	elseif target == "plaza" then
		character:PivotTo(CFrame.new(0, 4, -44) * CFrame.Angles(0, math.rad(180), 0))
	end
end

function Actions.setting(state, key, value)
	if type(value) ~= "boolean" then
		return
	end
	if key == "decor" then
		state.data.settings.decor = value
		if state.plot then
			PlotService.rebuildExtras(state.plot, state)
		end
	elseif key == "theme" then
		state.data.settings.theme = value
		if state.plot then
			PlotService.rebuildAll(state.plot, state)
			DayNightService.applyTo(state.plot.model)
		end
	else
		return
	end
	markDirty(state)
end

function Actions.tutorial(state, event)
	if event == "openedChallenges" then
		state.flags.openedChallenges = true
	elseif event == "skip" then
		state.data.tutorial = TUTORIAL_DONE
	end
	checkTutorial(state)
	markDirty(state)
end

function Actions.simulate(state, kind, key)
	if type(kind) ~= "string" or type(key) ~= "string" then
		return
	end
	local ok, err = MonetizationService.simulate(state.player, kind, key)
	if not ok and err then
		notify(state.player, err, COLORS.bad, "error")
	end
end

function Actions.requestState(state)
	markDirty(state)
end

------------------------------------------------------------------------------
-- Pads (botones fisicos de la parcela)
------------------------------------------------------------------------------

function GameService.onPad(player, plot, kind, target)
	local state = states[player]
	if kind == "notOwner" then
		notify(player, "🚫 Esta no es tu parcela. Solo su dueño puede construir aquí.", COLORS.bad, "error")
		return
	end
	if not state or not state.ready or state.plot ~= plot then
		return
	end
	if kind == "business" then
		Actions.buyBusiness(state, target)
	elseif kind == "expansion" then
		Actions.buyExpansion(state, target)
	end
end

------------------------------------------------------------------------------
-- Ciclo de vida de jugadores
------------------------------------------------------------------------------

local function grantOffline(state)
	local data = state.data
	if (data.lastOnline or 0) <= 0 then
		return
	end
	local elapsed = os.time() - data.lastOnline
	if elapsed < Config.Offline.minSeconds then
		return
	end
	local rate, maxSeconds = Economy.offlineSettings(data)
	local seconds = math.min(elapsed, maxSeconds)
	local amount = math.floor(Economy.totalIncome(data, hasX2(state)) * seconds * rate)
	if amount > 0 then
		earn(state, amount)
		task.delay(3, function()
			if state.player.Parent then
				effect(state.player, { kind = "offline", amount = amount, seconds = seconds })
			end
		end)
	end
end

local function placeCharacter(state)
	local player = state.player
	local character = player.Character
	if not character or not state.plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		task.wait(0.1)
		character:PivotTo(PlotService.spawnCFrame(state.plot))
	end
end

local function onPlayerAdded(player)
	LeaderboardService.setup(player)
	local state = {
		player = player,
		data = nil,
		ready = false,
		dirty = true,
		passes = { decor = false, theme = false, x2 = false },
		flags = {},
		plot = nil,
		actionTimes = {},
		minuteAcc = 0,
	}
	states[player] = state

	local profile = DataService.load(player)
	if not profile or not player.Parent then
		-- El jugador se fue mientras cargaba: liberar el bloqueo de sesion
		DataService.release(player)
		states[player] = nil
		return
	end
	state.data = profile.data
	state.passes = MonetizationService.loadPasses(player, state.data)

	local plot = PlotService.assign(player)
	if not plot then
		player:Kick("El servidor está lleno (8 parcelas). ¡Prueba en otro servidor!")
		return
	end
	state.plot = plot
	ChallengeService.ensure(state)
	grantOffline(state)
	state.ready = true

	PlotService.rebuildAll(plot, state)
	DayNightService.applyTo(plot.model)
	refreshVisuals(state)
	LeaderboardService.update(player, state.data)
	checkTutorial(state)
	sync(state)

	if not profile.persistent then
		task.delay(4, function()
			notify(player, "⚠️ Guardado desactivado: activa 'Enable Studio Access to API Services' o publica el juego.", COLORS.bad)
		end)
	end
	notify(player, "👋 ¡Bienvenido a Tiny Empire Tycoon, " .. player.DisplayName .. "!", COLORS.gold, "success")

	player.CharacterAdded:Connect(function()
		task.defer(placeCharacter, state)
	end)
	if player.Character then
		task.defer(placeCharacter, state)
	end
end

local function onPlayerRemoving(player)
	local state = states[player]
	if state then
		state.ready = false
	end
	DataService.release(player)
	PlotService.release(player)
	states[player] = nil
end

------------------------------------------------------------------------------
-- Bucles
------------------------------------------------------------------------------

local function incomeLoop()
	while true do
		task.wait(Config.IncomeTick)
		for player, state in pairs(states) do
			if state.ready and player.Parent then
				local income = Economy.totalIncome(state.data, hasX2(state)) * Config.IncomeTick
				if income > 0 then
					earn(state, income)
				end
				-- Tiempo jugado (retos de minutos)
				state.data.stats.playSeconds += Config.IncomeTick
				state.minuteAcc += Config.IncomeTick
				if state.minuteAcc >= 60 then
					state.minuteAcc -= 60
					if ChallengeService.progress(state, "minutes", 1) then
						notify(player, "🎯 ¡Reto diario completado!", COLORS.gold, "success")
					end
					markDirty(state)
				end
				-- Nuevo dia
				if ChallengeService.ensure(state) then
					notify(player, "🌅 ¡Nuevos retos diarios disponibles!", COLORS.gold)
					markDirty(state)
				end
				-- Visita a la plaza
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local p = root.Position
					local inPlaza = Vector3.new(p.X, 0, p.Z).Magnitude < Config.PlazaRadius
					if inPlaza and not state.flags.visitedPlaza then
						state.flags.visitedPlaza = true
						ChallengeService.progress(state, "plaza", 1)
						markDirty(state)
					end
				end
				checkTutorial(state)
				refreshVisuals(state)
				LeaderboardService.update(player, state.data)
				if state.dirty then
					sync(state)
				else
					remotes.Tick:FireClient(player, state.data.cash, income / Config.IncomeTick, state.data.runEarned)
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- API publica para otros servicios
------------------------------------------------------------------------------

function GameService.getState(player)
	return states[player]
end

function GameService.getStates()
	return states
end

function GameService.collectCrate(player, position)
	local state = states[player]
	if not state or not state.ready then
		return false
	end
	local reward = Economy.crateReward(state.data, hasX2(state))
	earn(state, reward)
	state.data.stats.crates += 1
	if ChallengeService.progress(state, "crates", 1) then
		notify(player, "🎯 ¡Reto diario completado!", COLORS.gold, "success")
	end
	effect(player, { kind = "cash", amount = reward, position = position })
	notify(player, "💼 ¡Maletín recogido! +" .. Format.cash(reward), COLORS.gold, "coin")
	markDirty(state)
	return true
end

function GameService.init(remoteFolder)
	remotes = remoteFolder

	MonetizationService.init({
		getState = GameService.getState,
		onPassGranted = function(player, key)
			local state = states[player]
			if not state then
				return
			end
			local pass = Config.GamePasses[key]
			if key == "decor" and state.plot then
				PlotService.rebuildExtras(state.plot, state)
			elseif key == "theme" and state.plot then
				PlotService.rebuildAll(state.plot, state)
				DayNightService.applyTo(state.plot.model)
			end
			notify(player, pass.icon .. " ¡Gracias! Has desbloqueado: " .. pass.name, COLORS.gold, "success")
			effect(player, { kind = "confetti" })
			refreshVisuals(state)
			markDirty(state)
			sync(state)
		end,
		onCashGranted = function(player, amount, product)
			local state = states[player]
			if not state then
				return
			end
			notify(player, product.icon .. " ¡Gracias! +" .. Format.cash(amount), COLORS.gold, "success")
			effect(player, { kind = "cash", amount = amount })
			effect(player, { kind = "confetti" })
			refreshVisuals(state)
			markDirty(state)
			sync(state)
		end,
	})

	remotes.Action.OnServerEvent:Connect(function(player, action, a, b)
		local state = states[player]
		if not state or not state.ready then
			return
		end
		if type(action) ~= "string" then
			return
		end
		-- Limite de peticiones: maximo 12 por segundo
		local now = os.clock()
		local times = state.actionTimes
		while #times > 0 and now - times[1] > 1 do
			table.remove(times, 1)
		end
		if #times >= 12 then
			return
		end
		table.insert(times, now)
		local handler = Actions[action]
		if handler then
			handler(state, a, b)
			if state.dirty then
				sync(state)
			end
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(incomeLoop)
end

GameService.Actions = Actions
GameService._checkTutorial = checkTutorial
GameService._snapshot = snapshot

return GameService
