--!nonstrict
-- Tiny Empire Tycoon :: arranque del cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("TinyEmpireShared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Store = require(script.Parent.Store)
local Theme = require(script.Parent.UI.Theme)
local Hud = require(script.Parent.UI.Hud)
local Panels = require(script.Parent.UI.Panels)
local Effects = require(script.Parent.Effects)
local Animator = require(script.Parent.Animator)
local Physics = require(script.Parent.Physics)
local Tutorial = require(script.Parent.Tutorial)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TinyEmpireRemotes")
local map = workspace:WaitForChild("TinyEmpireMap")

local function fire(action, a, b)
	remotes.Action:FireServer(action, a, b)
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

------------------------------------------------------------------------------
-- Compras
------------------------------------------------------------------------------

local function buyPass(key)
	local p = Config.GamePasses[key]
	if not p then
		return
	end
	if (p.id or 0) > 0 then
		MarketplaceService:PromptGamePassPurchase(player, p.id)
	elseif Store.state and Store.state.simulation then
		fire("simulate", "pass", key)
	else
		Hud.toast("🛒 Este artículo estará disponible pronto.", Theme.C.grey)
	end
end

local function buyProduct(key)
	local p = Config.Products[key]
	if not p then
		return
	end
	if (p.id or 0) > 0 then
		MarketplaceService:PromptProductPurchase(player, p.id)
	elseif Store.state and Store.state.simulation then
		fire("simulate", "product", key)
	else
		Hud.toast("🛒 Este artículo estará disponible pronto.", Theme.C.grey)
	end
end

------------------------------------------------------------------------------
-- Interfaz
------------------------------------------------------------------------------

Hud.init({
	empire = function()
		Panels.open("empire")
	end,
	challenges = function()
		Panels.open("challenges")
	end,
	shop = function()
		Panels.open("shop")
	end,
	plot = function()
		Panels.close()
		fire("teleport", "plot")
	end,
	plaza = function()
		Panels.close()
		fire("teleport", "plaza")
	end,
	claimGoal = function()
		fire("claimGoal")
	end,
	skipTutorial = function()
		Panels.confirm("¿Saltar el tutorial?", "Puedes consultar cómo jugar en el panel de la plaza central.", function()
			fire("tutorial", "skip")
		end)
	end,
})

Panels.init(Hud.gui(), {
	fire = fire,
	buyPass = buyPass,
	buyProduct = buyProduct,
	onOpen = function(key)
		if key == "challenges" then
			fire("tutorial", "openedChallenges")
		end
	end,
})

Effects.init(Hud.gui())
Animator.onBuild = function(position)
	Physics.debrisBurst(position, 12)
end
Animator.start(map)
Physics.start(Hud.gui())
Tutorial.init(map)

------------------------------------------------------------------------------
-- Red
------------------------------------------------------------------------------

remotes.State.OnClientEvent:Connect(function(state)
	Store.set(state)
	Hud.refresh(state)
	Panels.refresh(state)
	Tutorial.update(state)
end)

remotes.Tick.OnClientEvent:Connect(function(cash, income, runEarned)
	Store.tick(cash, income, runEarned)
end)

remotes.Notify.OnClientEvent:Connect(function(payload)
	Hud.toast(payload.text, payload.color)
	if payload.sound then
		Theme.play(payload.sound)
	end
end)

remotes.Effect.OnClientEvent:Connect(function(payload)
	local kind = payload.kind
	if kind == "confetti" then
		Effects.confetti(70)
	elseif kind == "cash" then
		Effects.cashBurst(payload.amount, Hud.cashPanel())
		if payload.position then
			Physics.coinBurst(payload.position, 14)
		end
	elseif kind == "build" then
		Effects.flash(Theme.C.green)
		if payload.position then
			Physics.coinBurst(payload.position, 10)
		end
	elseif kind == "rain" then
		Effects.flash(Theme.C.gold)
	elseif kind == "levelup" then
		Effects.flash(Theme.C.blue)
		if payload.position then
			Physics.coinBurst(payload.position, 8)
		end
		if payload.level == Config.MaxBusinessLevel then
			Effects.confetti(40)
		end
	elseif kind == "upgrade" then
		Effects.flash(Theme.C.purple)
	elseif kind == "expansion" then
		Effects.flash(Theme.C.gold)
	elseif kind == "offline" then
		Hud.modal("🌙 ¡Bienvenido de vuelta!", string.format("Mientras no estabas (%s), tu imperio ganó:\n%s", Format.time(payload.seconds), Format.cash(payload.amount)), "¡Genial!", Theme.C.gold)
		Effects.confetti(50)
		Theme.play("success")
	end
end)

fire("requestState")
