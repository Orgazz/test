--!nonstrict
-- Constructores procedurales de los 10 negocios. Cada negocio crece de forma
-- visible en sus 5 niveles. El frente del edificio mira hacia -Z local.
--
-- Etiquetas de animacion (las anima el cliente, ver Client/Animator):
--   TE_Spin  (SpinSpeed grados/s, SpinAxis "X"|"Y"|"Z")
--   TE_Bob   (BobHeight, BobSpeed)
--   TE_Slide (SlideOffset Vector3 local, SlideSpeed, SlideMode "pingpong"|"loop")
--   TE_Pulse (PulseSpeed) neon que parpadea suavemente

local Kit = require(script.Parent.Kit)
local Details = require(script.Parent.Details)

local Buildings = {}

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(45, 45, 55)
local METAL = Color3.fromRGB(150, 155, 165)
local GLASS = Color3.fromRGB(160, 215, 245)
local CONCRETE = Color3.fromRGB(200, 200, 205)

local function spin(inst, speed, axis)
	inst:AddTag("TE_Spin")
	inst:SetAttribute("SpinSpeed", speed)
	inst:SetAttribute("SpinAxis", axis or "Y")
	return inst
end

local function bob(inst, height, speed)
	inst:AddTag("TE_Bob")
	inst:SetAttribute("BobHeight", height or 1)
	inst:SetAttribute("BobSpeed", speed or 1)
	return inst
end

local function slide(inst, offset, speed, mode)
	inst:AddTag("TE_Slide")
	inst:SetAttribute("SlideOffset", offset)
	inst:SetAttribute("SlideSpeed", speed or 0.3)
	inst:SetAttribute("SlideMode", mode or "pingpong")
	return inst
end

local function pulse(inst, speed)
	inst:AddTag("TE_Pulse")
	inst:SetAttribute("PulseSpeed", speed or 1)
	return inst
end

-- Losa de cimentacion
local function foundation(m, cf, w, d, color)
	Kit.box(m, "Foundation", Vector3.new(w, 0.6, d), cf * CFrame.new(0, 0.3, 0), color or CONCRETE, Enum.Material.Concrete)
end

-- Bloque con ventanas. Devuelve la altura del techo.
local function block(m, cf, w, d, h, y0, wall, opts)
	opts = opts or {}
	local center = cf * CFrame.new(opts.x or 0, y0 + h / 2, opts.z or 0)
	Kit.box(m, opts.name or "Wall", Vector3.new(w, h, d), center, wall, opts.material or Enum.Material.SmoothPlastic)
	if opts.windows ~= false then
		local rows = opts.rows or math.max(1, math.floor(h / 4.5))
		local cols = opts.cols or math.max(1, math.floor(w / 4))
		local winColor = opts.windowColor or GLASS
		Kit.windows(m, center * CFrame.new(0, 0, -d / 2 - 0.1), w - 1.5, h - 1.2, rows, cols, winColor, opts.sill)
		if opts.sideWindows ~= false then
			local sideCols = math.max(1, math.floor(d / 4))
			Kit.windows(m, center * CFrame.new(w / 2 + 0.1, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), d - 1.5, h - 1.2, rows, sideCols, winColor)
			Kit.windows(m, center * CFrame.new(-w / 2 - 0.1, 0, 0) * CFrame.Angles(0, math.rad(90), 0), d - 1.5, h - 1.2, rows, sideCols, winColor)
		end
	end
	if opts.trim then
		Kit.box(m, "Trim", Vector3.new(w + 0.6, 0.6, d + 0.6), cf * CFrame.new(opts.x or 0, y0 + h + 0.3, opts.z or 0), opts.trim)
	end
	return y0 + h + (opts.trim and 0.6 or 0)
end

-- Tejado a dos aguas (cumbrera a lo largo de X)
local function gable(m, cf, w, d, rh, y, color, x, z)
	x = x or 0
	z = z or 0
	Kit.wedge(m, "Roof", Vector3.new(w + 1, rh, d / 2 + 0.5), cf * CFrame.new(x, y + rh / 2, z - d / 4 - 0.25), color, Enum.Material.SmoothPlastic)
	Kit.wedge(m, "Roof", Vector3.new(w + 1, rh, d / 2 + 0.5), cf * CFrame.new(x, y + rh / 2, z + d / 4 + 0.25) * CFrame.Angles(0, math.rad(180), 0), color, Enum.Material.SmoothPlastic)
end

local function door(m, cf, x, z, color, w, h)
	w = w or 3
	h = h or 5
	Kit.box(m, "Door", Vector3.new(w, h, 0.4), cf * CFrame.new(x, 0.6 + h / 2, z - 0.2), color or Color3.fromRGB(120, 80, 55), Enum.Material.Wood)
	Kit.box(m, "DoorFrame", Vector3.new(w + 0.8, 0.5, 0.6), cf * CFrame.new(x, 0.6 + h + 0.25, z - 0.25), WHITE)
end

-- Letrero de fachada con el nombre del negocio
local function frontSign(m, cf, text, y, z, w, bg, fg)
	local s = Kit.box(m, "Sign", Vector3.new(w, 2.4, 0.4), cf * CFrame.new(0, y, z - 0.3), bg or WHITE)
	Kit.surfaceText(s, text, Enum.NormalId.Front, bg or WHITE, fg or DARK)
	return s
end

local function table_(m, cf, umbrella)
	Kit.cylinder(m, "Table", 0.3, 3.2, cf * CFrame.new(0, 2.6, 0), WHITE)
	Kit.cylinder(m, "TableLeg", 2.5, 0.4, cf * CFrame.new(0, 1.3, 0), DARK, Enum.Material.Metal)
	for i = 0, 1 do
		local a = math.rad(90 + i * 180)
		Kit.box(m, "Stool", Vector3.new(1.4, 1.6, 1.4), cf * CFrame.new(math.cos(a) * 2.6, 0.8, math.sin(a) * 2.6), Color3.fromRGB(230, 90, 80))
	end
	if umbrella then
		Kit.cylinder(m, "UmbrellaPole", 5, 0.3, cf * CFrame.new(0, 5, 0), WHITE)
		Kit.cylinder(m, "Umbrella", 0.6, 7, cf * CFrame.new(0, 7.4, 0), umbrella, Enum.Material.Fabric)
		Kit.cylinder(m, "UmbrellaTop", 0.6, 4, cf * CFrame.new(0, 7.9, 0), umbrella:Lerp(WHITE, 0.4), Enum.Material.Fabric)
	end
end

local function crates(m, cf, nx, ny, color)
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			Kit.box(m, "Crate", Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(i * 2.6, 1.2 + j * 2.45, 0) * CFrame.Angles(0, math.rad((i * 13 + j * 7) % 15), 0), color or Color3.fromRGB(190, 140, 80), Enum.Material.Wood)
		end
	end
end

local function chimney(m, cf, x, z, h, y, color)
	local c = Kit.box(m, "Chimney", Vector3.new(2, h, 2), cf * CFrame.new(x, y + h / 2, z), color or Color3.fromRGB(150, 80, 70), Enum.Material.Brick)
	local top = Kit.box(m, "ChimneyTop", Vector3.new(2.4, 0.5, 2.4), cf * CFrame.new(x, y + h + 0.25, z), DARK)
	Kit.smoke(top, Color3.fromRGB(235, 235, 240), 3)
	return c
end

local function stringLights(m, a, b, n, color)
	for i = 0, n do
		local p = a:Lerp(b, i / n) - Vector3.new(0, math.sin(math.pi * i / n) * 1.2, 0)
		local bulb = Kit.ball(m, "Bulb", 0.6, CFrame.new(p), color or Color3.fromRGB(255, 230, 150), Enum.Material.Neon, { CanCollide = false, CastShadow = false })
		if i % 3 == 0 then
			Kit.light(bulb, color or Color3.fromRGB(255, 220, 150), 10, 1)
		end
	end
	local mid = (a + b) / 2
	Kit.box(m, "Wire", Vector3.new(0.1, 0.1, (b - a).Magnitude), CFrame.lookAt(mid, b), DARK, Enum.Material.SmoothPlastic, { CanCollide = false })
end

-- Engranaje (modelo que gira)
local function gear(m, cf, diameter, color, speed)
	local g = Kit.model(m, "Gear")
	Kit.cylinderX(g, "Disc", 0.6, diameter, cf * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Metal)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Kit.box(g, "Tooth", Vector3.new(diameter * 0.18, diameter * 0.18, 0.6), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, diameter / 2, 0), color, Enum.Material.Metal)
	end
	Kit.cylinderX(g, "Hub", 0.8, diameter * 0.3, cf * CFrame.Angles(0, math.rad(90), 0), DARK, Enum.Material.Metal)
	g.WorldPivot = cf
	spin(g, speed or 60, "Z")
	return g
end

-- Cinta transportadora con cajas que avanzan en bucle
local function conveyor(m, cf, length, itemColor, items)
	Kit.box(m, "Belt", Vector3.new(length, 0.4, 3), cf * CFrame.new(0, 2.2, 0), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	Kit.box(m, "BeltFrame", Vector3.new(length, 2, 0.4), cf * CFrame.new(0, 1, 1.5), METAL, Enum.Material.Metal)
	Kit.box(m, "BeltFrame", Vector3.new(length, 2, 0.4), cf * CFrame.new(0, 1, -1.5), METAL, Enum.Material.Metal)
	items = items or 4
	for i = 1, items do
		local start = -length / 2 + 1
		local item = Kit.box(m, "Product", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(start, 3.2, 0), itemColor or Color3.fromRGB(240, 180, 90), Enum.Material.SmoothPlastic, { CanCollide = false })
		slide(item, Vector3.new(length - 2, 0, 0), 0.15, "loop")
		item:SetAttribute("SlidePhase", (i - 1) / items)
	end
end

------------------------------------------------------------------------------
-- NEGOCIOS
------------------------------------------------------------------------------

local builders = {}

builders.lemonade = function(m, cf, L, pal, S)
	local yellow = Color3.fromRGB(255, 225, 70)
	foundation(m, cf, S - 2, S - 2, pal.path)
	-- Puesto
	local stand = cf * CFrame.new(0, 0, -3)
	Kit.box(m, "Counter", Vector3.new(8, 3.4, 3.4), stand * CFrame.new(0, 2.3, 0), Color3.fromRGB(255, 250, 235), Enum.Material.Wood)
	Kit.box(m, "CounterTop", Vector3.new(8.6, 0.4, 3.8), stand * CFrame.new(0, 4.2, 0), yellow)
	for _, x in ipairs({ -3.8, 3.8 }) do
		Kit.box(m, "Post", Vector3.new(0.5, 4.5, 0.5), stand * CFrame.new(x, 6.5, 1.4), Color3.fromRGB(170, 120, 80), Enum.Material.Wood)
	end
	Kit.awning(m, stand * CFrame.new(0, 9.2, -0.6), 9, 4.4, yellow, WHITE)
	local sign = Kit.box(m, "Sign", Vector3.new(7, 1.8, 0.4), stand * CFrame.new(0, 10.8, 1.4), WHITE)
	Kit.surfaceText(sign, "🍋 LIMONADA", Enum.NormalId.Front, WHITE, Color3.fromRGB(230, 160, 0))
	Kit.cylinder(m, "Jug", 1.6, 1.4, stand * CFrame.new(-2, 5.2, 0), Color3.fromRGB(255, 240, 120), Enum.Material.Glass, { Transparency = 0.2 })
	Kit.cylinder(m, "Cup", 0.8, 0.7, stand * CFrame.new(1, 4.8, -0.5), WHITE)
	Kit.cylinder(m, "Cup", 0.8, 0.7, stand * CFrame.new(2, 4.8, -0.5), WHITE)
	local lemon = Kit.ball(m, "BigLemon", 2.4, stand * CFrame.new(0, 13, 1.4), yellow, Enum.Material.SmoothPlastic, { CanCollide = false })
	bob(lemon, 0.8, 1.2)
	if L >= 2 then
		table_(m, cf * CFrame.new(-6, 0, -6.5), Color3.fromRGB(255, 220, 60))
		table_(m, cf * CFrame.new(6, 0, -6.5), Color3.fromRGB(120, 210, 90))
	end
	if L >= 3 then
		local back = cf * CFrame.new(0, 0, 5)
		local top = block(m, back, 12, 6, 7, 0.6, pal.wall, { windows = true, rows = 1, cols = 2, trim = yellow, sideWindows = false })
		gable(m, back, 12, 6, 2.5, top, yellow)
		Kit.bush(m, cf * CFrame.new(-8, 0.6, 2))
		Kit.bush(m, cf * CFrame.new(8, 0.6, 2))
	end
	if L >= 4 then
		stringLights(m, (cf * CFrame.new(-8.5, 8, -8.5)).Position, (cf * CFrame.new(8.5, 8, -8.5)).Position, 9)
		for _, x in ipairs({ -8.5, 8.5 }) do
			Kit.cylinder(m, "LightPole", 8, 0.4, cf * CFrame.new(x, 4, -8.5), DARK, Enum.Material.Metal)
		end
	end
	if L >= 5 then
		local big = Kit.model(m, "SpinningLemon")
		local c = cf * CFrame.new(0, 18, 5)
		Kit.ball(big, "Lemon", 5, c, yellow, Enum.Material.SmoothPlastic, { CanCollide = false })
		Kit.ball(big, "LemonTip", 1.6, c * CFrame.new(2.6, 0, 0), yellow, Enum.Material.SmoothPlastic, { CanCollide = false })
		Kit.box(big, "Leaf", Vector3.new(0.3, 1.2, 2.2), c * CFrame.new(-1, 2.6, 0), Color3.fromRGB(80, 180, 70), Enum.Material.SmoothPlastic, { CanCollide = false })
		big.WorldPivot = c
		spin(big, 45, "Y")
		Kit.cylinder(m, "Pole", 4, 0.6, cf * CFrame.new(0, 15, 5), WHITE)
		Kit.sparkles(Kit.box(m, "SparkleSrc", Vector3.new(1, 1, 1), c, WHITE, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false }), yellow, 5)
	end
end

local function truck(m, cf, color, label)
	local t = Kit.model(m, "FoodTruck")
	Kit.box(t, "Body", Vector3.new(12, 6, 5.5), cf * CFrame.new(0, 4.2, 0), color)
	Kit.box(t, "Cab", Vector3.new(3.6, 4.2, 5.5), cf * CFrame.new(-7.6, 3.3, 0), color:Lerp(WHITE, 0.2))
	Kit.box(t, "Windshield", Vector3.new(0.3, 2, 4.8), cf * CFrame.new(-9.45, 4, 0), GLASS, Enum.Material.Glass, { Transparency = 0.2 })
	Kit.box(t, "Hatch", Vector3.new(7, 2.6, 0.3), cf * CFrame.new(0.5, 5, -2.8), Color3.fromRGB(40, 30, 30))
	Kit.box(t, "Shelf", Vector3.new(7.4, 0.3, 1.4), cf * CFrame.new(0.5, 3.6, -3.4), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	Kit.awning(t, cf * CFrame.new(0.5, 7.2, -4), 8, 2.8, WHITE, color:Lerp(Color3.new(1, 0.2, 0.2), 0.4))
	for _, x in ipairs({ -7.5, 3.5 }) do
		for _, z in ipairs({ -2.6, 2.6 }) do
			Kit.cylinderX(t, "Wheel", 1, 2.4, cf * CFrame.new(x, 1.2, z) * CFrame.Angles(0, math.rad(90), 0), DARK)
		end
	end
	local sign = Kit.box(t, "RoofSign", Vector3.new(8, 2, 0.4), cf * CFrame.new(0, 8.3, 0), WHITE)
	Kit.surfaceText(sign, label, Enum.NormalId.Front, WHITE, color)
	return t
end

builders.foodtruck = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(80, 80, 90))
	-- Lineas de aparcamiento
	for _, x in ipairs({ -7, 7 }) do
		Kit.box(m, "Line", Vector3.new(0.4, 0.05, 8), cf * CFrame.new(x, 0.62, 3), WHITE, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	truck(m, cf * CFrame.new(0.5, 0.6, 1.5), Color3.fromRGB(255, 120, 80), "🌮 TACOS")
	local menu = Kit.box(m, "Menu", Vector3.new(3, 4, 0.3), cf * CFrame.new(-6.5, 2.6, -5), DARK)
	Kit.surfaceText(menu, "MENÚ\nTacos $2\nNachos $3", Enum.NormalId.Front, DARK, Color3.fromRGB(255, 230, 120))
	local taco = Kit.model(m, "Taco")
	local tc = cf * CFrame.new(0.5, 12, 1.5)
	Kit.cylinderX(taco, "Shell", 0.8, 3.2, tc, Color3.fromRGB(245, 200, 90))
	Kit.ball(taco, "Filling", 1.2, tc * CFrame.new(0, 0.8, 0), Color3.fromRGB(110, 200, 80))
	taco.WorldPivot = tc
	bob(taco, 0.7, 1.4)
	if L >= 2 then
		table_(m, cf * CFrame.new(6, 0, -6), Color3.fromRGB(255, 90, 90))
		Kit.cylinder(m, "Bin", 2.4, 1.6, cf * CFrame.new(-8.5, 1.8, -7), Color3.fromRGB(70, 150, 90))
	end
	if L >= 3 then
		local pav = cf * CFrame.new(0, 0, -6.5)
		for _, x in ipairs({ -9, 9 }) do
			Kit.box(m, "PavPost", Vector3.new(0.6, 7, 0.6), pav * CFrame.new(x, 4, -2), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		end
		Kit.box(m, "PavRoof", Vector3.new(19, 0.5, 4), pav * CFrame.new(0, 7.6, -1.5), Color3.fromRGB(255, 140, 90), Enum.Material.Fabric)
	end
	if L >= 4 then
		truck(m, cf * CFrame.new(0.5, 0.6, 8.5) * CFrame.Angles(0, math.rad(180), 0), pal.accent2, "🍔 BURGERS")
	end
	if L >= 5 then
		stringLights(m, (cf * CFrame.new(-9, 7.5, -8.5)).Position, (cf * CFrame.new(9, 7.5, -8.5)).Position, 10, Color3.fromRGB(255, 120, 200))
		local arch = Kit.box(m, "Arch", Vector3.new(14, 2.6, 0.6), cf * CFrame.new(0, 15.5, 1.5), Color3.fromRGB(255, 80, 120), Enum.Material.Neon)
		Kit.surfaceText(arch, "FOOD COURT", Enum.NormalId.Front, nil, WHITE)
		pulse(arch, 1.5)
		Kit.cylinder(m, "ArchPole", 7, 0.5, cf * CFrame.new(-6, 11, 1.5), DARK, Enum.Material.Metal)
		Kit.cylinder(m, "ArchPole", 7, 0.5, cf * CFrame.new(6, 11, 1.5), DARK, Enum.Material.Metal)
	end
end

builders.bakery = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, pal.path)
	local wall = Color3.fromRGB(245, 225, 190)
	local floors = L >= 3 and 2 or 1
	local body = cf * CFrame.new(0, 0, 2)
	local top = block(m, body, 13, 9, 7 * floors, 0.6, wall, { rows = floors, cols = 3, trim = Color3.fromRGB(140, 90, 60), sill = Color3.fromRGB(140, 90, 60), material = Enum.Material.Brick })
	gable(m, body, 13, 9, 4, top, Color3.fromRGB(170, 70, 50))
	door(m, body, 0, -4.5, Color3.fromRGB(150, 90, 50))
	frontSign(m, body, "🥐 PANADERÍA", 7.6 * floors - 0.5, -4.5, 9, Color3.fromRGB(140, 90, 60), Color3.fromRGB(255, 235, 200))
	chimney(m, body, 4, 2, 4, top, Color3.fromRGB(170, 90, 70))
	local bread = Kit.model(m, "Croissant")
	local bc = cf * CFrame.new(-7, 4, -7)
	Kit.ball(bread, "Bun", 2, bc, Color3.fromRGB(225, 160, 80))
	Kit.ball(bread, "BunL", 1.4, bc * CFrame.new(-1.1, -0.2, 0), Color3.fromRGB(215, 145, 70))
	Kit.ball(bread, "BunR", 1.4, bc * CFrame.new(1.1, -0.2, 0), Color3.fromRGB(215, 145, 70))
	bread.WorldPivot = bc
	bob(bread, 0.6, 1)
	Kit.cylinder(m, "Stand", 2.6, 1.2, cf * CFrame.new(-7, 1.9, -7), WHITE)
	if L >= 2 then
		Kit.awning(m, body * CFrame.new(0, 6.2, -5.8), 12, 2.6, Color3.fromRGB(200, 80, 60), WHITE)
		crates(m, cf * CFrame.new(4, 0.6, -6.5), 2, 1, Color3.fromRGB(200, 150, 90))
	end
	if L >= 4 then
		local side = cf * CFrame.new(0, 0, 8)
		local ovenTop = block(m, side, 10, 4, 5, 0.6, Color3.fromRGB(180, 110, 80), { windows = false, material = Enum.Material.Brick })
		local glow = Kit.box(m, "OvenGlow", Vector3.new(4, 2, 0.3), side * CFrame.new(5.1, 3, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		pulse(glow, 0.8)
		chimney(m, side, -3, 0, 3, ovenTop, Color3.fromRGB(150, 80, 70))
	end
	if L >= 5 then
		local mill = Kit.model(m, "Windmill")
		local hub = body * CFrame.new(0, top + 3, -5)
		Kit.cylinderX(mill, "Hub", 1, 1.4, hub * CFrame.Angles(0, math.rad(90), 0), DARK)
		for i = 0, 3 do
			Kit.box(mill, "Blade", Vector3.new(1.4, 7, 0.2), hub * CFrame.Angles(0, 0, math.rad(i * 90)) * CFrame.new(0, 3.8, -0.3), Color3.fromRGB(255, 250, 240), Enum.Material.Fabric)
		end
		mill.WorldPivot = hub
		spin(mill, 50, "Z")
	end
end

builders.cafe = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(215, 205, 190))
	local brown = Color3.fromRGB(120, 80, 60)
	local floors = (L >= 5 and 3) or (L >= 3 and 2) or 1
	local body = cf * CFrame.new(0, 0, 3)
	local top = block(m, body, 14, 10, 6.5 * floors, 0.6, Color3.fromRGB(235, 220, 200), { rows = floors, cols = 3, trim = brown, material = Enum.Material.Concrete })
	-- Escaparate grande
	Kit.box(m, "Storefront", Vector3.new(10, 4.5, 0.3), body * CFrame.new(0, 3, -5.15), GLASS, Enum.Material.Glass, { Transparency = 0.25 })
	door(m, body, 5.5, -5, brown, 2.2, 4.5)
	frontSign(m, body, "☕ CAFETERÍA", top - 1.5, -5, 10, brown, Color3.fromRGB(255, 230, 190))
	Kit.awning(m, body * CFrame.new(0, 6.3, -6.4), 13, 2.6, Color3.fromRGB(80, 140, 90), WHITE)
	-- Taza gigante
	local cup = Kit.model(m, "BigCup")
	local cc = body * CFrame.new(0, top + 2.4, 0)
	Kit.cylinder(cup, "Cup", 3.6, 4, cc, WHITE)
	Kit.cylinder(cup, "Coffee", 0.2, 3.5, cc * CFrame.new(0, 1.75, 0), Color3.fromRGB(90, 55, 35))
	local handle = Kit.box(cup, "Handle", Vector3.new(1.2, 2, 0.6), cc * CFrame.new(2.3, 0, 0), WHITE)
	Kit.smoke(handle, Color3.fromRGB(255, 255, 255), 2)
	cup.WorldPivot = cc
	bob(cup, 0.5, 0.8)
	if L >= 2 then
		table_(m, cf * CFrame.new(-5, 0, -6), Color3.fromRGB(80, 140, 90))
		table_(m, cf * CFrame.new(5, 0, -6), Color3.fromRGB(80, 140, 90))
	end
	if L >= 4 then
		for i = -1, 1 do
			Kit.flowerBed(m, body * CFrame.new(i * 4.2, top, 3.5), 3.6, 2.2)
		end
		Kit.tree(m, body * CFrame.new(-5.5, top, 3), "round")
	end
	if L >= 5 then
		local neon = Kit.box(m, "NeonBean", Vector3.new(3, 4, 0.4), body * CFrame.new(-7.3, top - 3, -3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
		pulse(neon, 1.2)
	end
end

builders.toystore = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(255, 240, 250))
	local rainbow = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(255, 230, 80),
		Color3.fromRGB(110, 210, 110),
		Color3.fromRGB(90, 170, 255),
		Color3.fromRGB(180, 110, 255),
	}
	local floors = L >= 3 and 2 or 1
	local body = cf * CFrame.new(0, 0, 3)
	local h = 7.5 * floors
	local top = block(m, body, 16, 12, h, 0.6, Color3.fromRGB(255, 200, 230), { rows = floors, cols = 4, trim = WHITE })
	for i, c in ipairs(rainbow) do
		Kit.box(m, "Stripe", Vector3.new(16.4, 0.5, 0.2), body * CFrame.new(0, 0.6 + h - i * 0.5 + 0.25, -6.15), c, Enum.Material.SmoothPlastic)
	end
	door(m, body, 0, -6, Color3.fromRGB(255, 90, 140), 3.4, 5)
	frontSign(m, body, "🧸 JUGUETERÍA", top + 1.6, -5.4, 12, Color3.fromRGB(255, 90, 160), WHITE)
	-- Osito gigante
	local bear = Kit.model(m, "Teddy")
	local tc = body * CFrame.new(4, top + 3, 1)
	local fur = Color3.fromRGB(190, 130, 80)
	Kit.ball(bear, "Body", 4.2, tc, fur)
	Kit.ball(bear, "Head", 3.2, tc * CFrame.new(0, 3.2, 0), fur)
	Kit.ball(bear, "EarL", 1.3, tc * CFrame.new(-1.3, 4.6, 0), fur)
	Kit.ball(bear, "EarR", 1.3, tc * CFrame.new(1.3, 4.6, 0), fur)
	Kit.ball(bear, "Snout", 1.3, tc * CFrame.new(0, 2.9, -1.4), Color3.fromRGB(240, 210, 170))
	Kit.ball(bear, "Bow", 1, tc * CFrame.new(0, 1.8, -1.6), Color3.fromRGB(255, 70, 120))
	bear.WorldPivot = tc
	bob(bear, 0.6, 0.9)
	-- Molinillo
	local pin = Kit.model(m, "Pinwheel")
	local pc = body * CFrame.new(-5, top + 4, -2)
	for i = 0, 3 do
		Kit.wedge(pin, "Vane", Vector3.new(0.2, 2.6, 2.6), pc * CFrame.Angles(0, 0, math.rad(i * 90)) * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(90), 0), rainbow[i + 1])
	end
	pin.WorldPivot = pc
	spin(pin, 120, "Z")
	Kit.cylinder(m, "PinStick", 4, 0.3, body * CFrame.new(-5, top + 2, -1.8), WHITE)
	if L >= 2 then
		for i = 1, 5 do
			local b = Kit.ball(m, "Balloon", 1.8, cf * CFrame.new(-9 + i * 3, 9 + (i % 2), -9), rainbow[i], Enum.Material.SmoothPlastic, { CanCollide = false })
			bob(b, 0.6, 0.7 + i * 0.1)
		end
	end
	if L >= 4 then
		local car = Kit.model(m, "Carousel")
		local cc = cf * CFrame.new(-8.5, 0.6, -6)
		Kit.cylinder(car, "Base", 0.8, 6, cc * CFrame.new(0, 0.4, 0), Color3.fromRGB(255, 220, 240))
		Kit.cylinder(car, "Pole", 5, 0.5, cc * CFrame.new(0, 3, 0), Color3.fromRGB(255, 215, 0), Enum.Material.Metal)
		Kit.cylinder(car, "Top", 0.8, 6.4, cc * CFrame.new(0, 5.6, 0), Color3.fromRGB(255, 120, 170))
		for i = 0, 3 do
			local a = math.rad(i * 90)
			Kit.ball(car, "Horse", 1.4, cc * CFrame.new(math.cos(a) * 2.2, 2.4, math.sin(a) * 2.2), rainbow[i + 2])
		end
		car.WorldPivot = cc
		spin(car, 40, "Y")
	end
	if L >= 5 then
		local neon = Kit.box(m, "NeonStar", Vector3.new(3, 3, 0.5), body * CFrame.new(-4, top + 3, -3), Color3.fromRGB(255, 240, 80), Enum.Material.Neon)
		spin(neon, 90, "Z")
		Kit.sparkles(neon, Color3.fromRGB(255, 240, 120), 8)
	end
end

builders.workshop = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(150, 150, 155))
	local body = cf * CFrame.new(0, 0, 3)
	local wall = pal.wall2
	local top = block(m, body, 18, 13, 9, 0.6, wall, { rows = 1, cols = 4, material = Enum.Material.Metal, sideWindows = false })
	-- Tejado en dientes de sierra
	for i = 0, 2 do
		Kit.wedge(m, "SawRoof", Vector3.new(18, 3, 13 / 3), body * CFrame.new(0, top + 1.5, -13 / 2 + 13 / 6 + i * 13 / 3), Color3.fromRGB(90, 95, 105), Enum.Material.Metal)
	end
	Kit.box(m, "RollDoor", Vector3.new(8, 6.5, 0.3), body * CFrame.new(-3, 3.85, -6.65), Color3.fromRGB(200, 205, 210), Enum.Material.DiamondPlate)
	frontSign(m, body, "🔧 TALLER", 8.4, -6.5, 7, pal.accent, WHITE)
	gear(m, body * CFrame.new(5.5, 5.5, -6.9), 4, Color3.fromRGB(255, 190, 40), 70)
	chimney(m, body, 6, 4, 6, top, Color3.fromRGB(100, 100, 110))
	if L >= 2 then
		for _, x in ipairs({ -7, -2 }) do
			Kit.box(m, "Bench", Vector3.new(4, 0.4, 2), cf * CFrame.new(x, 3, -7), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
			Kit.box(m, "BenchLeg", Vector3.new(3.6, 2.4, 1.6), cf * CFrame.new(x, 1.8, -7), DARK, Enum.Material.Metal)
		end
	end
	if L >= 3 then
		conveyor(m, cf * CFrame.new(5.5, 0.6, -8), 9, Color3.fromRGB(240, 170, 70), 3)
	end
	if L >= 4 then
		chimney(m, body, -6, 4, 7, top, Color3.fromRGB(100, 100, 110))
		gear(m, body * CFrame.new(8, 7, -6.9), 2.6, Color3.fromRGB(200, 200, 210), -110)
	end
	if L >= 5 then
		local crane = Kit.model(m, "Crane")
		local base = body * CFrame.new(-7, top, 2)
		Kit.box(m, "CraneMast", Vector3.new(1.2, 8, 1.2), base * CFrame.new(0, 4, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		local pivot = base * CFrame.new(0, 8.4, 0)
		Kit.box(crane, "Jib", Vector3.new(12, 0.8, 0.8), pivot * CFrame.new(4, 0, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		Kit.box(crane, "Hook", Vector3.new(0.6, 3, 0.6), pivot * CFrame.new(9, -1.8, 0), DARK, Enum.Material.Metal)
		crane.WorldPivot = pivot
		spin(crane, 15, "Y")
	end
end

local function forklift(m, cf, color)
	local f = Kit.model(m, "Forklift")
	Kit.box(f, "Body", Vector3.new(3, 2, 4), cf * CFrame.new(0, 1.6, 0), color or Color3.fromRGB(255, 190, 40))
	Kit.box(f, "Cage", Vector3.new(3, 2.4, 0.3), cf * CFrame.new(0, 3.8, 1.2), DARK, Enum.Material.Metal)
	Kit.box(f, "Mast", Vector3.new(2.4, 4.5, 0.3), cf * CFrame.new(0, 2.6, -2.2), DARK, Enum.Material.Metal)
	Kit.box(f, "Fork", Vector3.new(2.4, 0.2, 2.4), cf * CFrame.new(0, 0.9, -3.4), DARK, Enum.Material.Metal)
	Kit.box(f, "Load", Vector3.new(2.2, 2, 2.2), cf * CFrame.new(0, 2, -3.4), Color3.fromRGB(190, 140, 80), Enum.Material.Wood)
	f.WorldPivot = cf
	return f
end

builders.warehouse = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(160, 160, 165))
	local body = cf * CFrame.new(0, 0, 4)
	local w = L >= 4 and 20 or 17
	local top = block(m, body, w, 12, 10, 0.6, Color3.fromRGB(215, 160, 90), { rows = 1, cols = 3, material = Enum.Material.Metal, sideWindows = false, windowColor = Color3.fromRGB(190, 220, 240) })
	Kit.box(m, "Roof", Vector3.new(w + 1, 1, 13), body * CFrame.new(0, top + 0.5, 0), Color3.fromRGB(110, 110, 120), Enum.Material.Metal)
	local docks = L >= 5 and 3 or 2
	for i = 1, docks do
		local x = -w / 2 + i * (w / (docks + 1))
		Kit.box(m, "DockDoor", Vector3.new(4.4, 5.5, 0.3), body * CFrame.new(x, 3.6, -6.15), Color3.fromRGB(230, 230, 235), Enum.Material.DiamondPlate)
		Kit.box(m, "DockStripe", Vector3.new(4.8, 0.6, 0.35), body * CFrame.new(x, 6.7, -6.2), Color3.fromRGB(255, 200, 40))
	end
	frontSign(m, body, "📦 ALMACÉN", top - 1.5, -6.2, 10, Color3.fromRGB(60, 60, 70), Color3.fromRGB(255, 200, 60))
	crates(m, cf * CFrame.new(-9, 0.6, -6), 2, 2)
	local fl = forklift(m, cf * CFrame.new(3, 0.6, -7) * CFrame.Angles(0, math.rad(90), 0))
	slide(fl, Vector3.new(0, 0, -6), 0.18, "pingpong")
	if L >= 2 then
		crates(m, cf * CFrame.new(7, 0.6, -10), 2, 1, Color3.fromRGB(120, 170, 220))
	end
	if L >= 3 then
		local t = Kit.car(m, cf * CFrame.new(-w / 2 - 1, 0.6, 7), Color3.fromRGB(70, 130, 220), "truck")
		t.Name = "Truck"
	end
	if L >= 4 then
		Kit.box(m, "Pallets", Vector3.new(6, 0.5, 4), cf * CFrame.new(0, 0.85, -10), Color3.fromRGB(170, 120, 70), Enum.Material.Wood)
	end
	if L >= 5 then
		local logo = Kit.box(m, "Logo", Vector3.new(8, 3, 0.5), body * CFrame.new(0, top + 2.5, 0), pal.accent, Enum.Material.Neon)
		Kit.surfaceText(logo, "EXPRESS", Enum.NormalId.Front, nil, WHITE)
		pulse(logo, 0.7)
	end
end

builders.factory = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(130, 130, 135))
	local body = cf * CFrame.new(0, 0, 4)
	local floors = L >= 3 and 2 or 1
	local top = block(m, body, 20, 13, 9 * floors, 0.6, Color3.fromRGB(180, 90, 70), { rows = floors * 2, cols = 5, material = Enum.Material.Brick, windowColor = Color3.fromRGB(255, 220, 150) })
	Kit.box(m, "Roof", Vector3.new(21, 1, 14), body * CFrame.new(0, top + 0.5, 0), Color3.fromRGB(80, 80, 90), Enum.Material.Metal)
	frontSign(m, body, "🏭 FÁBRICA", top - 1.6, -6.6, 11, Color3.fromRGB(40, 40, 50), Color3.fromRGB(255, 170, 60))
	local chimneys = math.min(1 + L // 2, 3)
	for i = 1, chimneys do
		local x = -6 + (i - 1) * 6
		Kit.cylinder(m, "Stack", 12, 2.6, body * CFrame.new(x, top + 6.5, 3), Color3.fromRGB(170, 170, 175), Enum.Material.Concrete)
		local ring = Kit.cylinder(m, "StackRing", 1, 2.8, body * CFrame.new(x, top + 11, 3), Color3.fromRGB(230, 70, 60))
		Kit.smoke(ring, Color3.fromRGB(220, 220, 225), 5)
	end
	conveyor(m, cf * CFrame.new(0, 0.6, -9.5), 20, Color3.fromRGB(255, 120, 80), 5)
	-- Ventilador
	local fan = Kit.model(m, "Fan")
	local fc = body * CFrame.new(10.2, 5, 0) * CFrame.Angles(0, math.rad(-90), 0)
	for i = 0, 2 do
		Kit.box(fan, "Blade", Vector3.new(0.9, 3.2, 0.2), fc * CFrame.Angles(0, 0, math.rad(i * 120)) * CFrame.new(0, 1.5, -0.3), DARK, Enum.Material.Metal)
	end
	fan.WorldPivot = fc
	spin(fan, 240, "Z")
	if L >= 2 then
		for i = 0, 1 do
			Kit.cylinder(m, "Tank", 6, 3.6, cf * CFrame.new(-9 + i * 4.4, 3.6, -4.8), Color3.fromRGB(220, 225, 235), Enum.Material.Metal)
		end
	end
	if L >= 4 then
		Kit.box(m, "Pipe", Vector3.new(0.8, 0.8, 12), body * CFrame.new(10.6, top - 2, 0), Color3.fromRGB(80, 160, 210), Enum.Material.Metal)
		Kit.box(m, "Pipe", Vector3.new(0.8, 0.8, 12), body * CFrame.new(10.6, top - 4, 0), Color3.fromRGB(230, 200, 60), Enum.Material.Metal)
	end
	if L >= 5 then
		local neon = Kit.box(m, "NeonBand", Vector3.new(20.4, 0.6, 13.4), body * CFrame.new(0, top - 0.2, 0), pal.accent, Enum.Material.Neon)
		pulse(neon, 0.6)
	end
end

builders.techlab = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(230, 235, 240))
	local cyan = Color3.fromRGB(80, 230, 230)
	local floors = 2 + math.floor((L - 1) / 2)
	local body = cf * CFrame.new(0, 0, 3)
	local top = block(m, body, 16, 14, 6 * floors, 0.6, Color3.fromRGB(235, 240, 245), { rows = floors, cols = 4, windowColor = Color3.fromRGB(120, 210, 240), trim = cyan })
	Kit.box(m, "Entrance", Vector3.new(6, 5, 3), body * CFrame.new(0, 3.1, -8.5), GLASS, Enum.Material.Glass, { Transparency = 0.3 })
	Kit.box(m, "Canopy", Vector3.new(8, 0.5, 4), body * CFrame.new(0, 5.8, -8.5), WHITE)
	frontSign(m, body, "🔬 TECH LAB", top - 1.6, -7.2, 10, Color3.fromRGB(20, 30, 50), cyan)
	-- Radar
	local radar = Kit.model(m, "Radar")
	local rc = body * CFrame.new(-4, top + 2.5, 2)
	Kit.cylinder(m, "RadarMast", 2.5, 0.6, body * CFrame.new(-4, top + 1.25, 2), METAL, Enum.Material.Metal)
	Kit.box(radar, "Dish", Vector3.new(5, 3, 0.4), rc * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-25), 0, 0), WHITE, Enum.Material.Metal)
	Kit.cylinderX(radar, "Emitter", 2, 0.3, rc * CFrame.new(0, 0.8, -1) * CFrame.Angles(0, math.rad(90), 0), DARK)
	radar.WorldPivot = rc
	spin(radar, 35, "Y")
	-- Holograma
	local holo = Kit.ball(m, "Hologram", 3, cf * CFrame.new(-7, 5, -7), cyan, Enum.Material.Neon, { Transparency = 0.35, CanCollide = false })
	bob(holo, 1, 1.1)
	spin(holo, 80, "Y")
	Kit.cylinder(m, "Projector", 1.2, 2.4, cf * CFrame.new(-7, 1.2, -7), DARK, Enum.Material.Metal)
	if L >= 2 then
		local ant = Kit.cylinder(m, "Antenna", 6, 0.3, body * CFrame.new(5, top + 3, 3), METAL, Enum.Material.Metal)
		local tip = Kit.ball(m, "AntennaTip", 0.8, body * CFrame.new(5, top + 6.2, 3), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		pulse(tip, 1.5)
		ant.CastShadow = false
	end
	if L >= 4 then
		Kit.ball(m, "Dome", 6, body * CFrame.new(3, top, -2), Color3.fromRGB(200, 240, 255), Enum.Material.Glass, { Transparency = 0.35 })
	end
	if L >= 5 then
		local ring = Kit.model(m, "Ring")
		local c = body * CFrame.new(3, top + 5, -2)
		for i = 0, 11 do
			local a = math.rad(i * 30)
			Kit.box(ring, "Seg", Vector3.new(1.2, 0.4, 0.6), c * CFrame.new(math.cos(a) * 4, 0, math.sin(a) * 4) * CFrame.Angles(0, -a, 0), cyan, Enum.Material.Neon, { CanCollide = false })
		end
		ring.WorldPivot = c
		spin(ring, 60, "Y")
	end
end

builders.tower = function(m, cf, L, pal, S)
	foundation(m, cf, S - 2, S - 2, Color3.fromRGB(220, 225, 235))
	local blue = Color3.fromRGB(110, 120, 255)
	local floors = 5 + L * 3
	local fh = 4
	local body = cf * CFrame.new(0, 0, 2)
	-- Vestibulo
	Kit.box(m, "Lobby", Vector3.new(18, 6, 16), body * CFrame.new(0, 3.6, 0), Color3.fromRGB(230, 235, 245))
	Kit.box(m, "LobbyGlass", Vector3.new(14, 5, 0.3), body * CFrame.new(0, 3.4, -8.1), GLASS, Enum.Material.Glass, { Transparency = 0.25 })
	-- Torre
	local towerH = floors * fh
	local tw, td = 13, 12
	Kit.box(m, "Tower", Vector3.new(tw, towerH, td), body * CFrame.new(0, 6.6 + towerH / 2, 1), Color3.fromRGB(70, 90, 140), Enum.Material.Glass, { Reflectance = 0.25 })
	for f = 1, floors do
		local y = 6.6 + (f - 1) * fh
		local band = Kit.box(m, "FloorBand", Vector3.new(tw + 0.3, 0.5, td + 0.3), body * CFrame.new(0, y, 1), Color3.fromRGB(235, 240, 250))
		band.CastShadow = false
		for side = -1, 1, 2 do
			local win = Kit.box(m, "Window", Vector3.new(tw - 1, fh - 1.2, 0.2), body * CFrame.new(0, y + fh / 2, 1 + side * (td / 2 + 0.15)), Color3.fromRGB(150, 200, 255), Enum.Material.Glass, { Transparency = 0.1, CastShadow = false })
			win:AddTag("TE_Window")
			local sideWin = Kit.box(m, "Window", Vector3.new(0.2, fh - 1.2, td - 1), body * CFrame.new(side * (tw / 2 + 0.15), y + fh / 2, 1), Color3.fromRGB(150, 200, 255), Enum.Material.Glass, { Transparency = 0.1, CastShadow = false })
			sideWin:AddTag("TE_Window")
		end
	end
	local roofY = 6.6 + towerH
	local logo = Kit.box(m, "Logo", Vector3.new(10, 3.4, 0.5), body * CFrame.new(0, roofY - 2.5, 1 - td / 2 - 0.4), blue, Enum.Material.Neon)
	Kit.surfaceText(logo, "TINY EMPIRE", Enum.NormalId.Front, nil, WHITE)
	pulse(logo, 0.5)
	local sign = frontSign(m, body, "🏢 TORRE CORPORATIVA", 7.5, -8.2, 14, Color3.fromRGB(30, 35, 60), Color3.fromRGB(200, 210, 255))
	sign.Name = "LobbySign"
	-- Ascensor exterior
	Kit.box(m, "ElevatorShaft", Vector3.new(3, towerH, 0.3), body * CFrame.new(tw / 2 + 1.6, 6.6 + towerH / 2, -1.5) * CFrame.Angles(0, math.rad(90), 0), GLASS, Enum.Material.Glass, { Transparency = 0.6, CanCollide = false })
	local cab = Kit.box(m, "ElevatorCab", Vector3.new(2.6, 3.4, 2.6), body * CFrame.new(tw / 2 + 1.6, 8.4, -1.5), Color3.fromRGB(255, 210, 80), Enum.Material.Neon, { CanCollide = false })
	slide(cab, Vector3.new(0, towerH - 4, 0), 0.06, "pingpong")
	-- Antena
	Kit.cylinder(m, "Spire", 10, 0.6, body * CFrame.new(0, roofY + 5, 1), METAL, Enum.Material.Metal)
	local beacon = Kit.ball(m, "Beacon", 1.4, body * CFrame.new(0, roofY + 10.5, 1), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	pulse(beacon, 1.2)
	Kit.light(beacon, Color3.fromRGB(255, 80, 80), 20, 2)
	if L >= 3 then
		Kit.box(m, "RoofDeck", Vector3.new(tw + 2, 1, td + 2), body * CFrame.new(0, roofY + 0.5, 1), Color3.fromRGB(60, 65, 80), Enum.Material.Metal)
	end
	if L >= 5 then
		local pad = Kit.cylinder(m, "Helipad", 0.4, 9, body * CFrame.new(-3, roofY + 1.2, 3), Color3.fromRGB(50, 55, 65))
		Kit.surfaceText(pad, "H", Enum.NormalId.Right, nil, Color3.fromRGB(255, 220, 60))
		Kit.sparkles(beacon, Color3.fromRGB(180, 200, 255), 6)
	end
end

------------------------------------------------------------------------------

-- Construye el negocio `id` a nivel `level`. `cf` es el centro del solar.
function Buildings.build(parent, id, cf, level, palette, footprint)
	local m = Instance.new("Model")
	m.Name = id
	local builder = builders[id]
	if builder then
		builder(m, cf, level, palette, footprint)
	end
	-- Clientes en la puerta: mas negocio, mas gente
	local seed = level * 97
	for i = 1, #id do
		seed += string.byte(id, i) * i
	end
	Details.customers(m, cf, level, footprint, seed)
	if palette.premium then
		-- Tema dorado: bordes dorados y luces violetas
		local f = footprint - 2
		for _, side in ipairs({ -1, 1 }) do
			Kit.box(m, "GoldTrim", Vector3.new(f, 0.35, 0.5), cf * CFrame.new(0, 0.75, side * (f / 2 - 0.25)), palette.trim, Enum.Material.Neon, { CanCollide = false })
			Kit.box(m, "GoldTrim", Vector3.new(0.5, 0.35, f), cf * CFrame.new(side * (f / 2 - 0.25), 0.75, 0), palette.trim, Enum.Material.Neon, { CanCollide = false })
		end
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local post = Kit.box(m, "GoldPost", Vector3.new(0.8, 3, 0.8), cf * CFrame.new(x * (f / 2 - 0.4), 1.9, z * (f / 2 - 0.4)), palette.trim, Enum.Material.Foil, { CanCollide = false })
				local orb = Kit.ball(m, "GoldOrb", 1.1, cf * CFrame.new(x * (f / 2 - 0.4), 3.7, z * (f / 2 - 0.4)), palette.accent2, Enum.Material.Neon, { CanCollide = false })
				local _ = post
				Kit.light(orb, palette.accent2, 10, 1)
			end
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Trim" or d.Name == "Roof" or d.Name == "SawRoof") then
				if d.Name == "Wall" then
					d.Color = palette.wall
					d.Material = Enum.Material.Marble
				elseif d.Name == "Roof" or d.Name == "SawRoof" then
					d.Color = palette.roof
				else
					d.Color = palette.trim
					d.Material = Enum.Material.Foil
				end
			end
		end
	end
	m:SetAttribute("Business", id)
	m:SetAttribute("Level", level)
	m.WorldPivot = cf
	m.Parent = parent
	return m
end

return Buildings
