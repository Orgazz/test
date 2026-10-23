--!nonstrict
-- Guardado de progreso con DataStoreService.
--  * Bloqueo de sesion para evitar que dos servidores pisen los mismos datos.
--  * Reintentos con espera creciente.
--  * Autoguardado periodico y guardado al cerrar el servidor.
--  * Si los DataStores no estan disponibles (Studio sin acceso a API), el juego
--    sigue funcionando en memoria y avisa al jugador.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.TinyEmpireShared.Config)
local Economy = require(ReplicatedStorage.TinyEmpireShared.Economy)

local DataService = {}

local SESSION_LOCK_SECONDS = 150
local MAX_ATTEMPTS = 5

local store = nil
local storeAvailable = true
local profiles = {} -- [Player] = { data, persistent, saving, released }

local function jobId()
	local id = game.JobId
	if id == nil or id == "" then
		return "studio"
	end
	return id
end

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

local function isFatal(err)
	local msg = tostring(err)
	return msg:find("StudioAccessToApisNotAllowed") ~= nil
		or msg:find("publish") ~= nil
		or msg:find("API Services") ~= nil
		or msg:find("403") ~= nil
end

local function getStore()
	if not storeAvailable then
		return nil
	end
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		return store
	end
	warn("[TinyEmpire] DataStore no disponible: " .. tostring(result))
	storeAvailable = false
	return nil
end

function DataService.isAvailable()
	return storeAvailable
end

-- Carga los datos de un jugador. Devuelve el perfil (nunca nil).
function DataService.load(player)
	local ds = getStore()
	local key = keyFor(player.UserId)
	local loaded = nil
	local persistent = false

	if ds then
		for attempt = 1, MAX_ATTEMPTS do
			if not player.Parent then
				return nil
			end
			local lockedByOther = false
			local forceTakeover = attempt == MAX_ATTEMPTS
			local ok, result = pcall(function()
				return ds:UpdateAsync(key, function(old)
					if type(old) ~= "table" then
						old = { data = Economy.newData() }
					end
					local session = old.session
					if session and session.jobId ~= jobId() and os.time() - (session.time or 0) < SESSION_LOCK_SECONDS and not forceTakeover then
						lockedByOther = true
						return nil
					end
					old.session = { jobId = jobId(), time = os.time() }
					return old
				end)
			end)
			if ok and not lockedByOther and type(result) == "table" then
				loaded = result.data
				persistent = true
				break
			elseif not ok then
				warn(string.format("[TinyEmpire] Error cargando %s (intento %d): %s", player.Name, attempt, tostring(result)))
				if isFatal(result) then
					storeAvailable = false
					break
				end
			end
			task.wait(math.min(2 * attempt, 6))
		end
	end

	if loaded == nil then
		loaded = Economy.newData()
	end
	local data = Economy.reconcile(loaded)
	local profile = {
		data = data,
		persistent = persistent,
		saving = false,
		released = false,
	}
	profiles[player] = profile
	return profile
end

function DataService.get(player)
	return profiles[player]
end

-- Guarda el perfil. `release` libera el bloqueo de sesion (al salir).
function DataService.save(player, release)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not profile.persistent then
		return true -- modo en memoria: no hay nada que guardar
	end
	local ds = getStore()
	if not ds then
		return false
	end
	-- Espera a que termine un guardado anterior
	local waited = 0
	while profile.saving and waited < 15 do
		task.wait(0.25)
		waited += 0.25
	end
	profile.saving = true
	profile.data.lastOnline = os.time()
	local stolen = false
	local ok, err = pcall(function()
		ds:UpdateAsync(keyFor(player.UserId), function(old)
			if type(old) == "table" and old.session and old.session.jobId ~= jobId() then
				-- Otro servidor tomo el control: no sobrescribir
				stolen = true
				return nil
			end
			return {
				data = profile.data,
				session = (not release) and { jobId = jobId(), time = os.time() } or nil,
			}
		end)
	end)
	profile.saving = false
	if not ok then
		warn(string.format("[TinyEmpire] Error guardando %s: %s", player.Name, tostring(err)))
		return false
	end
	if stolen then
		warn("[TinyEmpire] La sesion de " .. player.Name .. " esta activa en otro servidor; no se sobrescribe.")
		return false
	end
	return true
end

-- Guardado con reintentos (usado tras compras con Robux)
function DataService.forceSave(player)
	for attempt = 1, 3 do
		if DataService.save(player, false) then
			return true
		end
		task.wait(attempt)
	end
	return false
end

function DataService.isPersistent(player)
	local p = profiles[player]
	return p ~= nil and p.persistent
end

function DataService.release(player)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	profile.released = true
	DataService.save(player, true)
	profiles[player] = nil
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				if profiles[player] then
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if profiles[player] then
				pending += 1
				task.spawn(function()
					DataService.release(player)
					pending -= 1
				end)
			end
		end
		local t = 0
		while pending > 0 and t < 25 do
			task.wait(0.25)
			t += 0.25
		end
		if RunService:IsStudio() then
			task.wait(1)
		end
	end)
end

return DataService
