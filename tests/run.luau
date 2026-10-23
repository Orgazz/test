--!nocheck
-- Pruebas de integracion de Tiny Empire Tycoon (ejecutar con Lune).
--   rojo build default.project.json -o build/TinyEmpireTycoon.rbxlx
--   lune run tests/run.luau build/TinyEmpireTycoon.rbxlx

local process = require("@lune/process")
local Enum = require("@lune/roblox").Enum
local H = require("./harness")

local placePath = process.args[1] or "build/TinyEmpireTycoon.rbxlx"

local passed, failed = 0, 0
local failures = {}
local currentTest = "?"

local function check(cond, msg)
	if cond then
		passed += 1
	else
		failed += 1
		local line = string.format("[%s] %s", currentTest, msg)
		table.insert(failures, line)
		print("\27[31m  ✗ " .. msg .. "\27[0m")
	end
	return cond
end

local function section(name)
	currentTest = name
	print("\n\27[36m▶ " .. name .. "\27[0m")
end

local function approx(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-6) * math.max(1, math.abs(b))
end

------------------------------------------------------------------------------
-- Arranque del servidor
------------------------------------------------------------------------------

local game = H.loadPlace(placePath)
H.setup({ studio = true })
local server = H.newRealm("server", game)

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Shared = RS:FindFirstChild("TinyEmpireShared")
local ServerRoot = SSS:FindFirstChild("TinyEmpireServer")

local Config = server.require(Shared.Config)
local Economy = server.require(Shared.Economy)
-- IDs de prueba: dos productos y un pase "reales"; el resto se simula (Studio)
Config.Products.small.id = 1001
Config.Products.medium.id = 1002
Config.GamePasses.x2.id = 2001

local remoteLog = {}
H.onFireClient = function(name, player, payload)
	table.insert(remoteLog, { name = name, player = player, payload = payload })
end

local mainCo
local function bootServer()
	server.runScript(ServerRoot:FindFirstChild("Main"))
	local remotes = RS:FindFirstChild("TinyEmpireRemotes")
	assert(remotes, "remotos no creados")
	H.connectRemotes(remotes)
	return remotes
end

local t0 = os.clock()
local remotes = bootServer()
local GameService = server.require(ServerRoot.Services.GameService)
local PlotService = server.require(ServerRoot.Services.PlotService)
local ChallengeService = server.require(ServerRoot.Services.ChallengeService)
local DataService = server.require(ServerRoot.Services.DataService)
local workspace = H.workspace
local map = workspace:FindFirstChild("TinyEmpireMap")

local function lastNotify(player)
	for i = #remoteLog, 1, -1 do
		local e = remoteLog[i]
		if e.name == "Notify" and e.player == player then
			return e.payload.text
		end
	end
	return nil
end

-- Ejecuta una funcion que puede ceder (task.wait) y avanza el reloj hasta que termine
local function await(fn, ...)
	local done, results = false, nil
	local args = table.pack(...)
	H.Sched.queue = H.Sched.queue
	local co = coroutine.create(function()
		results = table.pack(fn(table.unpack(args, 1, args.n)))
		done = true
	end)
	local ok, err = coroutine.resume(co)
	if not ok then
		error(err)
	end
	local guard = 0
	while not done and guard < 2000 do
		H.advance(0.1, 0.1)
		guard += 1
	end
	assert(done, "await: la funcion no termino")
	return table.unpack(results, 1, results.n)
end

local function stateOf(player)
	return GameService.getState(player)
end

local function action(player, name, a, b)
	remotes.Action.OnServerEvent:Fire(player, name, a, b)
	H.advance(0.1, 0.1)
end

local function plotModel(player)
	local st = stateOf(player)
	return st and st.plot and st.plot.model
end

local function padTouch(player, ownerOfPlot, key)
	local plot = plotModel(ownerOfPlot)
	local pad = plot.Pads:FindFirstChild("Pad_" .. key)
	H.touch(player, pad:FindFirstChild("Touch"))
	H.advance(0.1, 0.1)
end

------------------------------------------------------------------------------
section("Mundo generado")
------------------------------------------------------------------------------
do
	check(map ~= nil, "existe Workspace.TinyEmpireMap")
	local parts = 0
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format("  piezas del mapa: %d (%.2fs)", parts, os.clock() - t0))
	check(parts > 1500, "el mapa tiene muchas piezas (" .. parts .. ")")
	check(#map.Plots:GetChildren() == 8, "hay 8 parcelas")
	check(map:FindFirstChild("Plaza") ~= nil, "existe la plaza central")
	local hoods = 0
	for _, c in ipairs(map:GetChildren()) do
		if c.Name:sub(1, 7) == "Barrio_" then
			hoods += 1
		end
	end
	check(hoods == 4, "hay 4 barrios")
	check(#map.Vehicles:GetChildren() == 12, "hay 12 vehiculos decorativos")
	check(map:FindFirstChild("LeaderboardBoard", true) ~= nil, "existe el panel de ranking")
	local lamps = #game:GetService("CollectionService"):GetTagged("TE_Lamp")
	check(lamps > 50, "hay farolas con luz (" .. lamps .. ")")
	check(#H.errors == 0, "sin errores al construir el mundo")
end

------------------------------------------------------------------------------
section("Entrada de jugador y parcela")
------------------------------------------------------------------------------
local alice = H.addPlayer("Alice", 101)
H.advance(2)
do
	local st = stateOf(alice)
	check(st ~= nil and st.ready, "Alice tiene estado listo")
	check(st.plot ~= nil and st.plot.index == 1, "Alice recibe la parcela 1")
	check(plotModel(alice):GetAttribute("Owner") == 101, "la parcela registra al dueño")
	local pad = plotModel(alice).Pads.Pad_lemonade
	check(pad:GetAttribute("Visible") == true, "el pad de limonada es visible")
	check(pad.Button.Info.Card.Price.Text == "¡GRATIS!", "el pad de limonada indica GRATIS")
	check(plotModel(alice).Pads.Pad_foodtruck:GetAttribute("Visible") == false, "el food truck aun no se muestra")
	check(st.data.tutorial == 1, "tutorial en el paso 1")
	check(st.data.daily ~= nil and #st.data.daily.list == 3, "3 retos diarios generados")
	local root = H.customOf(alice).Character and H.customOf(alice).Character:FindFirstChild("HumanoidRootPart")
	check(root ~= nil and PlotService.isInside(st.plot, root.Position), "el personaje aparece dentro de su parcela")
	local ls = alice:FindFirstChild("leaderstats")
	check(ls ~= nil, "leaderstats creados")
end

------------------------------------------------------------------------------
section("Construir con los botones de la parcela")
------------------------------------------------------------------------------
do
	padTouch(alice, alice, "lemonade")
	local st = stateOf(alice)
	check(st.data.businesses.lemonade == 1, "Puesto de Limonada comprado")
	check(plotModel(alice).Buildings:FindFirstChild("lemonade") ~= nil, "edificio construido en la parcela")
	check(plotModel(alice).Buildings.lemonade:GetAttribute("BuiltAt") ~= nil, "edificio marcado para animacion")
	check(st.data.tutorial == 2, "tutorial avanza al paso 2")
	check(plotModel(alice).Pads.Pad_foodtruck:GetAttribute("Visible") == true, "aparece el pad del Food Truck")
	local cash0 = st.data.cash
	H.advance(10)
	check(approx(st.data.cash - cash0, 20, 0.11), "ingresos automaticos: ~$2/s (" .. (st.data.cash - cash0) .. ")")
	local guard = 0
	while st.data.cash < Config.BusinessById.foodtruck.cost and guard < 200 do
		H.advance(1)
		guard += 1
	end
	H.advance(1)
	check(st.data.tutorial == 3, "tutorial avanza al paso 3 al reunir el dinero del Food Truck")
	padTouch(alice, alice, "foodtruck")
	check(st.data.businesses.foodtruck == 1, "Food Truck comprado con el pad")
	check(st.data.tutorial == 4, "tutorial paso 4")
end

------------------------------------------------------------------------------
section("Varios jugadores y proteccion de parcelas")
------------------------------------------------------------------------------
H.advance(1)
local bob = H.addPlayer("Bob", 102)
H.advance(2)
do
	local sb = stateOf(bob)
	check(sb.plot.index == 2, "Bob recibe la parcela 2")
	local before = stateOf(alice).data.businesses.bakery
	stateOf(bob).data.cash = 10_000
	padTouch(bob, alice, "bakery")
	check(stateOf(alice).data.businesses.bakery == before, "Bob NO puede construir en la parcela de Alice")
	check(stateOf(bob).data.businesses.bakery == nil, "Bob no recibe el negocio ajeno")
	check((lastNotify(bob) or ""):find("no es tu parcela") ~= nil, "Bob recibe aviso de parcela ajena")
	-- Remotos maliciosos
	local okCalls = pcall(function()
		action(bob, "buyBusiness", { evil = true })
		action(bob, "buyUpgrade", 12345)
		action(bob, "buyExpansion", "abc")
		action(bob, "claimDaily", -1)
		action(bob, "nope")
		action(bob, 42)
		action(bob, "setting", "decor", "yes")
	end)
	check(okCalls and #H.errors == 0, "argumentos invalidos no rompen el servidor")
	-- Limite de peticiones
	local sbData = stateOf(bob).data
	sbData.cash = 1e12
	local count0 = sbData.stats.builds
	for _ = 1, 40 do
		remotes.Action.OnServerEvent:Fire(bob, "buyBusiness", "lemonade")
	end
	H.advance(0.1, 0.1)
	check(sbData.stats.builds - count0 <= 12, "limite de 12 acciones/segundo (" .. (sbData.stats.builds - count0) .. ")")
	sbData.cash = 0
end

------------------------------------------------------------------------------
section("Mejoras, coste y fondos insuficientes")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	local cash = st.data.cash
	action(alice, "buyUpgrade", "u_brand")
	check(st.data.upgrades.u_brand == nil, "no se compra una mejora bloqueada")
	action(alice, "buyUpgrade", "u_sign")
	if cash < 150 then
		check(st.data.upgrades.u_sign == nil, "sin dinero no se compra la mejora")
	end
	st.data.cash = 1000
	action(alice, "upgradeBusiness", "lemonade")
	check(st.data.businesses.lemonade == 2, "limonada sube a nivel 2")
	check(st.data.cash == 1000 - Economy.levelUpCost("lemonade", 1), "se cobra el coste exacto del nivel")
	check(st.data.tutorial == 5, "tutorial paso 5")
	local incomeBefore = Economy.totalIncome(st.data)
	action(alice, "buyUpgrade", "u_sign")
	check(st.data.upgrades.u_sign == true, "mejora Letrero Llamativo comprada")
	check(approx(Economy.totalIncome(st.data), incomeBefore * 1.10), "la mejora suma +10% de ingresos")
	check(st.data.tutorial == 6, "tutorial paso 6")
	action(alice, "tutorial", "openedChallenges")
	check(st.data.tutorial == 7, "tutorial paso 7 al abrir retos")
	action(alice, "teleport", "plaza")
	H.advance(1.5)
	check(st.data.tutorial == 99, "tutorial completado al visitar la plaza")
	local up = 0
	for _ in pairs(Config.Upgrades) do
		up += 1
	end
	check(up >= 20, "hay al menos 20 mejoras de imperio (" .. up .. ")")
	action(alice, "teleport", "plot")
end

------------------------------------------------------------------------------
section("Expansiones y nuevos negocios")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	st.data.cash = 1_000_000
	action(alice, "buyExpansion", 1)
	check(st.data.expansions == 0, "expansion bloqueada por nivel de imperio")
	st.data.runEarned = 30_000
	action(alice, "buyBusiness", "bakery")
	action(alice, "buyBusiness", "cafe")
	action(alice, "buyExpansion", 1)
	check(st.data.expansions == 1, "Distrito Comercial desbloqueado")
	check(plotModel(alice).Pads.Pad_toystore:GetAttribute("Visible") == true, "aparece el pad de la Jugueteria")
	check(plotModel(alice).Zones:FindFirstChild("PadWalk") ~= nil, "la zona 2 se urbaniza")
	action(alice, "buyBusiness", "toystore")
	check(st.data.businesses.toystore == 1, "Jugueteria construida")
	action(alice, "buyBusiness", "warehouse")
	check(st.data.businesses.warehouse == nil, "no se puede saltar el orden de negocios")
end

------------------------------------------------------------------------------
section("Objetivos de expansion")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	local cash = st.data.cash
	local claimed = 0
	for _ = 1, 10 do
		local before = st.data.cash
		action(alice, "claimGoal")
		if st.data.cash > before then
			claimed += 1
		else
			break
		end
	end
	check(claimed >= 3, "se reclaman los objetivos cumplidos (" .. claimed .. ")")
	check(st.data.goalsClaimed.g_two and st.data.goalsClaimed.g_four, "objetivos registrados")
	check(st.data.cash > cash, "los objetivos dan dinero")
	local before = st.data.cash
	action(alice, "claimGoal")
	check(st.data.cash == before, "no se reclama un objetivo sin cumplir")
end

------------------------------------------------------------------------------
section("Retos diarios")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	local list = st.data.daily.list
	local ids = {}
	for _, c in ipairs(list) do
		ids[c.id] = true
	end
	local n = 0
	for _ in pairs(ids) do
		n += 1
	end
	check(n == 3, "los 3 retos son distintos")
	-- Completar a la fuerza y reclamar
	for _, c in ipairs(list) do
		c.progress = c.target
	end
	local cash = st.data.cash
	action(alice, "claimDaily", 1)
	action(alice, "claimDaily", 1)
	local diff = st.data.cash - cash
	check(list[1].claimed and diff >= list[1].reward and diff < list[1].reward * 1.5, "reto 1 reclamado una sola vez")
	action(alice, "claimDaily", 2)
	local beforeLast = st.data.cash
	action(alice, "claimDaily", 3)
	check(st.data.daily.bonusClaimed == true, "bonus por completar los 3 retos")
	check(st.data.cash - beforeLast > list[3].reward, "el bonus suma dinero extra")
	local day = st.data.daily.day
	H.advance(86400 - ((H.epoch + H.Sched.now) % 86400) + 5, 5)
	check(st.data.daily.day == day + 1, "nuevos retos al cambiar de dia")
	check(st.data.daily.list[1].claimed == false, "los retos nuevos empiezan sin reclamar")
	-- Progreso real: maletines
	local crateBefore = st.data.stats.crates
	local crates = map.Crates:GetChildren()
	check(#crates > 0, "hay maletines en la plaza (" .. #crates .. ")")
	if #crates > 0 then
		local cash2 = st.data.cash
		H.touch(alice, crates[1]:FindFirstChild("Touch"))
		H.advance(0.2, 0.1)
		check(st.data.stats.crates == crateBefore + 1, "maletin recogido")
		check(st.data.cash > cash2, "el maletin da dinero")
		check(crates[1].Parent == nil, "el maletin desaparece")
	end
end

------------------------------------------------------------------------------
section("Compras: productos con recibo (sin duplicados)")
------------------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
do
	local st = stateOf(alice)
	local processRaw = H.customOf(MarketplaceService).ProcessReceipt
	local function process(info)
		return await(processRaw, info)
	end
	check(type(processRaw) == "function", "ProcessReceipt registrado en el servidor")
	local cash = st.data.cash
	local expected = Economy.productReward(st.data, "small", st.passes.x2)
	local r1 = process({ PlayerId = 101, ProductId = 1001, PurchaseId = "R-1", CurrencySpent = 29 })
	check(r1 == Enum.ProductPurchaseDecision.PurchaseGranted, "recibo concedido")
	check(st.data.cash - cash == expected, "se entrega el efectivo del paquete (" .. expected .. ")")
	local r2 = process({ PlayerId = 101, ProductId = 1001, PurchaseId = "R-1", CurrencySpent = 29 })
	check(r2 == Enum.ProductPurchaseDecision.PurchaseGranted, "recibo repetido confirmado")
	check(st.data.cash - cash == expected, "recibo repetido NO duplica el dinero")
	-- Fallo de guardado: se revierte y Roblox reintentara
	H.dataStoreFailures = 10
	local cash2 = st.data.cash
	local r3 = process({ PlayerId = 101, ProductId = 1002, PurchaseId = "R-2", CurrencySpent = 49 })
	check(r3 == Enum.ProductPurchaseDecision.NotProcessedYet, "si no se puede guardar, NotProcessedYet")
	check(st.data.cash == cash2, "el dinero se revierte si falla el guardado")
	check(st.data.receipts["R-2"] == nil, "el recibo fallido no queda registrado")
	H.dataStoreFailures = 0
	local r4 = process({ PlayerId = 101, ProductId = 1002, PurchaseId = "R-2", CurrencySpent = 49 })
	check(r4 == Enum.ProductPurchaseDecision.PurchaseGranted, "reintento concedido")
	check(st.data.cash > cash2, "reintento entrega el dinero")
	local r5 = process({ PlayerId = 999999, ProductId = 1001, PurchaseId = "R-3", CurrencySpent = 29 })
	check(r5 == Enum.ProductPurchaseDecision.NotProcessedYet, "jugador ausente: NotProcessedYet")
	local saved = H.dataStores[Config.DataStoreName]._data["Player_101"]
	check(saved ~= nil and saved.data.receipts["R-1"] ~= nil, "el recibo queda guardado en DataStore")
	-- Cliente: el boton pide la compra real cuando hay ID
	-- (se prueba en la seccion de cliente)
end

------------------------------------------------------------------------------
section("Compras: pases (x2 real, decoracion y tema simulados en Studio)")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	local incomeBefore = Economy.totalIncome(st.data, st.passes.x2)
	H.ownedPasses[101] = { [2001] = true }
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(alice, 2001, true)
	H.advance(0.1, 0.1)
	check(st.passes.x2 == true, "pase x2 activado")
	check(approx(Economy.totalIncome(st.data, st.passes.x2), incomeBefore * 2), "el pase x2 duplica ingresos")
	local bobIncome = Economy.totalIncome(stateOf(bob).data, stateOf(bob).passes.x2)
	check(stateOf(bob).passes.x2 == false, "el pase de Alice no afecta a Bob")
	action(alice, "simulate", "pass", "decor")
	check(st.passes.decor == true, "decoracion premium simulada")
	check(plotModel(alice).Extras:FindFirstChild("PremiumDecor") ~= nil, "se construye la decoracion premium")
	action(alice, "simulate", "pass", "theme")
	check(st.passes.theme == true, "tema premium simulado")
	check(plotModel(alice).Buildings.lemonade:FindFirstChild("GoldTrim") ~= nil, "los edificios usan el tema dorado")
	action(alice, "setting", "theme", false)
	check(plotModel(alice).Buildings.lemonade:FindFirstChild("GoldTrim") == nil, "el tema se puede desactivar")
	action(alice, "setting", "theme", true)
	action(alice, "simulate", "pass", "x2")
	check((lastNotify(alice) or ""):find("no valido") ~= nil, "no se simula un pase con ID real")
	local cash = st.data.cash
	action(alice, "simulate", "product", "large")
	check(st.data.cash > cash, "paquete grande simulado en Studio")
	action(alice, "simulate", "product", "small")
	check((lastNotify(alice) or ""):find("no valido") ~= nil, "no se simula un producto con ID real")
	check(Economy.totalIncome(stateOf(bob).data, stateOf(bob).passes.x2) == bobIncome, "Bob no se ve afectado por compras ajenas")
end

------------------------------------------------------------------------------
section("Reingreso: guardado, liberacion de parcela y ganancias offline")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	local snapshot = {
		businesses = table.clone(st.data.businesses),
		upgrades = table.clone(st.data.upgrades),
		expansions = st.data.expansions,
		cash = st.data.cash,
		goals = table.clone(st.data.goalsClaimed),
	}
	local income = Economy.totalIncome(st.data, true)
	H.removePlayer(alice)
	H.advance(2)
	check(stateOf(alice) == nil, "estado liberado al salir")
	local plot1 = map.Plots.Plot1
	check(plot1:GetAttribute("Owner") == 0, "la parcela 1 queda libre")
	check(#plot1.Buildings:GetChildren() == 0, "los edificios de la parcela libre se retiran")
	local saved = H.dataStores[Config.DataStoreName]._data["Player_101"]
	check(saved.session == nil, "bloqueo de sesion liberado al salir")
	check(saved.data.businesses.toystore == 1, "negocios guardados en DataStore")

	H.advance(3600)
	local alice2 = H.addPlayer("Alice", 101)
	H.advance(3)
	local st2 = stateOf(alice2)
	check(st2 and st2.ready, "Alice vuelve a entrar")
	local same = true
	for k, v in pairs(snapshot.businesses) do
		if st2.data.businesses[k] ~= v then
			same = false
		end
	end
	check(same, "negocios restaurados")
	local sameUp = true
	for k in pairs(snapshot.upgrades) do
		if not st2.data.upgrades[k] then
			sameUp = false
		end
	end
	check(sameUp, "mejoras restauradas")
	check(st2.data.expansions == snapshot.expansions, "expansiones restauradas")
	local offline = st2.data.cash - snapshot.cash
	local expectedOffline = math.floor(income * 3600 * Config.Offline.baseRate)
	check(offline >= expectedOffline * 0.95, string.format("ganancias offline recibidas (%d ~ %d)", offline, expectedOffline))
	check(plotModel(alice2).Buildings:FindFirstChild("toystore") ~= nil, "la parcela se reconstruye al volver")
	check(st2.passes.decor and st2.passes.theme, "los pases simulados persisten en Studio")
	check(st2.data.receipts["R-1"] ~= nil, "historial de recibos persistente")
	alice = alice2
end

------------------------------------------------------------------------------
section("Bloqueo de sesion entre servidores")
------------------------------------------------------------------------------
do
	local store = H.dataStores[Config.DataStoreName]
	store._data["Player_555"] = { data = Economy.newData(), session = { jobId = "otro-servidor", time = H.epoch + math.floor(H.Sched.now) } }
	store._data["Player_555"].data.cash = 777
	local carol = H.addPlayer("Carol", 555)
	H.advance(4)
	check(stateOf(carol) == nil or not stateOf(carol).ready, "espera mientras otro servidor tiene la sesion")
	H.advance(30)
	check(stateOf(carol) and stateOf(carol).ready, "toma el control tras los reintentos")
	check(stateOf(carol).data.cash >= 777, "conserva los datos del otro servidor")
	check(store._data["Player_555"].session.jobId == "server-test-1", "la sesion pasa a este servidor")
	H.removePlayer(carol)
	H.advance(2)
end

------------------------------------------------------------------------------
section("Servidor lleno (8 parcelas)")
------------------------------------------------------------------------------
do
	local extra = {}
	for i = 1, 6 do
		table.insert(extra, H.addPlayer("Bot" .. i, 200 + i))
	end
	H.advance(3)
	local plots = {}
	for _, p in ipairs({ alice, bob, table.unpack(extra) }) do
		local st = stateOf(p)
		if st and st.plot then
			plots[st.plot.index] = true
		end
	end
	local count = 0
	for _ in pairs(plots) do
		count += 1
	end
	check(count == 8, "8 jugadores con 8 parcelas distintas")
	local ninth = H.addPlayer("Noveno", 300)
	H.advance(3)
	check(H.customOf(ninth).kicked ~= nil, "el noveno jugador es expulsado con aviso")
	-- Todos ganan dinero a la vez
	for _, p in ipairs(extra) do
		action(p, "buyBusiness", "lemonade")
	end
	H.advance(5)
	local allEarning = true
	for _, p in ipairs(extra) do
		if stateOf(p).data.cash <= 0 then
			allEarning = false
		end
	end
	check(allEarning, "todos los jugadores generan ingresos en paralelo")
	for _, p in ipairs(extra) do
		H.removePlayer(p)
	end
	H.advance(3)
end

------------------------------------------------------------------------------
section("Cliente: HUD, menus, tienda y tutorial")
------------------------------------------------------------------------------
do
	local dave = H.addPlayer("Dave", 401)
	H.clientPlayer = dave
	local client = H.newRealm("client", H.clientGame(dave))
	local clientRoot = game:GetService("StarterPlayer").StarterPlayerScripts.TinyEmpireClient
	local clientConfig = client.require(Shared.Config)
	clientConfig.Products.small.id = 1001
	clientConfig.Products.medium.id = 1002
	clientConfig.GamePasses.x2.id = 2001
	client.runScript(clientRoot:FindFirstChild("Main"))
	H.advance(3)
	local gui = dave.PlayerGui:FindFirstChild("TinyEmpireHUD")
	check(gui ~= nil, "HUD creado")
	if gui then
		local cashLabel = gui.TopBar.Cash.Amount
		check(cashLabel.Text:sub(1, 1) == "$", "contador de dinero visible (" .. cashLabel.Text .. ")")
		check(gui.Tutorial.Visible == true, "tarjeta de tutorial visible")
		-- Abrir menus
		gui.Menu.empire.Activated:Fire()
		H.advance(0.2, 0.1)
		check(gui.empireWindow.Visible == true, "menu Imperio se abre")
		local lemonCard = nil
		for _, c in ipairs(gui.empireWindow.Frame["Negocios"]:GetChildren()) do
			if c:IsA("Frame") then
				lemonCard = lemonCard or c
			end
		end
		local buyBtn = lemonCard and lemonCard:FindFirstChild("Button")
		check(buyBtn ~= nil and buyBtn.Label.Text == "¡GRATIS!", "tarjeta de limonada muestra GRATIS")
		if buyBtn then
			buyBtn.Activated:Fire()
			H.advance(0.3, 0.1)
			check(stateOf(dave).data.businesses.lemonade == 1, "comprar desde el menu funciona")
		end
		gui.Menu.challenges.Activated:Fire()
		H.advance(0.2, 0.1)
		check(gui.challengesWindow.Visible == true, "menu Retos se abre")
		check(gui.empireWindow.Visible == false, "solo hay una ventana abierta")
		gui.Menu.shop.Activated:Fire()
		H.advance(0.2, 0.1)
		check(gui.shopWindow.Visible == true, "Tienda se abre")
		-- Boton de producto con ID real -> PromptProductPurchase
		local promptsBefore = #H.prompts
		local shopPage = gui.shopWindow.Frame["Tienda"]
		local productButtons = {}
		for _, c in ipairs(shopPage:GetChildren()) do
			if c:IsA("Frame") and c:FindFirstChild("Button") then
				table.insert(productButtons, c.Button)
			end
		end
		check(#productButtons == 6, "6 articulos en la tienda (3 pases + 3 paquetes)")
		local labels = {}
		for _, b in ipairs(productButtons) do
			table.insert(labels, b.Label.Text)
		end
		local joined = table.concat(labels, " | ")
		check(joined:find("R%$ 39") and joined:find("R%$ 99") and joined:find("R%$ 149"), "precios de pases 39/99/149 (" .. joined .. ")")
		check(joined:find("R%$ 29") and joined:find("R%$ 49") and joined:find("R%$ 79"), "precios de paquetes 29/49/79")
		for _, b in ipairs(productButtons) do
			b.Activated:Fire()
		end
		H.advance(0.5, 0.1)
		local realPrompts = #H.prompts - promptsBefore
		check(realPrompts == 3, "se abren compras reales de Roblox para IDs validos (" .. realPrompts .. ")")
		check(stateOf(dave).passes.decor == true, "decoracion simulada desde el boton")
		-- Cerrar con la X
		gui.shopWindow.Frame.Header.Button.Activated:Fire()
		H.advance(0.2, 0.1)
		check(gui.shopWindow.Visible == false, "la X cierra la ventana")
		-- Teletransporte
		gui.Menu.plaza.Activated:Fire()
		H.advance(0.3, 0.1)
		local root = H.customOf(dave).Character.HumanoidRootPart
		check(root.Position.Magnitude < 60, "boton Plaza teletransporta a la plaza")
		gui.Menu.plot.Activated:Fire()
		H.advance(0.3, 0.1)
		check(PlotService.isInside(stateOf(dave).plot, root.Position), "boton Parcela vuelve a la parcela")
		-- Tutorial: haz guia
		check(workspace:FindFirstChild("TutorialAnchor") ~= nil, "haz de luz del tutorial creado")
		-- Ganancias y animaciones durante un rato
		H.advance(20, 0.1)
	end
	H.clientPlayer = nil
end

------------------------------------------------------------------------------
section("Progresion completa gratis (simulacion de 40 h de juego)")
------------------------------------------------------------------------------
do
	local bot = H.addPlayer("Robot", 900)
	H.advance(3)
	local st = stateOf(bot)
	local milestones = {}
	local function mark(name)
		if not milestones[name] then
			milestones[name] = H.Sched.now
		end
	end
	local startT = H.Sched.now
	-- Estrategia: comprar siempre lo mas barato disponible, reclamar objetivos/retos
	local function botStep()
		for _ = 1, 20 do
			local data = st.data
			local best, bestCost, bestAction, bestArg = nil, math.huge, nil, nil
			for _, b in ipairs(Config.Businesses) do
				local s = Economy.businessState(data, b.id)
				if s == "available" and b.cost < bestCost then
					best, bestCost, bestAction, bestArg = b.id, b.cost, "buyBusiness", b.id
				elseif s == "owned" then
					local c = Economy.levelUpCost(b.id, data.businesses[b.id])
					if c and c < bestCost then
						best, bestCost, bestAction, bestArg = b.id, c, "upgradeBusiness", b.id
					end
				end
			end
			for _, u in ipairs(Config.Upgrades) do
				if Economy.upgradeState(data, u.id) == "available" and u.cost < bestCost then
					best, bestCost, bestAction, bestArg = u.id, u.cost, "buyUpgrade", u.id
				end
			end
			for i, e in ipairs(Config.Expansions) do
				if Economy.expansionState(data, i) == "available" and e.cost < bestCost then
					best, bestCost, bestAction, bestArg = i, e.cost, "buyExpansion", i
				end
			end
			if best and data.cash >= bestCost then
				action(bot, bestAction, bestArg)
			else
				break
			end
		end
		action(bot, "claimGoal")
		for i = 1, 3 do
			action(bot, "claimDaily", i)
		end
		local data = st.data
		if data.businesses.foodtruck then
			mark("foodtruck")
		end
		if data.businesses.cafe then
			mark("cafe")
		end
		if data.expansions >= 1 then
			mark("expansion1")
		end
		if data.businesses.warehouse then
			mark("warehouse")
		end
		if data.expansions >= 2 then
			mark("expansion2")
		end
		if data.businesses.factory then
			mark("factory")
		end
		if data.businesses.tower then
			mark("tower")
		end
		if Economy.upgradeCount(data) >= 24 then
			mark("allUpgrades")
		end
		if Economy.canFranchise(data) then
			mark("franchiseReady")
		end
	end
	for i = 1, 40 * 60 do -- hasta 40 horas, revisando cada minuto (cada 15 s al principio)
		if i <= 20 then
			for _ = 1, 4 do
				H.advance(15, 5)
				botStep()
			end
		else
			H.advance(60, 5)
			botStep()
		end
		if milestones.franchiseReady and milestones.allUpgrades then
			break
		end
	end
	print("  Hitos (minutos de juego activo):")
	for _, k in ipairs({ "foodtruck", "cafe", "expansion1", "warehouse", "expansion2", "factory", "tower", "allUpgrades", "franchiseReady" }) do
		local t = milestones[k]
		print(string.format("    %-15s %s", k, t and string.format("%.1f min", (t - startT) / 60) or "no alcanzado"))
	end
	check(milestones.foodtruck and milestones.foodtruck - startT < 120, "Food Truck en menos de 2 minutos")
	check(milestones.expansion1 ~= nil, "primera expansion alcanzable gratis")
	check(milestones.tower ~= nil, "Torre Corporativa alcanzable gratis")
	check(milestones.allUpgrades ~= nil, "las 24 mejoras alcanzables gratis")
	check(milestones.franchiseReady ~= nil, "franquicia alcanzable gratis")
	if milestones.franchiseReady then
		action(bot, "franchise")
		check(st.data.franchises == 1, "franquicia realizada")
		check(st.data.businesses.lemonade == nil, "la franquicia reinicia los negocios")
		check(#plotModel(bot).Buildings:GetChildren() == 0, "la parcela se limpia tras la franquicia")
		action(bot, "buyBusiness", "lemonade")
		check(Economy.totalIncome(st.data) > 2, "bonus permanente de franquicia aplicado")
	end
	local maxLevelAll = true
	for _, b in ipairs(Config.Businesses) do
		if (st.data.businesses[b.id] or 0) < 1 and not milestones.franchiseReady then
			maxLevelAll = false
		end
	end
	local _ = maxLevelAll
	H.removePlayer(bot)
	H.advance(2)
end

------------------------------------------------------------------------------
section("Cierre del servidor")
------------------------------------------------------------------------------
do
	local st = stateOf(alice)
	st.data.cash = 4242
	H.shutdown()
	local saved = H.dataStores[Config.DataStoreName]._data["Player_101"]
	check(saved.data.cash == 4242, "BindToClose guarda a todos los jugadores")
	check(saved.session == nil, "BindToClose libera las sesiones")
end

------------------------------------------------------------------------------

print("\n========================================")
print(string.format("Comprobaciones: %d OK, %d fallidas", passed, failed))
print(string.format("Errores de ejecucion: %d", #H.errors))
local relevantWarnings = {}
for _, w in ipairs(H.warnings) do
	if not w:find("simulado") and not w:find("otro servidor") then
		table.insert(relevantWarnings, w)
	end
end
print(string.format("Avisos: %d", #relevantWarnings))
for i = 1, math.min(10, #relevantWarnings) do
	print("  ! " .. relevantWarnings[i])
end
for _, f in ipairs(failures) do
	print("\27[31m  ✗ " .. f .. "\27[0m")
end
if failed > 0 or #H.errors > 0 then
	process.exit(1)
end
print("\27[32mTODAS LAS PRUEBAS PASAN\27[0m")
