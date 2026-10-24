--!nocheck
-- Arnes de pruebas para Lune: emula el motor de Roblox lo suficiente para ejecutar
-- los scripts reales del juego (servidor y cliente) con tiempo virtual.
--
--  * Las instancias son reales de @lune/roblox (las propiedades se validan contra
--    la API de Roblox) envueltas en un proxy que anade eventos y metodos del motor.
--  * Planificador virtual: task.wait / delay / defer / spawn sin esperas reales.
--  * Servicios simulados: Players, RunService, DataStoreService, MarketplaceService,
--    CollectionService, TweenService, HttpService, SoundService, StarterGui.

local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local H = {}

H.errors = {}
H.warnings = {}
H.logs = {}

------------------------------------------------------------------------------
-- Planificador con tiempo virtual
------------------------------------------------------------------------------

local Sched = { now = 0, seq = 0, queue = {} }
H.Sched = Sched
H.epoch = 1_800_000_000 -- os.time() inicial virtual

local function recordError(err, co)
	local trace = co and debug.traceback(co, tostring(err)) or tostring(err)
	table.insert(H.errors, trace)
	print("\27[31m[ERROR] " .. trace .. "\27[0m")
end

local function resume(co, ...)
	if coroutine.status(co) == "dead" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		recordError(err, co)
	end
end

local function schedule(co, at, args)
	Sched.seq += 1
	table.insert(Sched.queue, { at = at, seq = Sched.seq, co = co, args = args })
end

local task = {}
function task.spawn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	schedule(co, Sched.now, table.pack(...))
	return co
end
function task.delay(t, fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	schedule(co, Sched.now + (t or 0), table.pack(...))
	return co
end
function task.wait(t)
	t = math.max(t or 0, 0.0001)
	local co = coroutine.running()
	local start = Sched.now
	schedule(co, Sched.now + t, { n = 0 })
	coroutine.yield()
	return Sched.now - start
end
function task.cancel(co)
	for i = #Sched.queue, 1, -1 do
		if Sched.queue[i].co == co then
			table.remove(Sched.queue, i)
		end
	end
end

local frameSignals = {}

function Sched.runUntil(target)
	while true do
		local bestIndex, best = nil, nil
		for i, e in ipairs(Sched.queue) do
			if e.at <= target and (not best or e.at < best.at or (e.at == best.at and e.seq < best.seq)) then
				best, bestIndex = e, i
			end
		end
		if not best then
			break
		end
		table.remove(Sched.queue, bestIndex)
		Sched.now = math.max(Sched.now, best.at)
		resume(best.co, table.unpack(best.args, 1, best.args.n))
	end
	Sched.now = math.max(Sched.now, target)
end

-- Avanza el tiempo virtual disparando Heartbeat/RenderStepped cada `dt`
function H.advance(seconds, dt)
	dt = dt or 0.25
	local target = Sched.now + seconds
	while Sched.now < target - 1e-9 do
		local stepTo = math.min(target, Sched.now + dt)
		Sched.runUntil(stepTo)
		for _, sig in ipairs(frameSignals) do
			sig:Fire(dt)
		end
		for _, hook in ipairs(H.frameHooks) do
			hook(dt)
		end
	end
	Sched.runUntil(target)
end

-- Ganchos opcionales (los usa tools/sim.luau para el video)
H.frameHooks = {}
H.tweenOverride = nil -- function(inst, info, goals) -> tween
H.onCreate = nil -- function(proxy, className)

------------------------------------------------------------------------------
-- Senales
------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new(name)
	return setmetatable({ name = name, handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local conn = { connected = true, fn = fn }
	conn.Disconnect = function()
		conn.connected = false
	end
	conn.Connected = true
	table.insert(self.handlers, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, conn in ipairs(table.clone(self.handlers)) do
		if conn.connected then
			task.spawn(conn.fn, ...)
		end
	end
end

H.Signal = Signal

------------------------------------------------------------------------------
-- Proxies de instancias
------------------------------------------------------------------------------

-- Lune crea un userdata nuevo en cada acceso: la identidad se basa en GetDebugId()
local function idOf(real)
	return real:GetDebugId()
end
local realToProxy = {} -- id -> proxy
local proxyToReal = setmetatable({}, { __mode = "k" })
local customOf = setmetatable({}, { __mode = "k" }) -- proxy -> tabla de miembros simulados
local signalsOf = {} -- id -> { [name] = Signal }
local destroyed = {} -- id -> true

local EVENTS = {}
for _, n in ipairs({
	"Touched", "TouchEnded", "ChildAdded", "ChildRemoved", "DescendantAdded", "AncestryChanged", "Changed",
	"Activated", "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click",
	"OnServerEvent", "OnClientEvent", "Event", "PlayerAdded", "PlayerRemoving", "CharacterAdded",
	"CharacterRemoving", "Heartbeat", "RenderStepped", "Stepped", "PromptGamePassPurchaseFinished",
	"PromptProductPurchaseFinished", "Died", "Completed", "FocusLost", "InputBegan",
}) do
	EVENTS[n] = true
end

local PROP_DEFAULTS = {
	Transparency = 0,
	Health = 100,
	MaxHealth = 100,
	Reflectance = 0,
	LocalTransparencyModifier = 0,
	Enabled = true,
	Visible = true,
	TextTransparency = 0,
	BackgroundTransparency = 0,
	Rotation = 0,
	Scale = 1,
	Thickness = 1,
	Active = false,
	AutoButtonColor = true,
	AssemblyLinearVelocity = roblox.Vector3.zero,
	AssemblyAngularVelocity = roblox.Vector3.zero,
}

local wrap, unwrap

local function isReal(v)
	return typeof(v) == "Instance"
end

local function unwrapArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = unwrap(args[i])
	end
	return table.unpack(args, 1, args.n)
end

local function wrapResults(...)
	local res = table.pack(...)
	for i = 1, res.n do
		local v = res[i]
		if isReal(v) then
			res[i] = wrap(v)
		elseif type(v) == "table" and getmetatable(v) == nil then
			local copy = {}
			for k, x in pairs(v) do
				copy[k] = isReal(x) and wrap(x) or x
			end
			res[i] = copy
		end
	end
	return table.unpack(res, 1, res.n)
end

local function getSignal(real, name)
	local id = idOf(real)
	local sigs = signalsOf[id]
	if not sigs then
		sigs = {}
		signalsOf[id] = sigs
	end
	if not sigs[name] then
		sigs[name] = Signal.new(name)
	end
	return sigs[name]
end
H.getSignal = function(proxy, name)
	return getSignal(proxyToReal[proxy], name)
end

local tagAdded = {}
local tagRemoved = {}
local function tagSignal(map, tag)
	if not map[tag] then
		map[tag] = Signal.new(tag)
	end
	return map[tag]
end

-- Metodos implementados por el arnes (Lune no los trae)
local Methods = {}

-- Metodos del motor que en las pruebas no hacen nada
function Methods.ChangeState(_self, _state) end
function Methods.SetNetworkOwner(_self, _owner) end

function Methods.GetPivot(self)
	local real = proxyToReal[self]
	if real:IsA("BasePart") then
		return real.CFrame
	end
	if real:IsA("Model") then
		local primary = real.PrimaryPart
		if primary then
			return primary.CFrame
		end
		local ok, wp = pcall(function()
			return real.WorldPivot
		end)
		return ok and wp or roblox.CFrame.new()
	end
	return roblox.CFrame.new()
end

function Methods.PivotTo(self, cf)
	local real = proxyToReal[self]
	if real:IsA("BasePart") then
		real.CFrame = cf
		return
	end
	local current = Methods.GetPivot(self)
	local delta = cf * current:Inverse()
	for _, d in ipairs(real:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	if real:IsA("Model") then
		real.WorldPivot = cf
	end
end

function Methods.GetExtentsSize(_self)
	return roblox.Vector3.new(10, 10, 10)
end

function Methods.WaitForChild(self, name, timeout)
	local real = proxyToReal[self]
	local waited = 0
	while true do
		local c = real:FindFirstChild(name)
		if c then
			return wrap(c)
		end
		if timeout and waited >= timeout then
			return nil
		end
		if waited > 60 then
			table.insert(H.warnings, "WaitForChild infinito: " .. real:GetFullName() .. "." .. name)
			return nil
		end
		waited += task.wait(0.1)
	end
end

function Methods.GetPropertyChangedSignal(self, prop)
	return getSignal(proxyToReal[self], "Changed_" .. prop)
end

function Methods.GetAttributeChangedSignal(self, prop)
	return getSignal(proxyToReal[self], "AttrChanged_" .. prop)
end

function Methods.AddTag(self, tag)
	local real = proxyToReal[self]
	real:AddTag(tag)
	tagSignal(tagAdded, tag):Fire(self)
end

function Methods.Destroy(self)
	local real = proxyToReal[self]
	if destroyed[idOf(real)] then
		return
	end
	local parent = real.Parent
	for _, d in ipairs(real:GetDescendants()) do
		for _, tag in ipairs(d:GetTags()) do
			tagSignal(tagRemoved, tag):Fire(wrap(d))
		end
	end
	for _, tag in ipairs(real:GetTags()) do
		tagSignal(tagRemoved, tag):Fire(self)
	end
	destroyed[idOf(real)] = true
	real:Destroy()
	if parent then
		getSignal(parent, "ChildRemoved"):Fire(self)
	end
end

function Methods.ClearAllChildren(self)
	local real = proxyToReal[self]
	for _, c in ipairs(real:GetChildren()) do
		Methods.Destroy(wrap(c))
	end
end

function Methods.IsDescendantOf(self, other)
	local real = proxyToReal[self]
	local target = unwrap(other)
	local node = real.Parent
	while node do
		if node == target then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Propiedades derivadas
local Getters = {}
function Getters.Position(real)
	if real:IsA("BasePart") then
		return real.CFrame.Position
	end
	return nil
end
function Getters.Orientation(_real)
	return roblox.Vector3.new()
end

local Setters = {}
function Setters.Position(real, v)
	if real:IsA("BasePart") then
		local cf = real.CFrame
		real.CFrame = cf - cf.Position + v
		return true
	end
	return false
end

local ProxyMT = {}

ProxyMT.__index = function(self, key)
	local custom = customOf[self]
	if custom then
		local v = custom[key]
		if v ~= nil then
			return v
		end
	end
	local real = proxyToReal[self]
	if destroyed[idOf(real)] and key == "Parent" then
		return nil
	end
	if EVENTS[key] then
		return getSignal(real, key)
	end
	if Methods[key] then
		return Methods[key]
	end
	if key == "Fire" and real:IsA("BindableEvent") then
		return function(_, ...)
			getSignal(real, "Event"):Fire(...)
		end
	end
	if Getters[key] then
		local v = Getters[key](real)
		if v ~= nil then
			return v
		end
	end
	local ok, v = pcall(function()
		return real[key]
	end)
	if not ok then
		local msg = tostring(v)
		if msg:find("missing default value") then
			return PROP_DEFAULTS[key]
		end
		error(msg:gsub("\n.*", ""), 2)
	end
	if type(v) == "function" then
		return function(selfArg, ...)
			if selfArg == self then
				selfArg = real
			else
				selfArg = unwrap(selfArg)
			end
			return wrapResults(v(selfArg, unwrapArgs(...)))
		end
	end
	if isReal(v) then
		return wrap(v)
	end
	return v
end

ProxyMT.__newindex = function(self, key, value)
	local custom = customOf[self]
	if custom and (custom[key] ~= nil or custom.__acceptAll) then
		custom[key] = value
		return
	end
	local real = proxyToReal[self]
	if Setters[key] and Setters[key](real, value) then
		return
	end
	if key == "Parent" then
		local oldParent = real.Parent
		local newParent = unwrap(value)
		if destroyed[idOf(real)] then
			error("The Parent property of " .. real.Name .. " is locked", 2)
		end
		real.Parent = newParent
		if oldParent and oldParent ~= newParent then
			getSignal(oldParent, "ChildRemoved"):Fire(self)
		end
		if newParent and oldParent ~= newParent then
			getSignal(newParent, "ChildAdded"):Fire(self)
		end
		return
	end
	local ok, err = pcall(function()
		real[key] = unwrap(value)
	end)
	if not ok then
		error(tostring(err):gsub("\n.*", "") .. " (" .. real.ClassName .. "." .. tostring(key) .. ")", 2)
	end
	local sigs = signalsOf[idOf(real)]
	if sigs and sigs["Changed_" .. key] then
		sigs["Changed_" .. key]:Fire()
	end
end

ProxyMT.__tostring = function(self)
	return "Proxy<" .. tostring(proxyToReal[self]) .. ">"
end

function wrap(real, custom)
	if real == nil then
		return nil
	end
	if not isReal(real) then
		return real
	end
	local id = idOf(real)
	local p = realToProxy[id]
	if not p then
		p = setmetatable({}, ProxyMT)
		realToProxy[id] = p
		proxyToReal[p] = real
	end
	if custom then
		customOf[p] = custom
	end
	return p
end

function unwrap(v)
	if type(v) == "table" and proxyToReal[v] then
		return proxyToReal[v]
	end
	return v
end

H.wrap = wrap
H.unwrap = unwrap
H.customOf = function(p)
	return customOf[p]
end

------------------------------------------------------------------------------
-- Datos serializables (DataStore y remotos)
------------------------------------------------------------------------------

local function deepCopy(v, seen, path, strict)
	seen = seen or {}
	path = path or "root"
	local t = type(v)
	if t == "table" then
		if proxyToReal[v] then
			if strict then
				error("DataStore: no se pueden guardar instancias en " .. path)
			end
			return v
		end
		if seen[v] then
			error("Referencia ciclica en " .. path)
		end
		seen[v] = true
		local out = {}
		local n = #v
		local count = 0
		for k, x in pairs(v) do
			count += 1
			if strict then
				if type(k) ~= "string" and type(k) ~= "number" then
					error("DataStore: clave no valida en " .. path)
				end
				if type(k) == "number" and (k < 1 or k > n or k % 1 ~= 0) then
					error("DataStore: tabla con claves numericas dispersas en " .. path .. " (clave " .. tostring(k) .. ")")
				end
			end
			out[k] = deepCopy(x, seen, path .. "." .. tostring(k), strict)
		end
		if strict and n > 0 and count ~= n then
			error("DataStore: tabla mixta (array + diccionario) en " .. path)
		end
		seen[v] = nil
		return out
	elseif t == "number" then
		if strict and (v ~= v or v == math.huge or v == -math.huge) then
			error("DataStore: numero no valido en " .. path)
		end
		return v
	elseif t == "string" or t == "boolean" or t == "nil" then
		return v
	elseif strict then
		error("DataStore: tipo no serializable (" .. typeof(v) .. ") en " .. path)
	end
	return v
end
H.deepCopy = deepCopy

------------------------------------------------------------------------------
-- Entorno de juego
------------------------------------------------------------------------------

function H.loadPlace(path)
	local place = roblox.deserializePlace(fs.readFile(path))
	H.place = place
	H.game = wrap(place)
	return H.game
end

local function newService(name, members)
	local folder = roblox.Instance.new("Folder")
	folder.Name = name
	return wrap(folder, members)
end

function H.setup(opts)
	opts = opts or {}
	local game = H.game
	local place = H.place
	local frameHeartbeat = Signal.new("Heartbeat")
	local frameRender = Signal.new("RenderStepped")
	local frameStepped = Signal.new("Stepped")
	table.insert(frameSignals, frameHeartbeat)
	table.insert(frameSignals, frameStepped)
	table.insert(frameSignals, frameRender)

	H.isStudio = opts.studio ~= false

	-- Players
	local playersReal = place:GetService("Players")
	local players = wrap(playersReal, {
		PlayerAdded = Signal.new("PlayerAdded"),
		PlayerRemoving = Signal.new("PlayerRemoving"),
		CharacterAutoLoads = true,
		MaxPlayers = 8,
		GetPlayers = function()
			local list = {}
			for _, c in ipairs(playersReal:GetChildren()) do
				if c:IsA("Player") then
					table.insert(list, wrap(c))
				end
			end
			return list
		end,
		GetPlayerByUserId = function(_, id)
			for _, c in ipairs(playersReal:GetChildren()) do
				if c:IsA("Player") and c.UserId == id then
					return wrap(c)
				end
			end
			return nil
		end,
		GetPlayerFromCharacter = function(_, model)
			if model == nil then
				return nil
			end
			for _, c in ipairs(playersReal:GetChildren()) do
				local pc = customOf[wrap(c)]
				if pc and pc.Character == model then
					return wrap(c)
				end
			end
			return nil
		end,
	})
	H.players = players

	local runService = newService("RunService", {
		Heartbeat = frameHeartbeat,
		RenderStepped = frameRender,
		Stepped = frameStepped,
		IsStudio = function()
			return H.isStudio
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
	})

	-- DataStore simulado con validacion de datos y fallos inyectables
	H.dataStores = {}
	H.dataStoreFailures = 0
	H.dataStoreDisabled = opts.dataStoreDisabled == true
	H.dataStoreCalls = 0
	local dataStoreService = newService("DataStoreService", {
		GetDataStore = function(_, name)
			if H.dataStoreDisabled then
				error("StudioAccessToApisNotAllowed: You must enable Studio Access to API Services")
			end
			local store = H.dataStores[name]
			if store then
				return store
			end
			local data = {}
			store = {
				_data = data,
				UpdateAsync = function(_, key, transform)
					H.dataStoreCalls += 1
					task.wait(0.05)
					if H.dataStoreFailures > 0 then
						H.dataStoreFailures -= 1
						error("502: API Services rejected request (simulado)")
					end
					local old = data[key] ~= nil and deepCopy(data[key]) or nil
					local new = transform(old)
					if new == nil then
						return nil
					end
					data[key] = deepCopy(new, nil, key, true)
					return deepCopy(data[key])
				end,
				GetAsync = function(_, key)
					return data[key] and deepCopy(data[key]) or nil
				end,
				SetAsync = function(_, key, value)
					data[key] = deepCopy(value, nil, key, true)
				end,
			}
			H.dataStores[name] = store
			return store
		end,
	})

	-- Marketplace simulado
	H.ownedPasses = {} -- [userId] = { [passId] = true }
	H.prompts = {}
	local marketplace = newService("MarketplaceService", {
		ProcessReceipt = false,
		PromptGamePassPurchaseFinished = Signal.new("PromptGamePassPurchaseFinished"),
		UserOwnsGamePassAsync = function(_, userId, passId)
			task.wait(0.05)
			return H.ownedPasses[userId] ~= nil and H.ownedPasses[userId][passId] == true
		end,
		GetProductInfo = function(_, id, _infoType)
			task.wait(0.05)
			return { Name = "Item " .. tostring(id), IconImageAssetId = 900000 + id }
		end,
		PromptGamePassPurchase = function(_, player, id)
			table.insert(H.prompts, { kind = "pass", player = player, id = id })
		end,
		PromptProductPurchase = function(_, player, id)
			table.insert(H.prompts, { kind = "product", player = player, id = id })
		end,
	})
	customOf[marketplace].__acceptAll = true

	local collection = newService("CollectionService", {
		GetTagged = function(_, tag)
			local out = {}
			for _, d in ipairs(place:GetDescendants()) do
				if d:HasTag(tag) then
					table.insert(out, wrap(d))
				end
			end
			return out
		end,
		GetInstanceAddedSignal = function(_, tag)
			return tagSignal(tagAdded, tag)
		end,
		GetInstanceRemovedSignal = function(_, tag)
			return tagSignal(tagRemoved, tag)
		end,
		HasTag = function(_, inst, tag)
			return unwrap(inst):HasTag(tag)
		end,
		AddTag = function(_, inst, tag)
			Methods.AddTag(inst, tag)
		end,
	})

	H.collisionGroups = {}
	local physicsService = newService("PhysicsService", {
		RegisterCollisionGroup = function(_, name)
			H.collisionGroups[name] = H.collisionGroups[name] or {}
		end,
		IsCollisionGroupRegistered = function(_, name)
			return name == "Default" or H.collisionGroups[name] ~= nil
		end,
		CollisionGroupSetCollidable = function(_, a, b, value)
			assert(H.collisionGroups[a] or a == "Default", "grupo no registrado: " .. a)
			assert(H.collisionGroups[b] or b == "Default", "grupo no registrado: " .. b)
			H.collisionGroups[a][b] = value
		end,
	})
	local userInput = newService("UserInputService", {
		InputBegan = Signal.new("InputBegan"),
		InputEnded = Signal.new("InputEnded"),
		TouchEnabled = false,
		KeyboardEnabled = true,
		GetFocusedTextBox = function()
			return nil
		end,
	})
	H.userInput = userInput

	local tweenService = newService("TweenService", {
		Create = function(_, inst, _info, goals)
			if H.tweenOverride then
				return H.tweenOverride(inst, _info, goals)
			end
			local tween = { Completed = Signal.new("Completed") }
			function tween:Play()
				for k, v in pairs(goals) do
					inst[k] = v
				end
				tween.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end
			function tween:Cancel() end
			function tween:Pause() end
			return tween
		end,
	})

	local guidCounter = 0
	local httpService = newService("HttpService", {
		GenerateGUID = function()
			guidCounter += 1
			return string.format("GUID-%08d", guidCounter)
		end,
	})

	local soundServiceReal = place:GetService("SoundService")
	local soundService = wrap(soundServiceReal, {
		PlayLocalSound = function() end,
	})
	local starterGui = wrap(place:GetService("StarterGui"), {
		SetCoreGuiEnabled = function() end,
		SetCore = function() end,
	})

	local workspaceReal = place:GetService("Workspace")
	local camera = roblox.Instance.new("Camera")
	camera.Name = "Camera"
	camera.CFrame = roblox.CFrame.new(0, 50, 100)
	camera.Parent = workspaceReal
	local cameraProxy = wrap(camera, {
		ViewportSize = roblox.Vector2.new(1366, 768),
	})
	local workspace = wrap(workspaceReal, {
		GetServerTimeNow = function()
			return H.epoch + Sched.now
		end,
		CurrentCamera = cameraProxy,
	})
	H.workspace = workspace

	H.bindToClose = {}
	local services = {
		Players = players,
		RunService = runService,
		DataStoreService = dataStoreService,
		MarketplaceService = marketplace,
		CollectionService = collection,
		PhysicsService = physicsService,
		UserInputService = userInput,
		TweenService = tweenService,
		HttpService = httpService,
		SoundService = soundService,
		StarterGui = starterGui,
		Workspace = workspace,
	}
	H.services = services
	customOf[game] = {
		JobId = "server-test-1",
		GetService = function(_, name)
			if services[name] then
				return services[name]
			end
			return wrap(place:GetService(name))
		end,
		BindToClose = function(_, fn)
			table.insert(H.bindToClose, fn)
		end,
	}
	return game
end

------------------------------------------------------------------------------
-- Realms (servidor / cliente) y require
------------------------------------------------------------------------------

local RandomMock = {}
RandomMock.__index = RandomMock
function RandomMock.new(seed)
	local state = math.floor(tonumber(seed) or os.time()) % 2147483647
	if state <= 0 then
		state = 12345
	end
	return setmetatable({ state = state }, RandomMock)
end
function RandomMock:_next()
	self.state = (self.state * 16807) % 2147483647
	return self.state / 2147483647
end
function RandomMock:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
function RandomMock:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + self:_next() * (b - a)
end

local TweenInfoMock = {
	new = function(time, style, dir, repeatCount, reverses, delayTime)
		return { Time = time or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = repeatCount, Reverses = reverses, DelayTime = delayTime }
	end,
}

-- Lune 0.8.9 invierte CFrame.lookAt (mira en sentido contrario). Version correcta:
local CFrameFixed = setmetatable({
	lookAt = function(pos, target, up)
		up = up or roblox.Vector3.yAxis
		local look = (target - pos).Unit
		local right = look:Cross(up)
		if right.Magnitude < 1e-6 then
			right = roblox.Vector3.xAxis
		end
		right = right.Unit
		local up2 = right:Cross(look).Unit
		return roblox.CFrame.fromMatrix(pos, right, up2, -look)
	end,
}, { __index = roblox.CFrame })
H.CFrame = CFrameFixed

local InstanceMock = {
	new = function(className, parent)
		local p = wrap(roblox.Instance.new(className))
		if parent then
			p.Parent = parent
		end
		if H.onCreate then
			H.onCreate(p, className)
		end
		return p
	end,
}

local function makeEnv(realm, scriptProxy)
	local base = {
		-- Luau
		math = math, string = string, table = table, coroutine = coroutine, utf8 = utf8, bit32 = bit32,
		pairs = pairs, ipairs = ipairs, next = next, select = select, type = type, typeof = function(v)
			if type(v) == "table" and proxyToReal[v] then
				return "Instance"
			end
			return typeof(v)
		end,
		tostring = tostring, tonumber = tonumber, pcall = pcall, xpcall = xpcall, error = error, assert = assert,
		setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset, rawequal = rawequal,
		unpack = table.unpack, buffer = buffer, vector = vector,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			table.insert(H.logs, "[" .. realm.name .. "] " .. table.concat(parts, " "))
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			local msg = "[" .. realm.name .. "] " .. table.concat(parts, " ")
			table.insert(H.warnings, msg)
		end,
		os = {
			time = function()
				return H.epoch + math.floor(Sched.now)
			end,
			clock = function()
				return Sched.now
			end,
			date = os.date,
		},
		tick = function()
			return H.epoch + Sched.now
		end,
		task = task,
		wait = task.wait,
		delay = task.delay,
		spawn = task.spawn,
		-- Roblox
		game = realm.game,
		workspace = realm.game:GetService("Workspace"),
		script = scriptProxy,
		Instance = InstanceMock,
		Enum = roblox.Enum,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrameFixed,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Rect = roblox.Rect,
		PhysicalProperties = roblox.PhysicalProperties,
		Ray = roblox.Ray,
		Random = RandomMock,
		TweenInfo = TweenInfoMock,
	}
	base.require = function(target)
		return realm.require(target)
	end
	return base
end

function H.newRealm(name, gameProxy)
	local realm = { name = name, game = gameProxy, cache = {} }
	function realm.require(moduleProxy)
		local real = unwrap(moduleProxy)
		local key = idOf(real)
		if realm.cache[key] ~= nil then
			return realm.cache[key].value
		end
		assert(real and real:IsA("ModuleScript"), "require: no es un ModuleScript")
		local fn = luau.load(real.Source, {
			debugName = real:GetFullName(),
			environment = makeEnv(realm, wrap(real)),
		})
		local result = fn()
		realm.cache[key] = { value = result }
		return result
	end
	function realm.runScript(scriptProxy)
		local real = unwrap(scriptProxy)
		local fn = luau.load(real.Source, {
			debugName = real:GetFullName(),
			environment = makeEnv(realm, wrap(real)),
		})
		task.spawn(fn)
	end
	return realm
end

-- Juego visto desde un cliente: Players.LocalPlayer y remotos hacia el servidor
function H.clientGame(player)
	local game = H.game
	local services = table.clone(H.services)
	services.Players = wrap(roblox.Instance.new("Folder"), setmetatable({ LocalPlayer = player }, { __index = customOf[H.players] }))
	local rs = table.clone(customOf[services.RunService])
	rs.IsServer = function()
		return false
	end
	rs.IsClient = function()
		return true
	end
	services.RunService = wrap(roblox.Instance.new("Folder"), rs)
	local clientGameReal = roblox.Instance.new("Folder")
	local proxy = wrap(clientGameReal, {
		JobId = "client",
		IsLoaded = function()
			return true
		end,
		GetService = function(_, name)
			if services[name] then
				return services[name]
			end
			return game:GetService(name)
		end,
	})
	return proxy
end

------------------------------------------------------------------------------
-- Jugadores simulados
------------------------------------------------------------------------------

H.clientPlayer = nil -- solo este jugador recibe eventos en el realm cliente

function H.connectRemotes(remoteFolder)
	for _, r in ipairs(remoteFolder:GetChildren()) do
		local custom = {
			FireClient = function(_, player, ...)
				local args = deepCopy(table.pack(...))
				if H.onFireClient then
					H.onFireClient(r.Name, player, table.unpack(args, 1, args.n))
				end
				if player == H.clientPlayer then
					getSignal(unwrap(r), "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
				end
			end,
			FireAllClients = function(_, ...)
				if H.clientPlayer then
					getSignal(unwrap(r), "OnClientEvent"):Fire(...)
				end
			end,
			FireServer = function(_, ...)
				local args = deepCopy(table.pack(...))
				getSignal(unwrap(r), "OnServerEvent"):Fire(H.clientPlayer, table.unpack(args, 1, args.n))
			end,
		}
		customOf[r] = custom
	end
end

local nextUserId = 1000

function H.spawnCharacter(player)
	local custom = customOf[player]
	local model = roblox.Instance.new("Model")
	model.Name = player.Name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = roblox.Vector3.new(2, 2, 1)
	root.CFrame = roblox.CFrame.new(0, 5, -44)
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = model
	model.Parent = unwrap(H.workspace)
	local proxy = wrap(model)
	custom.Character = proxy
	getSignal(unwrap(player), "CharacterAdded"):Fire(proxy)
	return proxy
end

function H.addPlayer(name, userId)
	nextUserId += 1
	userId = userId or nextUserId
	local real = roblox.Instance.new("Player")
	real.Name = name
	real.UserId = userId
	real.DisplayName = name
	local proxy
	local custom
	custom = {
		Character = false,
		kicked = nil,
		Kick = function(_, msg)
			custom.kicked = msg or "kicked"
			H.removePlayer(proxy)
		end,
	}
	proxy = wrap(real, custom)
	custom.Character = nil
	local gui = roblox.Instance.new("PlayerGui")
	gui.Parent = real
	real.Parent = unwrap(H.players)
	customOf[H.players].PlayerAdded:Fire(proxy)
	if customOf[H.players].CharacterAutoLoads then
		task.delay(0.2, function()
			if real.Parent then
				H.spawnCharacter(proxy)
			end
		end)
	end
	return proxy
end

function H.removePlayer(player)
	local real = unwrap(player)
	if not real.Parent then
		return
	end
	customOf[H.players].PlayerRemoving:Fire(player)
	local custom = customOf[player]
	if custom.Character then
		Methods.Destroy(custom.Character)
		custom.Character = nil
	end
	real.Parent = nil
end

function H.touch(player, part)
	local character = customOf[player].Character
	assert(character, "el jugador no tiene personaje")
	getSignal(unwrap(part), "Touched"):Fire(character:FindFirstChild("HumanoidRootPart"))
end

function H.shutdown()
	for _, fn in ipairs(H.bindToClose) do
		task.spawn(fn)
	end
	H.advance(30)
end

return H
