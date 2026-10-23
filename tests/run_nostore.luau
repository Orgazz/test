--!nocheck
-- Prueba: Studio sin "Enable Studio Access to API Services".
-- El juego debe funcionar en memoria y avisar al jugador.
--   lune run tests/run_nostore.luau build/TinyEmpireTycoon.rbxlx

local process = require("@lune/process")
local H = require("./harness")

local game = H.loadPlace(process.args[1] or "build/TinyEmpireTycoon.rbxlx")
H.setup({ studio = true, dataStoreDisabled = true })
local server = H.newRealm("server", game)
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local notices = {}
H.onFireClient = function(name, player, payload)
	if name == "Notify" then
		table.insert(notices, payload.text)
	end
end
server.runScript(SSS.TinyEmpireServer.Main)
H.connectRemotes(RS.TinyEmpireRemotes)
local GameService = server.require(SSS.TinyEmpireServer.Services.GameService)

local p = H.addPlayer("SinGuardado", 7)
H.advance(8)
local st = GameService.getState(p)
local ok = true
local function check(c, msg)
	print((c and "  ✓ " or "  ✗ ") .. msg)
	ok = ok and c
end
check(st ~= nil and st.ready, "el jugador juega aunque no haya DataStore")
local warned = false
for _, n in ipairs(notices) do
	if n:find("Guardado desactivado") then
		warned = true
	end
end
check(warned, "se avisa de que el guardado esta desactivado")
RS.TinyEmpireRemotes.Action.OnServerEvent:Fire(p, "buyBusiness", "lemonade")
H.advance(5)
check(st.data.businesses.lemonade == 1 and st.data.cash > 0, "la economia funciona en memoria")
H.removePlayer(p)
H.advance(2)
check(#H.errors == 0, "sin errores de ejecucion")
if not ok then
	process.exit(1)
end
print("OK: modo sin DataStore")
