--!nonstrict
-- Retos diarios: 3 retos por jugador y dia (reinicio a las 00:00 UTC).
-- La seleccion es determinista por jugador y dia para que no se puedan "rerollear".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.TinyEmpireShared.Config)
local Economy = require(ReplicatedStorage.TinyEmpireShared.Economy)
local Format = require(ReplicatedStorage.TinyEmpireShared.Format)

local ChallengeService = {}

function ChallengeService.today()
	return os.time() // 86400
end

function ChallengeService.secondsUntilReset()
	return 86400 - (os.time() % 86400)
end

local function describe(def, target)
	if def.kind == "earn" then
		return string.format(def.text, Format.cash(target))
	elseif def.text:find("%%d") then
		return string.format(def.text, target)
	end
	return def.text
end

-- Garantiza que el jugador tenga los retos del dia. Devuelve true si se generaron.
function ChallengeService.ensure(state)
	local data = state.data
	local day = ChallengeService.today()
	if data.daily and data.daily.day == day then
		return false
	end
	local income = Economy.totalIncome(data, state.passes.x2)
	local rng = Random.new(day * 7919 + (state.player.UserId % 100000))
	local pool = table.clone(Config.DailyPool)
	local list = {}
	for _ = 1, math.min(Config.DailyCount, #pool) do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		local target = def.target or 1
		if def.kind == "earn" then
			target = math.floor(math.max(def.min, income * def.incomeSeconds))
		end
		local reward = math.floor(math.max(Config.DailyMinReward, income * Config.DailyRewardIncomeSeconds))
		table.insert(list, {
			id = def.id,
			kind = def.kind,
			text = describe(def, target),
			target = target,
			progress = 0,
			reward = reward,
			claimed = false,
		})
	end
	data.daily = { day = day, list = list, bonusClaimed = false }
	return true
end

-- Suma progreso a los retos de un tipo. Devuelve true si alguno se completo.
function ChallengeService.progress(state, kind, amount)
	local daily = state.data.daily
	if not daily then
		return false
	end
	local completed = false
	for _, c in ipairs(daily.list) do
		if c.kind == kind and not c.claimed and c.progress < c.target then
			c.progress = math.min(c.target, c.progress + amount)
			if c.progress >= c.target then
				completed = true
			end
		end
	end
	return completed
end

-- Reclama un reto. Devuelve recompensa (0 si no se puede) y bonus extra.
function ChallengeService.claim(state, index)
	local daily = state.data.daily
	if not daily then
		return 0, 0
	end
	local c = daily.list[index]
	if not c or c.claimed or c.progress < c.target then
		return 0, 0
	end
	c.claimed = true
	local bonus = 0
	local all = true
	for _, other in ipairs(daily.list) do
		if not other.claimed then
			all = false
		end
	end
	if all and not daily.bonusClaimed then
		daily.bonusClaimed = true
		for _, other in ipairs(daily.list) do
			bonus += other.reward
		end
		bonus = math.floor(bonus * (Config.DailyAllBonusMult - 1))
	end
	return c.reward, bonus
end

return ChallengeService
