--!nonstrict
-- Estado del jugador recibido del servidor (solo lectura en el cliente).

local Store = {}

Store.state = nil
Store.cash = 0
Store.income = 0

local changed = Instance.new("BindableEvent")
local ticked = Instance.new("BindableEvent")
Store.Changed = changed.Event
Store.Ticked = ticked.Event

function Store.set(state)
	Store.state = state
	Store.cash = state.cash
	Store.income = state.income
	changed:Fire(state)
	ticked:Fire()
end

function Store.tick(cash, income, runEarned)
	Store.cash = cash
	Store.income = income
	if Store.state then
		Store.state.cash = cash
		Store.state.income = income
		Store.state.runEarned = runEarned
	end
	ticked:Fire()
end

return Store
