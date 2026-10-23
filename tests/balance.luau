--!nocheck
-- Simulacion rapida de balance: un jugador "codicioso" que compra siempre lo
-- mas barato disponible. Usa Config y Economy reales.
--   lune run tests/balance.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function load(path, env)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local base = setmetatable({ Color3 = roblox.Color3 }, { __index = _G })
local Config = load("src/shared/Config.luau", base)
local Economy = load("src/shared/Economy.luau", setmetatable({
	require = function()
		return Config
	end,
	script = { Parent = { Config = true } },
}, { __index = base }))

local efficiency = tonumber((...)) or 1 -- 1 = jugador perfecto; 0.5 = compra con retraso
local data = Economy.newData()
local t = 0
local milestones = {}
local function mark(k)
	if not milestones[k] then
		milestones[k] = t
	end
end
local nextAct = 0
local claimedDaily = 0
while t < 30 * 3600 do
	local income = Economy.totalIncome(data)
	data.cash += income
	data.runEarned += income
	t += 1
	if t >= nextAct then
		nextAct = t + math.floor(10 / efficiency)
		for _ = 1, 30 do
			local bestCost, bestFn = math.huge, nil
			for _, b in ipairs(Config.Businesses) do
				local s = Economy.businessState(data, b.id)
				if s == "available" and b.cost < bestCost then
					bestCost, bestFn = b.cost, function()
						data.businesses[b.id] = 1
					end
				elseif s == "owned" then
					local c = Economy.levelUpCost(b.id, data.businesses[b.id])
					if c and c < bestCost then
						bestCost, bestFn = c, function()
							data.businesses[b.id] += 1
						end
					end
				end
			end
			for _, u in ipairs(Config.Upgrades) do
				if Economy.upgradeState(data, u.id) == "available" and u.cost < bestCost then
					bestCost, bestFn = u.cost, function()
						data.upgrades[u.id] = true
					end
				end
			end
			for i, e in ipairs(Config.Expansions) do
				if Economy.expansionState(data, i) == "available" and e.cost < bestCost then
					bestCost, bestFn = e.cost, function()
						data.expansions = i
					end
				end
			end
			if bestFn and data.cash >= bestCost then
				data.cash -= bestCost
				bestFn()
			else
				break
			end
		end
		local goal = Economy.currentGoal(data)
		if goal and Economy.goalProgress(data, goal) >= goal.target then
			data.goalsClaimed[goal.id] = true
			data.cash += goal.reward
			data.runEarned += goal.reward
		end
	end
	-- Retos diarios: ~3 por dia jugado (aprox. 1 cada 2 h de juego)
	if t % 7200 == 0 and claimedDaily < 100 then
		local r = math.max(Config.DailyMinReward, Economy.totalIncome(data) * Config.DailyRewardIncomeSeconds)
		data.cash += r
		data.runEarned += r
	end
	for _, b in ipairs(Config.Businesses) do
		if (data.businesses[b.id] or 0) > 0 then
			mark(b.id)
		end
	end
	if data.expansions >= 1 then mark("exp1") end
	if data.expansions >= 2 then mark("exp2") end
	if Economy.upgradeCount(data) >= 12 then mark("12upgrades") end
	if Economy.upgradeCount(data) >= 24 then mark("24upgrades") end
	if Economy.goalProgress(data, { kind = "allMax" }) >= 10 then mark("allMax") end
	if Economy.canFranchise(data) then mark("franchise") end
	local lvl = Economy.empireLevel(data.runEarned)
	mark("level" .. lvl)
	if milestones.franchise and milestones["24upgrades"] and milestones.allMax then
		break
	end
end
local keys = { "foodtruck", "bakery", "cafe", "level2", "exp1", "toystore", "level3", "workshop", "warehouse", "level4", "exp2", "factory", "level5", "techlab", "level6", "tower", "12upgrades", "level7", "24upgrades", "allMax", "level8", "franchise" }
for _, k in ipairs(keys) do
	local v = milestones[k]
	print(string.format("%-12s %s", k, v and string.format("%7.1f min", v / 60) or "    ---"))
end
