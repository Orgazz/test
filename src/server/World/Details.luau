--!nonstrict
-- Detalles urbanos: peatones, clientes, pasos de cebra, semaforos, mobiliario,
-- parada de autobus, banderas y nubes. Todo lo que se mueve lo anima el cliente.
--   TE_Walker        peaton (WalkMode "circle" | "line")
--   TE_TrafficLight  semaforo (luces Red / Yellow / Green)
--   TE_Sway          balanceo suave (banderas)
--   TE_Cloud         nube a la deriva

local Kit = require(script.Parent.Kit)

local Details = {}

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(45, 48, 58)

local SKIN = {
	Color3.fromRGB(255, 220, 180),
	Color3.fromRGB(235, 185, 140),
	Color3.fromRGB(190, 135, 95),
	Color3.fromRGB(140, 95, 65),
	Color3.fromRGB(95, 65, 45),
}
local CLOTHES = {
	Color3.fromRGB(240, 80, 80),
	Color3.fromRGB(80, 150, 240),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(90, 200, 120),
	Color3.fromRGB(180, 110, 240),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(240, 240, 245),
	Color3.fromRGB(60, 200, 210),
	Color3.fromRGB(255, 120, 180),
}
local PANTS = {
	Color3.fromRGB(50, 70, 130),
	Color3.fromRGB(40, 40, 50),
	Color3.fromRGB(120, 90, 60),
	Color3.fromRGB(90, 95, 105),
	Color3.fromRGB(30, 60, 90),
}
local HAIR = {
	Color3.fromRGB(40, 30, 25),
	Color3.fromRGB(110, 70, 40),
	Color3.fromRGB(230, 190, 100),
	Color3.fromRGB(180, 60, 40),
	Color3.fromRGB(20, 20, 25),
}

-- Persona estilo bloque (mirando a -Z, pivote en los pies)
function Details.person(parent, cf, rng, opts)
	opts = opts or {}
	local m = Kit.model(parent, "Person")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = opts.shirt or CLOTHES[rng:NextInteger(1, #CLOTHES)]
	local pants = PANTS[rng:NextInteger(1, #PANTS)]
	local hair = HAIR[rng:NextInteger(1, #HAIR)]
	local s = opts.scale or 1
	local function p(name, size, offset, color, material)
		local part = Kit.box(m, name, size * s, cf * CFrame.new(offset * s), color, material or Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = true })
		return part
	end
	p("LegL", Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, 1, 0), pants)
	p("LegR", Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, 1, 0), pants)
	p("Shoe", Vector3.new(0.95, 0.35, 1.1), Vector3.new(-0.5, 0.17, -0.1), DARK)
	p("Shoe", Vector3.new(0.95, 0.35, 1.1), Vector3.new(0.5, 0.17, -0.1), DARK)
	p("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt)
	p("ArmL", Vector3.new(0.8, 1.9, 0.8), Vector3.new(-1.4, 3.05, 0), shirt:Lerp(skin, 0.15))
	p("ArmR", Vector3.new(0.8, 1.9, 0.8), Vector3.new(1.4, 3.05, 0), shirt:Lerp(skin, 0.15))
	p("Head", Vector3.new(1.25, 1.25, 1.25), Vector3.new(0, 4.65, 0), skin)
	p("Hair", Vector3.new(1.35, 0.45, 1.35), Vector3.new(0, 5.35, 0.05), hair)
	p("EyeL", Vector3.new(0.18, 0.22, 0.05), Vector3.new(-0.28, 4.75, -0.63), DARK)
	p("EyeR", Vector3.new(0.18, 0.22, 0.05), Vector3.new(0.28, 4.75, -0.63), DARK)
	if rng:NextNumber() < 0.35 then
		-- Gorra o sombrero
		p("Cap", Vector3.new(1.4, 0.35, 1.4), Vector3.new(0, 5.45, 0), CLOTHES[rng:NextInteger(1, #CLOTHES)])
		p("Visor", Vector3.new(1.2, 0.15, 0.7), Vector3.new(0, 5.3, -0.9), CLOTHES[rng:NextInteger(1, #CLOTHES)])
	elseif rng:NextNumber() < 0.3 then
		p("Bag", Vector3.new(0.4, 1.2, 0.9), Vector3.new(1.85, 2.4, 0), Color3.fromRGB(150, 100, 60))
	end
	m.WorldPivot = cf
	return m
end

------------------------------------------------------------------------------
-- Peatones
------------------------------------------------------------------------------

local function walker(parent, rng, attrs)
	-- Posicion inicial = punto del recorrido en t = 0 (igual que el cliente)
	local pos, dir
	if attrs.WalkMode == "line" then
		local delta = attrs.B - attrs.A
		local len = delta.Magnitude
		local s = (attrs.Phase * 2 * len) % (2 * len)
		if s < len then
			pos, dir = attrs.A + delta * (s / len), delta.Unit
		else
			pos, dir = attrs.B - delta * ((s - len) / len), -delta.Unit
		end
	else
		local ang = attrs.Phase * math.pi * 2
		pos = Vector3.new(attrs.CenterX + math.cos(ang) * attrs.Radius, 0, attrs.CenterZ + math.sin(ang) * attrs.Radius)
		dir = Vector3.new(-math.sin(ang), 0, math.cos(ang)) * (attrs.Speed >= 0 and 1 or -1)
	end
	pos = Vector3.new(pos.X, attrs.BaseY, pos.Z)
	local m = Details.person(parent, CFrame.lookAt(pos, pos + dir), rng)
	m.Name = "Pedestrian"
	for k, v in pairs(attrs) do
		m:SetAttribute(k, v)
	end
	m:AddTag("TE_Walker")
	return m
end

function Details.pedestrians(map)
	local folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = map
	local rng = Random.new(77)
	-- Paseando por la plaza
	for i = 1, 12 do
		walker(folder, rng, {
			WalkMode = "circle",
			CenterX = 0,
			CenterZ = 0,
			Radius = 22 + (i % 4) * 7 + rng:NextNumber(-1.5, 1.5),
			Speed = (i % 2 == 0 and 1 or -1) * rng:NextNumber(3.5, 5.5),
			Phase = rng:NextNumber(0, 1),
			BaseY = 0.6,
		})
	end
	-- Por las aceras de las avenidas
	for i = 1, 16 do
		local sx = (i % 2 == 0) and 1 or -1
		local sz = (i % 4 < 2) and 1 or -1
		local a, b
		if i <= 8 then
			a = Vector3.new(sx * 66, 0.5, sz * 14)
			b = Vector3.new(sx * 315, 0.5, sz * 14)
		else
			a = Vector3.new(sx * 14, 0.5, sz * 66)
			b = Vector3.new(sx * 14, 0.5, sz * 175)
		end
		walker(folder, rng, {
			WalkMode = "line",
			A = a + Vector3.new(0, 0, rng:NextNumber(-0.8, 0.8)),
			B = b,
			Speed = rng:NextNumber(4, 6),
			Phase = rng:NextNumber(0, 1),
			BaseY = 0.5,
		})
	end
	return folder
end

-- Clientes delante de un negocio (cantidad segun nivel)
function Details.customers(parent, cf, level, size, seed)
	local rng = Random.new(seed)
	local count = math.min(3, 1 + math.floor((level - 1) / 2))
	local spots = {
		Vector3.new(-(size / 2 - 2.2), 0, -(size / 2 - 1.6)),
		Vector3.new(size / 2 - 2.2, 0, -(size / 2 - 1.6)),
		Vector3.new(-(size / 2 - 4.6), 0, -(size / 2 - 1.2)),
	}
	for i = 1, count do
		local spot = spots[i]
		local yaw = math.rad(180 + rng:NextNumber(-25, 25))
		local person = Details.person(parent, cf * CFrame.new(spot + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, yaw, 0), rng)
		person.Name = "Customer"
		if i == 1 then
			-- Saluda / celebra: brazo arriba
			local arm = person:FindFirstChild("ArmR")
			if arm then
				arm.CFrame = arm.CFrame * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(160))
			end
		end
	end
end

------------------------------------------------------------------------------
-- Calles
------------------------------------------------------------------------------

-- Paso de cebra: `cf` en el centro, rayas a lo largo de X local
function Details.crosswalk(parent, cf, width, depth)
	local n = math.floor(width / 2.4)
	for i = 0, n - 1 do
		local x = -width / 2 + 1.2 + i * 2.4
		Kit.box(parent, "Zebra", Vector3.new(1.3, 0.06, depth), cf * CFrame.new(x, 0, 0), WHITE, Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
	end
end

function Details.trafficLight(parent, cf, phase)
	local m = Kit.model(parent, "TrafficLight")
	Kit.cylinder(m, "Pole", 9, 0.5, cf * CFrame.new(0, 4.5, 0), DARK, Enum.Material.Metal)
	Kit.box(m, "Arm", Vector3.new(0.35, 0.35, 6), cf * CFrame.new(0, 8.8, -3), DARK, Enum.Material.Metal)
	local head = cf * CFrame.new(0, 7.8, -5.6)
	Kit.box(m, "Housing", Vector3.new(1.3, 3.6, 1.1), head, Color3.fromRGB(30, 30, 35))
	local lamps = { { "Red", 1.1, Color3.fromRGB(255, 60, 60) }, { "Yellow", 0, Color3.fromRGB(255, 200, 40) }, { "Green", -1.1, Color3.fromRGB(70, 230, 100) } }
	for _, l in ipairs(lamps) do
		local lamp = Kit.box(m, l[1], Vector3.new(0.8, 0.8, 0.2), head * CFrame.new(0, l[2], -0.6), l[3], Enum.Material.SmoothPlastic, { CastShadow = false })
		lamp:SetAttribute("OnColor", l[3])
		Kit.box(m, "Visor", Vector3.new(0.9, 0.12, 0.5), head * CFrame.new(0, l[2] + 0.45, -0.8), Color3.fromRGB(30, 30, 35))
	end
	m:SetAttribute("Phase", phase or 0)
	m:AddTag("TE_TrafficLight")
	return m
end

local function hydrant(parent, cf)
	local m = Kit.model(parent, "Hydrant")
	local red = Color3.fromRGB(220, 50, 45)
	Kit.cylinder(m, "Body", 2, 0.9, cf * CFrame.new(0, 1, 0), red)
	Kit.ball(m, "Cap", 0.9, cf * CFrame.new(0, 2, 0), red)
	Kit.cylinderX(m, "Nozzle", 1.3, 0.4, cf * CFrame.new(0, 1.3, 0), Color3.fromRGB(240, 200, 60))
	return m
end

local function trashBin(parent, cf, color)
	local m = Kit.model(parent, "TrashBin")
	Kit.cylinder(m, "Bin", 2.4, 1.6, cf * CFrame.new(0, 1.2, 0), color or Color3.fromRGB(60, 140, 90), Enum.Material.Metal)
	Kit.cylinder(m, "Lid", 0.25, 1.8, cf * CFrame.new(0, 2.5, 0), DARK, Enum.Material.Metal)
	return m
end

local function mailbox(parent, cf)
	local m = Kit.model(parent, "Mailbox")
	local blue = Color3.fromRGB(50, 90, 200)
	Kit.box(m, "Box", Vector3.new(1.6, 2.4, 1.4), cf * CFrame.new(0, 1.5, 0), blue, Enum.Material.Metal)
	Kit.cylinderX(m, "Top", 1.6, 1.4, cf * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, math.rad(90), 0), blue, Enum.Material.Metal)
	Kit.box(m, "Slot", Vector3.new(0.9, 0.12, 0.05), cf * CFrame.new(0, 2.2, -0.72), DARK)
	return m
end

local function planter(parent, cf, color)
	local m = Kit.model(parent, "Planter")
	Kit.box(m, "Pot", Vector3.new(2.4, 1.4, 2.4), cf * CFrame.new(0, 0.7, 0), Color3.fromRGB(190, 120, 80), Enum.Material.Brick)
	Kit.ball(m, "Plant", 2.6, cf * CFrame.new(0, 2, 0), color or Color3.fromRGB(80, 170, 80), Enum.Material.Grass, { CanCollide = false })
	return m
end

function Details.streetFurniture(map)
	local folder = Kit.model(map, "StreetFurniture")
	local items = { hydrant, trashBin, planter, mailbox }
	local n = 0
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			for i = 0, 5 do
				n += 1
				local x = sx * (84 + i * 44)
				local cf = CFrame.lookAt(Vector3.new(x, 0.5, sz * 15.3), Vector3.new(x, 0.5, 0))
				items[(n % #items) + 1](folder, cf)
			end
			for i = 0, 2 do
				n += 1
				local z = sz * (84 + i * 40)
				local cf = CFrame.lookAt(Vector3.new(sx * 15.3, 0.5, z), Vector3.new(0, 0.5, z))
				items[(n % #items) + 1](folder, cf)
			end
		end
	end
	return folder
end

function Details.crossings(map, ringX, ringZ)
	local folder = Kit.model(map, "Crossings")
	-- Salidas de la plaza
	for _, s in ipairs({ -1, 1 }) do
		Details.crosswalk(folder, CFrame.new(0, 0.33, s * 64), 22, 4)
		Details.crosswalk(folder, CFrame.new(s * 64, 0.33, 0) * CFrame.Angles(0, math.rad(90), 0), 22, 4)
		-- Cruces con el anillo exterior
		Details.crosswalk(folder, CFrame.new(0, 0.33, s * (ringZ - 16)), 22, 4)
		Details.crosswalk(folder, CFrame.new(s * (ringX - 16), 0.33, 0) * CFrame.Angles(0, math.rad(90), 0), 22, 4)
		-- Calles laterales
		for _, sz in ipairs({ -1, 1 }) do
			Details.crosswalk(folder, CFrame.new(s * 175, 0.33, sz * 16), 16, 3.5)
		end
	end
	-- Semaforos: en cada cruce de una avenida con el anillo hay luces para la
	-- avenida y luces (en fase opuesta) para el trafico del anillo, que se detiene en rojo.
	local function at(x, z, yaw)
		-- El brazo del semaforo (-Z local) apunta hacia el centro de la calzada
		return CFrame.new(x, 0.5, z) * CFrame.Angles(0, math.rad(yaw), 0)
	end
	local function light(cf, phase, road, cx, cz)
		local m = Details.trafficLight(folder, cf, phase)
		m:SetAttribute("Road", road)
		m:SetAttribute("CenterX", cx)
		m:SetAttribute("CenterZ", cz)
	end
	local phase = 0
	for _, s in ipairs({ -1, 1 }) do
		-- Cruce de la avenida norte-sur con el anillo en (0, s * ringZ)
		phase += 0.25
		light(at(15, s * (ringZ - 20), 90), phase, "main", 0, s * ringZ)
		light(at(-15, s * (ringZ - 20), -90), phase, "main", 0, s * ringZ)
		light(at(14, s * (ringZ + 13), s > 0 and 0 or 180), phase + 0.5, "ring", 0, s * ringZ)
		light(at(-14, s * (ringZ + 13), s > 0 and 0 or 180), phase + 0.5, "ring", 0, s * ringZ)
		-- Cruce de la avenida este-oeste con el anillo en (s * ringX, 0)
		phase += 0.25
		light(at(s * (ringX - 20), 15, 0), phase, "main", s * ringX, 0)
		light(at(s * (ringX - 20), -15, 180), phase, "main", s * ringX, 0)
		light(at(s * (ringX + 13), 14, s > 0 and 90 or -90), phase + 0.5, "ring", s * ringX, 0)
		light(at(s * (ringX + 13), -14, s > 0 and 90 or -90), phase + 0.5, "ring", s * ringX, 0)
	end
	return folder
end

function Details.busStop(parent, cf)
	local m = Kit.model(parent, "BusStop")
	local frame = Color3.fromRGB(60, 65, 80)
	for _, z in ipairs({ -4, 4 }) do
		Kit.box(m, "Post", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(-1.3, 3.5, z), frame, Enum.Material.Metal)
		Kit.box(m, "Post", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(1.3, 3.5, z), frame, Enum.Material.Metal)
	end
	Kit.box(m, "Roof", Vector3.new(4.2, 0.4, 9.4), cf * CFrame.new(0, 7.2, 0), Color3.fromRGB(240, 110, 60))
	Kit.box(m, "BackGlass", Vector3.new(0.2, 5, 8), cf * CFrame.new(1.4, 3.6, 0), Color3.fromRGB(180, 220, 245), Enum.Material.Glass, { Transparency = 0.45 })
	local ad = Kit.box(m, "Ad", Vector3.new(0.3, 4, 2.6), cf * CFrame.new(1.3, 3.6, 5.5), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	Kit.surfaceText(ad, "🍋 ¡Limonada fresca!", Enum.NormalId.Left, Color3.fromRGB(255, 200, 60), Color3.fromRGB(60, 40, 20))
	Kit.box(m, "Seat", Vector3.new(1.4, 0.4, 7), cf * CFrame.new(0.5, 1.8, 0), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
	local sign = Kit.box(m, "Sign", Vector3.new(0.2, 1.6, 1.6), cf * CFrame.new(-1.6, 8.4, -4), Color3.fromRGB(40, 120, 220))
	Kit.surfaceText(sign, "🚌", Enum.NormalId.Left, Color3.fromRGB(40, 120, 220), WHITE)
	Kit.surfaceText(sign, "🚌", Enum.NormalId.Right, Color3.fromRGB(40, 120, 220), WHITE)
	return m
end

function Details.flag(parent, cf, color, text)
	local m = Kit.model(parent, "FlagPole")
	Kit.cylinder(m, "Pole", 16, 0.4, cf * CFrame.new(0, 8, 0), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
	Kit.ball(m, "Finial", 0.8, cf * CFrame.new(0, 16.2, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Foil)
	-- Tela dividida en segmentos: el cliente los encadena para que ondee (TE_Flag)
	local flagModel = Kit.model(m, "Flag")
	local hinge = cf * CFrame.new(0, 14, 0)
	local segments = 5
	local segW = 5.4 / segments
	for i = 1, segments do
		local segColor = (i % 2 == 0) and color:Lerp(WHITE, 0.35) or color
		Kit.box(flagModel, "Seg" .. i, Vector3.new(segW + 0.05, 3, 0.15), hinge * CFrame.new(segW * (i - 0.5) + 0.2, 0, 0), segColor, Enum.Material.Fabric, { CanCollide = false, CastShadow = false })
	end
	if text then
		-- El texto va en un estandarte fijo bajo la bandera
		local banner = Kit.box(m, "Banner", Vector3.new(3.4, 1, 0.2), cf * CFrame.new(1.9, 10.5, 0), color, Enum.Material.SmoothPlastic, { CanCollide = false })
		Kit.box(m, "BannerArm", Vector3.new(3.6, 0.15, 0.15), cf * CFrame.new(1.9, 11.1, 0), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
		Kit.surfaceText(banner, text, Enum.NormalId.Front, nil, WHITE)
		Kit.surfaceText(banner, text, Enum.NormalId.Back, nil, WHITE)
	end
	flagModel.WorldPivot = hinge
	flagModel:SetAttribute("Segments", segments)
	flagModel:SetAttribute("SegmentWidth", segW)
	flagModel:AddTag("TE_Flag")
	return m
end

------------------------------------------------------------------------------
-- Trampolin (el cliente aplica el impulso al personaje local: fisica fluida)
------------------------------------------------------------------------------

function Details.trampoline(parent, cf, color)
	local m = Kit.model(parent, "Trampoline")
	local frame = Color3.fromRGB(60, 90, 200)
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		Kit.box(m, "Leg", Vector3.new(0.5, 2.2, 0.5), cf * CFrame.new(math.cos(a) * 5.2, 1.1, math.sin(a) * 5.2), DARK, Enum.Material.Metal)
	end
	Kit.cylinder(m, "Rim", 0.8, 12, cf * CFrame.new(0, 2.4, 0), frame, Enum.Material.Metal)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		Kit.box(m, "Spring", Vector3.new(0.9, 0.25, 0.25), cf * CFrame.new(math.cos(a) * 5.2, 2.85, math.sin(a) * 5.2) * CFrame.Angles(0, -a, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	end
	local mat = Kit.cylinder(m, "Mat", 0.3, 9.6, cf * CFrame.new(0, 2.95, 0), color or Color3.fromRGB(255, 90, 160), Enum.Material.Fabric)
	Kit.cylinder(m, "Ring", 0.32, 4, cf * CFrame.new(0, 2.96, 0), Color3.fromRGB(255, 230, 90), Enum.Material.Neon, { CanCollide = false })
	mat:AddTag("TE_Trampoline")
	mat:SetAttribute("Power", 115)
	local sign = Kit.box(m, "Sign", Vector3.new(4, 1.2, 0.2), cf * CFrame.new(0, 4.6, 6.2), Color3.fromRGB(255, 220, 90))
	Kit.surfaceText(sign, "¡SALTA!", Enum.NormalId.Front, Color3.fromRGB(255, 220, 90), DARK)
	Kit.surfaceText(sign, "¡SALTA!", Enum.NormalId.Back, Color3.fromRGB(255, 220, 90), DARK)
	Kit.box(m, "SignPost", Vector3.new(0.3, 3.6, 0.3), cf * CFrame.new(0, 2, 6.2), DARK, Enum.Material.Metal)
	return m
end

------------------------------------------------------------------------------
-- Cielo
------------------------------------------------------------------------------

function Details.clouds(map)
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = map
	local rng = Random.new(31)
	for i = 1, 16 do
		local m = Kit.model(folder, "Cloud")
		local c = CFrame.new(rng:NextNumber(-650, 650), rng:NextNumber(150, 210), rng:NextNumber(-420, 420))
		local puffs = rng:NextInteger(4, 7)
		for j = 1, puffs do
			local d = rng:NextNumber(18, 34)
			Kit.ball(m, "Puff", d, c * CFrame.new((j - puffs / 2) * 13 + rng:NextNumber(-4, 4), rng:NextNumber(-3, 5), rng:NextNumber(-8, 8)), WHITE, Enum.Material.SmoothPlastic, {
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Transparency = 0.08,
			})
		end
		m.WorldPivot = c
		m:SetAttribute("Speed", rng:NextNumber(2, 5))
		m:AddTag("TE_Cloud")
		local _ = i
	end
	return folder
end

------------------------------------------------------------------------------
-- Detalles de azotea para las tiendas
------------------------------------------------------------------------------

function Details.rooftop(parent, cf, w, d, rng)
	local roll = rng:NextNumber()
	if roll < 0.45 then
		Kit.box(parent, "ACUnit", Vector3.new(3, 1.6, 2.4), cf * CFrame.new(-w / 4, 0.8, d / 6), Color3.fromRGB(200, 205, 210), Enum.Material.Metal)
		Kit.cylinderX(parent, "Fan", 0.2, 1.4, cf * CFrame.new(-w / 4, 1.65, d / 6) * CFrame.Angles(0, 0, math.rad(90)), DARK)
		Kit.box(parent, "Vent", Vector3.new(1, 1.8, 1), cf * CFrame.new(w / 4, 0.9, -d / 6), Color3.fromRGB(170, 170, 175), Enum.Material.Metal)
	elseif roll < 0.75 then
		local tank = cf * CFrame.new(w / 5, 0, d / 6)
		for _, x in ipairs({ -1.2, 1.2 }) do
			for _, z in ipairs({ -1.2, 1.2 }) do
				Kit.box(parent, "TankLeg", Vector3.new(0.3, 2.4, 0.3), tank * CFrame.new(x, 1.2, z), Color3.fromRGB(110, 80, 60), Enum.Material.Wood)
			end
		end
		Kit.cylinder(parent, "WaterTank", 3, 3.4, tank * CFrame.new(0, 3.9, 0), Color3.fromRGB(140, 100, 70), Enum.Material.WoodPlanks)
		Kit.cylinder(parent, "TankRoof", 0.6, 3.8, tank * CFrame.new(0, 5.6, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	else
		Kit.cylinder(parent, "Antenna", 5, 0.25, cf * CFrame.new(w / 4, 2.5, 0), Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
		local dish = Kit.cylinder(parent, "Dish", 0.3, 2.2, cf * CFrame.new(-w / 4, 1.3, 0) * CFrame.Angles(math.rad(35), 0, 0), WHITE)
		local _ = dish
		Kit.flowerBed(parent, cf * CFrame.new(0, 0, d / 4), w * 0.5, 2)
	end
end

return Details
