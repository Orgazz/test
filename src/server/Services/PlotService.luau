--!nonstrict
-- Asignacion de parcelas, botones de compra y reconstruccion visual.
-- Solo el dueno puede activar los botones de su parcela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent.World
local PlotBuilder = require(World.PlotBuilder)
local Palettes = require(World.Palettes)
local Config = require(ReplicatedStorage.TinyEmpireShared.Config)
local Economy = require(ReplicatedStorage.TinyEmpireShared.Economy)
local Format = require(ReplicatedStorage.TinyEmpireShared.Format)

local PlotService = {}

local plots = {} -- [index] = { def, model, pads, owner }
local byPlayer = {} -- [Player] = plot
local padHandler = nil -- function(player, plot, kind, target)
local nonOwnerWarned = {} -- [Player] = os.clock()

local GREEN = Color3.fromRGB(80, 230, 110)
local RED = Color3.fromRGB(240, 80, 80)
local BLUE = Color3.fromRGB(80, 170, 255)
local GOLD = Color3.fromRGB(255, 200, 60)

function PlotService.init(defs, parent, onPad)
	padHandler = onPad
	for _, def in ipairs(defs) do
		local model, pads = PlotBuilder.create(parent, def)
		local plot = { def = def, model = model, pads = pads, owner = nil, index = def.index }
		plots[def.index] = plot
		PlotBuilder.buildZones(model, def, 0)
		for key, pad in pairs(pads) do
			PlotBuilder.setPadVisible(pad.model, false)
			local debounce = {}
			pad.touch.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if not player then
					return
				end
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end
				local now = os.clock()
				if debounce[player] and now - debounce[player] < 0.8 then
					return
				end
				debounce[player] = now
				if plot.owner ~= player then
					-- Proteccion: nadie puede modificar parcelas ajenas
					if not nonOwnerWarned[player] or now - nonOwnerWarned[player] > 4 then
						nonOwnerWarned[player] = now
						if padHandler then
							padHandler(player, nil, "notOwner", nil)
						end
					end
					return
				end
				if not pad.model:GetAttribute("Visible") then
					return
				end
				if padHandler then
					padHandler(player, plot, pad.model:GetAttribute("Kind"), pad.model:GetAttribute("Target"))
				end
			end)
			local _ = key
		end
		PlotBuilder.setOwnerText(model, "🏗️ PARCELA LIBRE")
		PlotBuilder.setStatsText(model, "Disponible")
	end
	Players.PlayerRemoving:Connect(function(player)
		nonOwnerWarned[player] = nil
	end)
end

function PlotService.assign(player)
	if byPlayer[player] then
		return byPlayer[player]
	end
	for i = 1, Config.MaxPlots do
		local plot = plots[i]
		if plot and plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			plot.model:SetAttribute("Owner", player.UserId)
			plot.model:SetAttribute("OwnerName", player.DisplayName)
			PlotBuilder.setOwnerText(plot.model, "🏠 " .. player.DisplayName, Color3.fromRGB(255, 240, 150))
			return plot
		end
	end
	return nil
end

function PlotService.get(player)
	return byPlayer[player]
end

function PlotService.all()
	return plots
end

function PlotService.release(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	plot.model:SetAttribute("Owner", 0)
	plot.model:SetAttribute("OwnerName", "")
	plot.model.Buildings:ClearAllChildren()
	plot.model.Extras:ClearAllChildren()
	PlotBuilder.buildZones(plot.model, plot.def, 0)
	for _, pad in pairs(plot.pads) do
		PlotBuilder.setPadVisible(pad.model, false)
	end
	PlotBuilder.setOwnerText(plot.model, "🏗️ PARCELA LIBRE")
	PlotBuilder.setStatsText(plot.model, "Disponible")
end

function PlotService.palette(plot, state)
	local premium = state.passes.theme and (state.data.settings.theme ~= false)
	return Palettes.forPlot(plot.def.neighborhood, premium)
end

function PlotService.spawnCFrame(plot)
	return plot.def.cframe * PlotBuilder.SpawnOffset
end

-- Posicion local respecto a la parcela (para saber si un jugador esta dentro)
function PlotService.isInside(plot, position)
	local rel = plot.def.cframe:PointToObjectSpace(position)
	return math.abs(rel.X) <= 61 and math.abs(rel.Z) <= 61
end

function PlotService.buildBusiness(plot, state, id, animate)
	local level = state.data.businesses[id] or 0
	if level <= 0 then
		local existing = plot.model.Buildings:FindFirstChild(id)
		if existing then
			existing:Destroy()
		end
		return
	end
	local m = PlotBuilder.buildBusiness(plot.model, plot.def, id, level, PlotService.palette(plot, state))
	m:SetAttribute("Owner", state.player.UserId)
	if animate then
		m:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
	end
	return m
end

-- Reconstruye la parcela entera a partir de los datos
function PlotService.rebuildAll(plot, state)
	plot.model.Buildings:ClearAllChildren()
	PlotBuilder.buildZones(plot.model, plot.def, state.data.expansions or 0)
	for _, b in ipairs(Config.Businesses) do
		if (state.data.businesses[b.id] or 0) > 0 then
			PlotService.buildBusiness(plot, state, b.id, false)
		end
	end
	PlotService.rebuildExtras(plot, state)
	PlotService.updateIncomeAttributes(plot, state)
	PlotService.updatePads(plot, state)
end

function PlotService.rebuildExtras(plot, state)
	PlotBuilder.buildExtras(plot.model, plot.def, state.data, PlotService.palette(plot, state), state.passes.decor)
end

function PlotService.rebuildZones(plot, state)
	PlotBuilder.buildZones(plot.model, plot.def, state.data.expansions or 0)
end

-- Atributo de ingreso por edificio (el cliente muestra "+$" flotantes)
function PlotService.updateIncomeAttributes(plot, state)
	for _, m in ipairs(plot.model.Buildings:GetChildren()) do
		local id = m:GetAttribute("Business")
		if id then
			m:SetAttribute("Income", Economy.businessIncome(state.data, id, state.passes.x2))
		end
	end
end

-- Actualiza colores y textos de los botones segun el dinero actual
function PlotService.updatePads(plot, state)
	local data = state.data
	local cash = data.cash
	for _, b in ipairs(Config.Businesses) do
		local pad = plot.pads[b.id].model
		local st = Economy.businessState(data, b.id)
		if st == "available" then
			PlotBuilder.setPadVisible(pad, true)
			local afford = cash >= b.cost
			PlotBuilder.setPadStyle(pad, b.icon .. " " .. b.name, b.cost == 0 and "¡GRATIS!" or Format.cash(b.cost), afford and GREEN or RED)
		elseif st == "owned" then
			local level = data.businesses[b.id]
			local cost = Economy.levelUpCost(b.id, level)
			if cost then
				PlotBuilder.setPadVisible(pad, true)
				local afford = cash >= cost
				PlotBuilder.setPadStyle(pad, "⬆️ Nivel " .. (level + 1), Format.cash(cost), afford and BLUE or RED)
			else
				PlotBuilder.setPadVisible(pad, false)
			end
		else
			PlotBuilder.setPadVisible(pad, false)
		end
	end
	for i, exp in ipairs(Config.Expansions) do
		local pad = plot.pads["exp" .. i].model
		local st, reason = Economy.expansionState(data, i)
		if st == "available" then
			PlotBuilder.setPadVisible(pad, true)
			PlotBuilder.setPadStyle(pad, "🚧 " .. exp.name, Format.cash(exp.cost), cash >= exp.cost and GOLD or RED)
		elseif st == "locked" and (data.expansions or 0) == i - 1 then
			PlotBuilder.setPadVisible(pad, true)
			PlotBuilder.setPadStyle(pad, "🔒 " .. exp.name, reason, Color3.fromRGB(130, 130, 140))
		else
			PlotBuilder.setPadVisible(pad, false)
		end
	end
end

function PlotService.updateStats(plot, state, income)
	PlotBuilder.setStatsText(plot.model, "💰 " .. Format.cash(income) .. "/s")
end

return PlotService
