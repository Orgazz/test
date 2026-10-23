--!nocheck
-- Pruebas de integracion de Tiny Empire Tycoon (ejecutar con Lune).
--   rojo build default.project.json -o build/TinyEmpireTycoon.rbxlx
--   lune run tests/run.luau build/TinyEmpireTycoon.rbxlx

local process = require("@lune/process")
local Enum = require("@lune/roblox").Enum
local Vector3 = require("@lune/roblox").Vector3
local H = require("./harness")
local CFrame = H.CFrame

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
local CrateService = server.require(ServerRoot.Services.CrateService)
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
	check(#map.Pedestrians:GetChildren() == 28, "hay 28 peatones")
	check(#game:GetService("CollectionService"):GetTagged("TE_TrafficLight") == 16, "hay 16 semaforos (avenidas y anillo)")
	check(#map.Clouds:GetChildren() == 16, "hay nubes en el cielo")
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
	client.runScript(game:GetService("ReplicatedFirst").TinyEmpireIntro.Intro)
	client.runScript(clientRoot:FindFirstChild("Main"))
	H.advance(0.5)
	check(dave.PlayerGui:FindFirstChild("TinyEmpireIntro") ~= nil, "pantalla de carga visible al entrar")
	H.advance(5)
	check(dave.PlayerGui:FindFirstChild("TinyEmpireIntro") == nil, "la pantalla de carga desaparece al terminar")
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
		local storeIcons = 0
		for _, d in ipairs(shopPage:GetDescendants()) do
			if d.Name == "StoreIcon" then
				storeIcons += 1
			end
		end
		check(storeIcons == 3, "la tienda muestra las imagenes oficiales de los articulos con ID (" .. storeIcons .. ")")
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

	--------------------------------------------------------------------------
	section("Fisicas y animaciones")
	--------------------------------------------------------------------------
	local clientScripts = clientRoot
	local Traffic = client.require(clientScripts.World.Traffic)
	local Pedestrians = client.require(clientScripts.World.Pedestrians)
	local Physics = client.require(clientScripts.Physics)
	local Animator = client.require(clientScripts.Animator)
	local character = H.customOf(dave).Character
	local root = character.HumanoidRootPart
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- Grupos de colision
	check(H.collisionGroups["TE_Effects"] and H.collisionGroups["TE_Effects"]["TE_Players"] == false, "los efectos fisicos no chocan con jugadores")
	check(root.CollisionGroup == "TE_Players", "el personaje usa el grupo de colision TE_Players")

	-- Trampolin
	local mats = game:GetService("CollectionService"):GetTagged("TE_Trampoline")
	check(#mats == 2, "hay 2 trampolines en la plaza")
	root.AssemblyLinearVelocity = Vector3.new(5, 0, 0)
	mats[1].Touched:Fire(root)
	H.advance(0.05, 0.05)
	check(root.AssemblyLinearVelocity.Y >= 100, "el trampolin impulsa al jugador hacia arriba (" .. root.AssemblyLinearVelocity.Y .. ")")
	check(root.AssemblyLinearVelocity.X > 5, "el trampolin conserva y amplia el impulso horizontal")
	local matSpring = Physics._springs[mats[1]]
	H.advance(0.1, 0.02)
	check(matSpring and matSpring.x < -0.1, "la lona del trampolin se hunde")
	H.advance(3, 0.02)
	check(math.abs(matSpring.x) < 0.05, "la lona vuelve a su sitio (muelle amortiguado)")
	local otherPlayer = H.customOf(bob).Character
	local velBefore = otherPlayer.HumanoidRootPart.AssemblyLinearVelocity
	mats[2].Touched:Fire(otherPlayer.HumanoidRootPart)
	H.advance(0.05, 0.05)
	check(otherPlayer.HumanoidRootPart.AssemblyLinearVelocity == velBefore, "cada cliente solo impulsa a su propio personaje")

	-- Sprint
	H.userInput.InputBegan:Fire({ KeyCode = Enum.KeyCode.LeftShift }, false)
	H.advance(0.3, 0.05)
	check(humanoid.WalkSpeed > 16 and humanoid.WalkSpeed < 26, "el sprint acelera progresivamente (" .. math.floor(humanoid.WalkSpeed) .. ")")
	H.advance(1.5, 0.05)
	check(math.abs(humanoid.WalkSpeed - 26) < 0.5, "velocidad de sprint alcanzada")
	check(workspace.CurrentCamera.FieldOfView == 80, "el campo de vision se abre al correr")
	H.userInput.InputEnded:Fire({ KeyCode = Enum.KeyCode.LeftShift }, false)
	H.advance(2, 0.05)
	check(math.abs(humanoid.WalkSpeed - 16) < 0.5, "al soltar Shift vuelve a caminar")

	-- Monedas fisicas al recoger un maletin
	local crate = CrateService.spawn(true)
	check(crate.Body.Anchored == false, "los maletines caen con fisica real")
	H.advance(4, 0.1)
	check(crate.Body.Anchored == true and crate:HasTag("TE_Spin"), "al asentarse se anclan y giran")
	H.touch(dave, crate.Touch)
	H.advance(0.2, 0.05)
	local coins = 0
	for _, d in ipairs(workspace:GetChildren()) do
		if d.Name == "TE_Effect" then
			coins += 1
			if d.Anchored or d.CollisionGroup ~= "TE_Effects" then
				coins = -999
			end
		end
	end
	check(coins >= 10, "al recoger un maletin saltan monedas fisicas (" .. coins .. ")")
	H.advance(3.5, 0.1)
	local left = 0
	for _, d in ipairs(workspace:GetChildren()) do
		if d.Name == "TE_Effect" then
			left += 1
		end
	end
	check(left == 0, "las monedas desaparecen solas")

	-- Lluvia de maletines
	local before = #map.Crates:GetChildren()
	CrateService.rain()
	H.advance(4, 0.1)
	check(#map.Crates:GetChildren() >= before + 6, "la lluvia de maletines suelta varios a la vez")
	check((lastNotify(dave) or ""):find("Lluvia") ~= nil, "se avisa de la lluvia de maletines")

	-- Trafico: avanzan, frenan ante un jugador y respetan los semaforos
	local cars = Traffic._cars
	check(#cars == 12, "12 coches simulados")
	local moving = 0
	for _, c in ipairs(cars) do
		if c.v > 5 then
			moving += 1
		end
	end
	check(moving >= 6, "los coches circulan (" .. moving .. " en marcha)")
	-- Poner al jugador delante del coche 1
	local car = cars[1]
	local pos, dir = Traffic._sample(car.s)
	if car.lane < 0 then
		dir = -dir
	end
	local laneRight = dir:Cross(Vector3.yAxis)
	root.CFrame = CFrame.new(pos + dir * 30 + laneRight * 5 + Vector3.new(0, 3, 0))
	car.v = car.cruise
	for _ = 1, 40 do
		H.advance(0.1, 0.1)
		local p2 = Traffic._sample(car.s)
		local _ = p2
	end
	check(car.v < 1, "el coche frena hasta pararse ante un jugador (" .. string.format("%.1f", car.v) .. ")")
	local p3 = Traffic._sample(car.s)
	check((p3 - (pos + dir * 30)).Magnitude > 4, "el coche se detiene antes de atropellar")
	root.CFrame = CFrame.new(0, 5, -44)
	H.advance(4, 0.1)
	check(car.v > 5, "cuando el jugador se aparta, el coche reanuda la marcha")

	-- Semaforos: ningun coche cruza con el rojo bien establecido
	local violations, crossings = 0, 0
	local prevS = {}
	for i, c in ipairs(cars) do
		prevS[i] = c.s
	end
	local inters = Traffic._intersections
	check(#inters == 4, "4 cruces regulados en el anillo")
	local function ahead(c, s0, s1)
		if c.lane > 0 then
			return (s1 - s0) % 2000
		end
		return (s0 - s1) % 2000
	end
	local _ = ahead
	for _ = 1, 400 do
		H.advance(0.1, 0.1)
		local t = Traffic._time or 0
		for i, c in ipairs(cars) do
			for _, inter in ipairs(inters) do
				-- cruce de la linea central del cruce en este paso
				local a0 = c.lane > 0 and (inter.s - prevS[i]) or (prevS[i] - inter.s)
				local a1 = c.lane > 0 and (inter.s - c.s) or (c.s - inter.s)
				local L = Traffic._length
				a0 %= L
				a1 %= L
				if a0 < 40 and a1 > L - 40 then
					crossings += 1
					local cycle = (t / 12 + inter.phase) % 1
					if cycle > 0.54 + 2 / 12 then
						violations += 1
						print(string.format("    infraccion: coche %d carril %d v=%.1f ciclo=%.3f s0=%.1f s1=%.1f cruce=%.1f", i, c.lane, c.v, cycle, prevS[i], c.s, inter.s))
					end
				end
			end
			prevS[i] = c.s
		end
	end
	check(crossings > 5, "los coches cruzan las intersecciones (" .. crossings .. ")")
	check(violations == 0, "ningun coche se salta un semaforo en rojo (" .. violations .. ")")

	-- Peatones
	local walkers = Pedestrians._walkers
	check(#walkers == 28, "28 peatones animados")
	local turned, idled = 0, 0
	for _ = 1, 300 do
		H.advance(0.1, 0.1)
		for _, w in ipairs(walkers) do
			if w.state == "turn" then
				turned += 1
			elseif w.state == "idle" then
				idled += 1
			end
		end
	end
	check(turned > 0, "los peatones se paran y dan la vuelta al final de la acera")
	check(idled > 0, "los peatones hacen pausas para mirar a su alrededor")
	local finite = true
	for _, w in ipairs(walkers) do
		local p = w.parts[1].part.Position
		if p.X ~= p.X or math.abs(p.Y - w.baseY) > 6 then
			finite = false
		end
	end
	check(finite, "posiciones de peatones validas")

	-- Banderas y arboles
	local flagsList = Animator._flags
	check(#flagsList == 4, "4 banderas con tela por segmentos")
	local seg = flagsList[1].segs[#flagsList[1].segs]
	local c1 = seg.CFrame
	H.advance(0.5, 0.1)
	check((seg.CFrame.Position - c1.Position).Magnitude > 0.01, "la bandera ondea")
	local swaying = 0
	for _, e in pairs(Animator._entries) do
		if e.swayMode == "tilt" then
			swaying += 1
		end
	end
	check(swaying > 100, "los arboles se mecen con el viento (" .. swaying .. ")")
	-- "+$" con trayectoria parabolica
	H.advance(4, 0.1)
	check(#H.errors == 0, "sin errores en las animaciones")
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
