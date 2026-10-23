--!nonstrict
-- Logica pura de economia compartida por servidor y cliente.
-- El servidor es la autoridad; el cliente solo la usa para mostrar precios.

local Config = require(script.Parent.Config)

local Economy = {}

function Economy.newData()
	return {
		version = 1,
		cash = Config.StartingCash,
		runEarned = 0, -- ganado desde la ultima franquicia (define el nivel de imperio)
		lifetimeEarned = 0,
		businesses = {}, -- [id] = nivel (1..5)
		upgrades = {}, -- [id] = true
		expansions = 0,
		franchises = 0,
		goalsClaimed = {}, -- [goalId] = true
		tutorial = 1,
		daily = nil,
		stats = { crates = 0, levelUps = 0, upgrades = 0, builds = 0, playSeconds = 0 },
		passes = {}, -- pases simulados en Studio (los reales se consultan a Roblox)
		settings = { decor = true, theme = true },
		receipts = {}, -- [receiptId] = os.time() (evita duplicados)
		receiptOrder = {},
		lastOnline = 0,
	}
end

-- Rellena campos que falten en datos antiguos sin perder progreso.
function Economy.reconcile(data)
	local template = Economy.newData()
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k == "stats" then
			for sk, sv in pairs(v) do
				if data[k][sk] == nil then
					data[k][sk] = sv
				end
			end
		elseif type(v) == "table" and type(data[k]) == "table" and k == "settings" then
			for sk, sv in pairs(v) do
				if data[k][sk] == nil then
					data[k][sk] = sv
				end
			end
		end
	end
	return data
end

function Economy.empireLevel(runEarned: number)
	local current = Config.EmpireLevels[1]
	local nextLevel = nil
	for i, info in ipairs(Config.EmpireLevels) do
		if runEarned >= info.need then
			current = info
			nextLevel = Config.EmpireLevels[i + 1]
		end
	end
	local progress = 1
	if nextLevel then
		progress = math.clamp((runEarned - current.need) / (nextLevel.need - current.need), 0, 1)
	end
	return current.level, current, nextLevel, progress
end

function Economy.ownedCount(data): number
	local n = 0
	for _, b in ipairs(Config.Businesses) do
		if (data.businesses[b.id] or 0) > 0 then
			n += 1
		end
	end
	return n
end

function Economy.upgradeCount(data): number
	local n = 0
	for _, u in ipairs(Config.Upgrades) do
		if data.upgrades[u.id] then
			n += 1
		end
	end
	return n
end

function Economy.globalMultiplier(data, hasX2: boolean?): number
	local bonus = 0
	for _, u in ipairs(Config.Upgrades) do
		if u.kind == "global" and data.upgrades[u.id] then
			bonus += u.value
		end
	end
	local mult = 1 + bonus
	mult *= 1 + (data.franchises or 0) * Config.Franchise.bonusPerFranchise
	if hasX2 then
		mult *= 2
	end
	return mult
end

function Economy.businessMultiplier(data, id: string): number
	local mult = 1
	for _, u in ipairs(Config.Upgrades) do
		if u.kind == "business" and u.target == id and data.upgrades[u.id] then
			mult *= u.value
		end
	end
	return mult
end

-- Ingreso por segundo de un negocio a un nivel concreto (sin multiplicador global)
function Economy.baseIncomeAt(id: string, level: number): number
	local b = Config.BusinessById[id]
	if not b or level <= 0 then
		return 0
	end
	return b.income * Config.LevelIncomeMult[math.clamp(level, 1, Config.MaxBusinessLevel)]
end

function Economy.businessIncome(data, id: string, hasX2: boolean?): number
	local level = data.businesses[id] or 0
	if level <= 0 then
		return 0
	end
	return Economy.baseIncomeAt(id, level) * Economy.businessMultiplier(data, id) * Economy.globalMultiplier(data, hasX2)
end

function Economy.totalIncome(data, hasX2: boolean?): number
	local total = 0
	for _, b in ipairs(Config.Businesses) do
		total += Economy.businessIncome(data, b.id, hasX2)
	end
	return total
end

-- Coste de subir un negocio desde `level` a `level + 1`
function Economy.levelUpCost(id: string, level: number): number?
	local b = Config.BusinessById[id]
	if not b or level < 1 or level >= Config.MaxBusinessLevel then
		return nil
	end
	local base = math.max(b.cost, 50)
	return math.floor(base * Config.LevelCostMult[level])
end

function Economy.zoneUnlocked(data, zone: number): boolean
	return zone <= (data.expansions or 0) + 1
end

-- Devuelve: estado ("owned" | "available" | "locked"), motivo
function Economy.businessState(data, id: string)
	local b = Config.BusinessById[id]
	if not b then
		return "locked", "Desconocido"
	end
	if (data.businesses[id] or 0) > 0 then
		return "owned", nil
	end
	if not Economy.zoneUnlocked(data, b.zone) then
		local exp = Config.Expansions[b.zone - 1]
		return "locked", "Necesitas: " .. (exp and exp.name or "expansión")
	end
	local prev = Config.Businesses[b.order - 1]
	if prev and (data.businesses[prev.id] or 0) <= 0 then
		return "locked", "Primero: " .. prev.name
	end
	return "available", nil
end

function Economy.upgradeState(data, id: string)
	local u = Config.UpgradeById[id]
	if not u then
		return "locked", "Desconocido"
	end
	if data.upgrades[id] then
		return "owned", nil
	end
	local tier = Config.UpgradeTiers[u.tier]
	local level = Economy.empireLevel(data.runEarned)
	if level < tier.needLevel then
		return "locked", "Nivel de imperio " .. tier.needLevel
	end
	if u.kind == "business" and (data.businesses[u.target] or 0) <= 0 then
		local b = Config.BusinessById[u.target]
		return "locked", "Necesitas: " .. (b and b.name or "?")
	end
	return "available", nil
end

function Economy.expansionState(data, index: number)
	local exp = Config.Expansions[index]
	if not exp then
		return "locked", "?"
	end
	if (data.expansions or 0) >= index then
		return "owned", nil
	end
	if (data.expansions or 0) < index - 1 then
		return "locked", "Primero: " .. Config.Expansions[index - 1].name
	end
	local level = Economy.empireLevel(data.runEarned)
	if level < exp.needLevel then
		return "locked", "Nivel de imperio " .. exp.needLevel
	end
	return "available", nil
end

function Economy.crateMultiplier(data): number
	local mult = 1
	for _, u in ipairs(Config.Upgrades) do
		if u.kind == "crate" and data.upgrades[u.id] then
			mult += u.value
		end
	end
	return mult
end

function Economy.crateReward(data, hasX2: boolean?): number
	local income = Economy.totalIncome(data, hasX2)
	return math.floor(math.max(Config.Crates.minReward, income * Config.Crates.incomeSeconds) * Economy.crateMultiplier(data))
end

function Economy.offlineSettings(data)
	if data.upgrades["u_manager"] then
		return Config.UpgradeById["u_manager"].value, Config.Offline.managerMaxSeconds
	end
	return Config.Offline.baseRate, Config.Offline.baseMaxSeconds
end

function Economy.productReward(data, key: string, hasX2: boolean?): number
	local p = Config.Products[key]
	if not p then
		return 0
	end
	local income = Economy.totalIncome(data, hasX2)
	return math.floor(math.max(p.min, income * 60 * p.incomeMinutes))
end

function Economy.maxBusinessLevel(data): number
	local m = 0
	for _, b in ipairs(Config.Businesses) do
		m = math.max(m, data.businesses[b.id] or 0)
	end
	return m
end

function Economy.goalProgress(data, goal): number
	local kind = goal.kind
	if kind == "businesses" then
		return Economy.ownedCount(data)
	elseif kind == "maxLevel" then
		return Economy.maxBusinessLevel(data)
	elseif kind == "upgrades" then
		return Economy.upgradeCount(data)
	elseif kind == "expansions" then
		return data.expansions or 0
	elseif kind == "franchise" then
		return data.franchises or 0
	elseif kind == "allMax" then
		local n = 0
		for _, b in ipairs(Config.Businesses) do
			if (data.businesses[b.id] or 0) >= Config.MaxBusinessLevel then
				n += 1
			end
		end
		return n
	end
	return 0
end

-- Primer objetivo sin reclamar (los objetivos son secuenciales)
function Economy.currentGoal(data)
	for i, goal in ipairs(Config.Goals) do
		if not data.goalsClaimed[goal.id] then
			return goal, i
		end
	end
	return nil, #Config.Goals + 1
end

function Economy.canFranchise(data): boolean
	return (data.businesses["tower"] or 0) > 0 and data.runEarned >= Config.Franchise.needEarned
end

return Economy
