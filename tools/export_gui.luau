--!nocheck
-- Exporta el arbol de interfaz del cliente (HUD y ventanas) a JSON para
-- revisarlo con tools/render_gui.py.
--   lune run tools/export_gui.luau build/TinyEmpireTycoon.rbxlx build/gui

local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local H = require("../tests/harness")

local placePath = process.args[1] or "build/TinyEmpireTycoon.rbxlx"
local outDir = process.args[2] or "build/gui"
fs.writeDir(outDir)

local game = H.loadPlace(placePath)
H.setup({ studio = true })
local server = H.newRealm("server", game)
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
server.runScript(SSS.TinyEmpireServer.Main)
H.connectRemotes(RS.TinyEmpireRemotes)
local GameService = server.require(SSS.TinyEmpireServer.Services.GameService)

local player = H.addPlayer("Tester", 77)
H.clientPlayer = player
local client = H.newRealm("client", H.clientGame(player))
client.runScript(game:GetService("StarterPlayer").StarterPlayerScripts.TinyEmpireClient.Main)
H.advance(3)
local st = GameService.getState(player)
local function act(...)
	RS.TinyEmpireRemotes.Action.OnServerEvent:Fire(player, ...)
	H.advance(0.2, 0.1)
end
act("buyBusiness", "lemonade")
st.data.cash = 2_500
st.data.runEarned = 2_000
act("buyBusiness", "foodtruck")
act("upgradeBusiness", "lemonade")
H.advance(4, 0.2)

local function color(c)
	return c and { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } or nil
end
local function udim2(u)
	return u and { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } or nil
end
local function get(inst, prop)
	local ok, v = pcall(function()
		return inst[prop]
	end)
	if ok then
		return v
	end
	return nil
end

local function dump(inst)
	local node = { class = inst.ClassName, name = inst.Name, children = {} }
	local c = inst.ClassName
	if inst:IsA("GuiObject") then
		node.pos = udim2(get(inst, "Position"))
		node.size = udim2(get(inst, "Size"))
		local ap = get(inst, "AnchorPoint")
		node.anchor = ap and { ap.X, ap.Y } or { 0, 0 }
		node.visible = get(inst, "Visible") ~= false
		node.bg = color(get(inst, "BackgroundColor3"))
		node.bgT = get(inst, "BackgroundTransparency") or 0
		node.z = get(inst, "ZIndex") or 1
		node.order = get(inst, "LayoutOrder") or 0
		node.rotation = get(inst, "Rotation") or 0
		local auto = get(inst, "AutomaticSize")
		node.autoSize = auto and auto.Name or "None"
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			node.text = get(inst, "Text") or ""
			node.textColor = color(get(inst, "TextColor3"))
			node.textT = get(inst, "TextTransparency") or 0
			local xa = get(inst, "TextXAlignment")
			node.xAlign = xa and xa.Name or "Center"
			local ya = get(inst, "TextYAlignment")
			node.yAlign = ya and ya.Name or "Center"
			node.scaled = get(inst, "TextScaled") == true
			node.wrapped = get(inst, "TextWrapped") == true
			node.textSize = get(inst, "TextSize") or 14
			local font = get(inst, "Font")
			node.font = font and font.Name or "Gotham"
		end
		if inst:IsA("ScrollingFrame") then
			local auto2 = get(inst, "AutomaticCanvasSize")
			node.autoCanvas = auto2 and auto2.Name or "None"
		end
	elseif c == "UIListLayout" then
		node.dir = get(inst, "FillDirection").Name
		local p = get(inst, "Padding")
		node.padding = p and { p.Scale, p.Offset } or { 0, 0 }
		node.hAlign = get(inst, "HorizontalAlignment").Name
		node.vAlign = get(inst, "VerticalAlignment").Name
	elseif c == "UIGridLayout" then
		node.cell = udim2(get(inst, "CellSize"))
		node.cellPad = udim2(get(inst, "CellPadding"))
	elseif c == "UIPadding" then
		local function u(v)
			return v and { v.Scale, v.Offset } or { 0, 0 }
		end
		node.pad = { u(get(inst, "PaddingLeft")), u(get(inst, "PaddingRight")), u(get(inst, "PaddingTop")), u(get(inst, "PaddingBottom")) }
	elseif c == "UICorner" then
		local r = get(inst, "CornerRadius")
		node.radius = r and { r.Scale, r.Offset } or { 0, 8 }
	elseif c == "UIStroke" then
		node.color = color(get(inst, "Color"))
		node.thickness = get(inst, "Thickness") or 1
		node.t = get(inst, "Transparency") or 0
		local mode = get(inst, "ApplyStrokeMode")
		node.mode = mode and mode.Name or "Contextual"
	elseif c == "UIScale" then
		node.scale = get(inst, "Scale") or 1
	elseif c == "UITextSizeConstraint" then
		node.max = get(inst, "MaxTextSize") or 100
	elseif c == "UIGradient" then
		node.gradient = true
	end
	for _, child in ipairs(inst:GetChildren()) do
		table.insert(node.children, dump(child))
	end
	return node
end

local gui = player.PlayerGui.TinyEmpireHUD
local function save(name)
	fs.writeFile(outDir .. "/" .. name .. ".json", serde.encode("json", dump(H.unwrap(gui))))
	print("guardado " .. name)
end
save("hud")
gui.Menu.empire.Activated:Fire()
H.advance(0.5, 0.1)
save("empire")
local win = gui.empireWindow
for _, tab in ipairs({ "Mejoras", "Expansión" }) do
	for _, b in ipairs(win.Frame.Tabs:GetChildren()) do
		if b:IsA("TextButton") and b.Label.Text == tab then
			b.Activated:Fire()
		end
	end
	H.advance(0.3, 0.1)
	save("empire_" .. (tab == "Mejoras" and "upgrades" or "expansion"))
end
gui.Menu.challenges.Activated:Fire()
H.advance(0.5, 0.1)
save("challenges")
for _, b in ipairs(gui.challengesWindow.Frame.Tabs:GetChildren()) do
	if b:IsA("TextButton") and b.Label.Text == "Objetivos" then
		b.Activated:Fire()
	end
end
H.advance(0.3, 0.1)
save("goals")
gui.Menu.shop.Activated:Fire()
H.advance(0.5, 0.1)
save("shop")
print("errores: " .. #H.errors)
