--!nonstrict
-- Compras con Robux: pases (decoracion, tema, x2) y productos de efectivo.
--  * ProcessReceipt se gestiona SOLO en el servidor.
--  * Cada recibo se registra en los datos del jugador y se guarda antes de
--    confirmar la compra -> sin duplicados aunque Roblox reintente.
--  * Con IDs = 0 y dentro de Roblox Studio, las compras se simulan para pruebas.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.TinyEmpireShared.Config)
local Economy = require(ReplicatedStorage.TinyEmpireShared.Economy)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local api = nil -- { getState, onPassGranted, onCashGranted }
local processing = {} -- [PurchaseId] = true
local MAX_RECEIPTS = 200

local productByKey = Config.Products
local passKeyById = {}
local productKeyById = {}
for key, p in pairs(Config.GamePasses) do
	if p.id and p.id > 0 then
		passKeyById[p.id] = key
	end
end
for key, p in pairs(Config.Products) do
	if p.id and p.id > 0 then
		productKeyById[p.id] = key
	end
end

function MonetizationService.simulationAllowed()
	return RunService:IsStudio()
end

-- Comprueba los pases del jugador (reales y simulados en Studio)
function MonetizationService.loadPasses(player, data)
	local passes = { decor = false, theme = false, x2 = false }
	for key, p in pairs(Config.GamePasses) do
		if p.id and p.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end)
			if ok and owns then
				passes[key] = true
			end
		end
		if MonetizationService.simulationAllowed() and data.passes and data.passes[key] then
			passes[key] = true
		end
	end
	return passes
end

local function rememberReceipt(data, purchaseId)
	data.receipts[purchaseId] = os.time()
	table.insert(data.receiptOrder, purchaseId)
	while #data.receiptOrder > MAX_RECEIPTS do
		local old = table.remove(data.receiptOrder, 1)
		data.receipts[old] = nil
	end
end

-- Concede un producto de efectivo de forma idempotente
local function grantProduct(player, key, purchaseId)
	local state = api.getState(player)
	if not state or not state.data then
		return false
	end
	local data = state.data
	if data.receipts[purchaseId] then
		return true -- ya concedido antes
	end
	local reward = Economy.productReward(data, key, state.passes.x2)
	local previousCash = data.cash
	data.cash += reward
	rememberReceipt(data, purchaseId)
	if DataService.isPersistent(player) then
		if not DataService.forceSave(player) then
			-- No se pudo guardar: revertir y dejar que Roblox reintente
			data.cash = previousCash
			data.receipts[purchaseId] = nil
			local idx = table.find(data.receiptOrder, purchaseId)
			if idx then
				table.remove(data.receiptOrder, idx)
			end
			return false
		end
	end
	api.onCashGranted(player, reward, productByKey[key])
	return true
end

local function processReceipt(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = productKeyById[receiptInfo.ProductId]
	if not key then
		warn("[TinyEmpire] Producto desconocido: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Espera a que los datos esten cargados
	local t = 0
	while (not api.getState(player) or not api.getState(player).ready) and t < 20 and player.Parent do
		task.wait(0.5)
		t += 0.5
	end
	if not api.getState(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if processing[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	processing[purchaseId] = true
	local ok, granted = pcall(grantProduct, player, key, purchaseId)
	processing[purchaseId] = nil
	if ok and granted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not ok then
		warn("[TinyEmpire] Error en ProcessReceipt: " .. tostring(granted))
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function grantPass(player, key)
	local state = api.getState(player)
	if not state then
		return
	end
	if state.passes[key] then
		return
	end
	state.passes[key] = true
	api.onPassGranted(player, key)
end

-- Compra simulada (solo Studio y solo para articulos sin ID real)
function MonetizationService.simulate(player, kind, key)
	if not MonetizationService.simulationAllowed() then
		return false, "Las compras simuladas solo funcionan en Studio."
	end
	if kind == "pass" then
		local p = Config.GamePasses[key]
		if not p or (p.id and p.id > 0) then
			return false, "Pase no valido."
		end
		local state = api.getState(player)
		if not state then
			return false, "Datos no cargados."
		end
		state.data.passes[key] = true
		grantPass(player, key)
		return true
	elseif kind == "product" then
		local p = Config.Products[key]
		if not p or (p.id and p.id > 0) then
			return false, "Producto no valido."
		end
		local ok = grantProduct(player, key, "STUDIO-" .. HttpService:GenerateGUID(false))
		if ok then
			return true
		end
		return false, "No se pudo guardar la compra."
	end
	return false, "Tipo desconocido."
end

function MonetizationService.init(gameApi)
	api = gameApi
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyById[passId]
		if key then
			grantPass(player, key)
		end
	end)
end

return MonetizationService
