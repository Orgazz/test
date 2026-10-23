--!nonstrict
-- Construye el mapa: suelo, carreteras, plaza central, 4 barrios, tiendas,
-- vehiculos decorativos e iluminacion. Devuelve la lista de parcelas.

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)
local Palettes = require(script.Parent.Palettes)
local Details = require(script.Parent.Details)

local WorldBuilder = {}

local ROAD = Color3.fromRGB(70, 72, 80)
local LINE = Color3.fromRGB(255, 220, 90)
local SIDEWALK = Color3.fromRGB(205, 205, 210)
local WHITE = Color3.new(1, 1, 1)

WorldBuilder.RingX = 330
WorldBuilder.RingZ = 185
WorldBuilder.PlotSize = 120

-- Cuadrantes: (signo X, signo Z, indice de barrio)
local QUADRANTS = {
	{ sx = 1, sz = 1, hood = 1 },
	{ sx = -1, sz = 1, hood = 2 },
	{ sx = -1, sz = -1, hood = 3 },
	{ sx = 1, sz = -1, hood = 4 },
}

local function road(parent, size, cf, dashedAlongX)
	local r = Kit.box(parent, "Road", size, cf, ROAD, Enum.Material.Asphalt)
	local long = dashedAlongX and size.X or size.Z
	local n = math.floor(long / 12)
	for i = 0, n - 1 do
		local off = -long / 2 + 6 + i * 12
		local dcf = dashedAlongX and cf * CFrame.new(off, size.Y / 2 + 0.02, 0) or cf * CFrame.new(0, size.Y / 2 + 0.02, off)
		Kit.box(parent, "Dash", dashedAlongX and Vector3.new(5, 0.05, 0.6) or Vector3.new(0.6, 0.05, 5), dcf, LINE, Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
	end
	return r
end

local function sidewalk(parent, size, cf)
	return Kit.box(parent, "Sidewalk", size, cf, SIDEWALK, Enum.Material.Concrete)
end

local function lighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(200, 220, 255)
	atm.Decay = Color3.fromRGB(110, 130, 170)
	atm.Glare = 0.2
	atm.Haze = 1.2
	atm.Parent = Lighting
	local cc = Lighting:FindFirstChild("TE_Color") or Instance.new("ColorCorrectionEffect")
	cc.Name = "TE_Color"
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 16
		sky.MoonAngularSize = 9
		sky.StarCount = 3000
		sky.Parent = Lighting
	end
end

------------------------------------------------------------------------------
-- PLAZA CENTRAL
------------------------------------------------------------------------------

local function fountain(parent, cf, radius, premium)
	local m = Kit.model(parent, "Fountain")
	local stone = premium and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(225, 225, 230)
	Kit.cylinder(m, "Rim", 2, radius * 2, cf * CFrame.new(0, 1, 0), stone, premium and Enum.Material.Foil or Enum.Material.Marble)
	local water = Kit.cylinder(m, "Water", 0.4, radius * 2 - 2, cf * CFrame.new(0, 1.9, 0), Color3.fromRGB(80, 180, 255), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	water.Reflectance = 0.2
	Kit.cylinder(m, "Column", 6, radius * 0.25, cf * CFrame.new(0, 4, 0), stone, Enum.Material.Marble)
	Kit.cylinder(m, "Bowl", 1, radius * 0.9, cf * CFrame.new(0, 7, 0), stone, Enum.Material.Marble)
	local top = Kit.ball(m, "Spout", radius * 0.25, cf * CFrame.new(0, 8, 0), Color3.fromRGB(120, 210, 255), Enum.Material.Neon, { CanCollide = false })
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(170, 225, 255))
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) })
	p.Lifetime = NumberRange.new(1, 1.4)
	p.Rate = 60
	p.Speed = NumberRange.new(10, 14)
	p.SpreadAngle = Vector2.new(25, 25)
	p.Acceleration = Vector3.new(0, -25, 0)
	p.EmissionDirection = Enum.NormalId.Top
	p.LightEmission = 0.6
	p.Parent = top
	return m
end

local function kiosk(parent, cf, name, color, icon)
	local m = Kit.model(parent, "Kiosk")
	Kit.box(m, "Base", Vector3.new(8, 4, 6), cf * CFrame.new(0, 2, 0), WHITE, Enum.Material.Wood)
	Kit.box(m, "Counter", Vector3.new(8.4, 0.4, 6.4), cf * CFrame.new(0, 4.2, 0), color)
	for _, x in ipairs({ -3.8, 3.8 }) do
		for _, z in ipairs({ -2.8, 2.8 }) do
			Kit.box(m, "Post", Vector3.new(0.4, 4, 0.4), cf * CFrame.new(x, 6.2, z), WHITE)
		end
	end
	Kit.box(m, "Roof", Vector3.new(9.4, 0.6, 7.4), cf * CFrame.new(0, 8.4, 0), color)
	Kit.wedge(m, "RoofTop", Vector3.new(9.4, 1.6, 3.7), cf * CFrame.new(0, 9.5, -1.85), color:Lerp(WHITE, 0.3))
	Kit.wedge(m, "RoofTop", Vector3.new(9.4, 1.6, 3.7), cf * CFrame.new(0, 9.5, 1.85) * CFrame.Angles(0, math.rad(180), 0), color:Lerp(WHITE, 0.3))
	local sign = Kit.box(m, "Sign", Vector3.new(7, 1.6, 0.3), cf * CFrame.new(0, 7.4, -3.1), WHITE)
	Kit.surfaceText(sign, icon .. " " .. name, Enum.NormalId.Front, WHITE, color)
	local bulb = Kit.box(m, "Glow", Vector3.new(6, 0.2, 0.2), cf * CFrame.new(0, 8, -3.3), Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
	Kit.light(bulb, Color3.fromRGB(255, 220, 160), 12, 1)
	return m
end

local function infoBoard(parent, cf, title, lines, color)
	local m = Kit.model(parent, "InfoBoard")
	Kit.box(m, "Leg", Vector3.new(0.6, 6, 0.6), cf * CFrame.new(-5, 3, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	Kit.box(m, "Leg", Vector3.new(0.6, 6, 0.6), cf * CFrame.new(5, 3, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	local board = Kit.box(m, "Board", Vector3.new(12, 9, 0.5), cf * CFrame.new(0, 9.5, 0), Color3.fromRGB(40, 45, 60))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
	frame.Parent = gui
	local head = Instance.new("TextLabel")
	head.Size = UDim2.new(1, 0, 0.18, 0)
	head.BackgroundColor3 = color
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = WHITE
	head.Text = title
	head.Parent = frame
	local body = Instance.new("TextLabel")
	body.Position = UDim2.new(0.05, 0, 0.22, 0)
	body.Size = UDim2.new(0.9, 0, 0.74, 0)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextScaled = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(235, 240, 255)
	body.Text = table.concat(lines, "\n")
	body.Parent = frame
	local back = Kit.surfaceText(board, "TINY EMPIRE", Enum.NormalId.Back, Color3.fromRGB(40, 45, 60), color)
	back.Name = "BackText"
	return m, board
end

local function signpost(parent, cf, entries)
	local m = Kit.model(parent, "Signpost")
	Kit.cylinder(m, "Pole", 10, 0.6, cf * CFrame.new(0, 5, 0), Color3.fromRGB(80, 60, 45), Enum.Material.Wood)
	for i, e in ipairs(entries) do
		local dir = e.dir
		local y = 9 - (i - 1) * 2.2
		local ang = math.atan2(-dir.X, -dir.Z)
		local arrowCF = CFrame.new((cf * CFrame.new(0, y, 0)).Position) * CFrame.Angles(0, ang, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(3.2, 0, 0)
		local arrow = Kit.box(m, "Arrow", Vector3.new(6.4, 1.6, 0.3), arrowCF, e.color, Enum.Material.SmoothPlastic)
		Kit.surfaceText(arrow, e.text, Enum.NormalId.Front, e.color, WHITE)
		Kit.surfaceText(arrow, e.text, Enum.NormalId.Back, e.color, WHITE)
		-- Punta de flecha
		Kit.wedge(m, "ArrowTip", Vector3.new(0.3, 0.8, 1.2), arrowCF * CFrame.new(3.8, 0.4, 0) * CFrame.Angles(0, math.rad(-90), 0), e.color)
		Kit.wedge(m, "ArrowTip", Vector3.new(0.3, 0.8, 1.2), arrowCF * CFrame.new(3.8, -0.4, 0) * CFrame.Angles(math.rad(180), math.rad(-90), 0), e.color)
	end
	return m
end

local function stage(parent, cf)
	local m = Kit.model(parent, "Stage")
	Kit.box(m, "Platform", Vector3.new(26, 2, 14), cf * CFrame.new(0, 1, 0), Color3.fromRGB(90, 70, 110), Enum.Material.Wood)
	local colors = { Color3.fromRGB(255, 80, 150), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(140, 255, 120) }
	for i = 0, 5 do
		for j = 0, 2 do
			local tile = Kit.box(m, "DanceTile", Vector3.new(3.6, 0.2, 3.6), cf * CFrame.new(-9.5 + i * 3.8, 2.1, -3.8 + j * 3.8), colors[((i + j) % 4) + 1], Enum.Material.Neon)
			tile:AddTag("TE_Pulse")
			tile:SetAttribute("PulseSpeed", 1 + ((i * 3 + j) % 4) * 0.4)
		end
	end
	Kit.box(m, "Back", Vector3.new(26, 12, 1), cf * CFrame.new(0, 8, 7), Color3.fromRGB(40, 35, 60))
	local banner = Kit.box(m, "Banner", Vector3.new(20, 4, 0.4), cf * CFrame.new(0, 11, 6.3), Color3.fromRGB(255, 90, 160), Enum.Material.Neon)
	Kit.surfaceText(banner, "⭐ ZONA SOCIAL ⭐", Enum.NormalId.Front, nil, WHITE)
	banner:AddTag("TE_Pulse")
	banner:SetAttribute("PulseSpeed", 0.6)
	for _, x in ipairs({ -12, 12 }) do
		Kit.box(m, "Speaker", Vector3.new(3, 5, 3), cf * CFrame.new(x, 4.5, 4), Color3.fromRGB(30, 30, 35))
		Kit.cylinderX(m, "Cone", 0.3, 2.2, cf * CFrame.new(x, 5, 2.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(80, 80, 90))
		local spot = Kit.box(m, "Spot", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(x, 12.5, 5), Color3.fromRGB(255, 255, 220), Enum.Material.Neon)
		local l = Instance.new("SpotLight")
		l.Angle = 50
		l.Range = 30
		l.Brightness = 3
		l.Face = Enum.NormalId.Front
		l.Color = x < 0 and Color3.fromRGB(255, 120, 200) or Color3.fromRGB(120, 200, 255)
		l.Enabled = false
		l.Parent = spot
		spot:AddTag("TE_Lamp")
	end
	-- Escaleras
	for i = 0, 1 do
		Kit.box(m, "Step", Vector3.new(8, 0.7, 1.5), cf * CFrame.new(0, 0.35 + i * 0.7, -7.75 - (1 - i) * 1.5), Color3.fromRGB(110, 90, 130), Enum.Material.Wood)
	end
	return m
end

local function buildPlaza(map)
	local plaza = Kit.model(map, "Plaza")
	local R = 58
	Kit.cylinder(plaza, "Paving", 0.6, R * 2, CFrame.new(0, 0.3, 0), Color3.fromRGB(235, 225, 210), Enum.Material.Pavement)
	Kit.cylinder(plaza, "Ring", 0.62, R * 2 - 16, CFrame.new(0, 0.31, 0), Color3.fromRGB(215, 175, 140), Enum.Material.Pavement)
	Kit.cylinder(plaza, "Inner", 0.64, 40, CFrame.new(0, 0.32, 0), Color3.fromRGB(240, 235, 225), Enum.Material.Marble)
	-- Bordillo
	for i = 0, 47 do
		local a = math.rad(i * 7.5)
		local pos = Vector3.new(math.cos(a) * (R - 0.5), 0.8, math.sin(a) * (R - 0.5))
		if math.abs(pos.X) > 14 and math.abs(pos.Z) > 14 then
			Kit.box(plaza, "Curb", Vector3.new(1, 1, 8), CFrame.lookAt(pos, Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(190, 185, 180), Enum.Material.Concrete)
		end
	end
	local mosaic = { Color3.fromRGB(255, 150, 120), Color3.fromRGB(120, 190, 255), Color3.fromRGB(255, 215, 110), Color3.fromRGB(150, 220, 140) }
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		local mid = Vector3.new(math.cos(a) * 34, 0.66, math.sin(a) * 34)
		Kit.box(plaza, "Mosaic", Vector3.new(2.2, 0.05, 26), CFrame.lookAt(mid, Vector3.new(0, 0.66, 0)), mosaic[(i % 4) + 1], Enum.Material.Pavement, { CanCollide = false, CastShadow = false })
	end
	fountain(plaza, CFrame.new(0, 0.6, 0), 9)
	-- Arboles y bancos en circulo
	for i = 0, 7 do
		local a = math.rad(22.5 + i * 45)
		local p = Vector3.new(math.cos(a) * 34, 0.6, math.sin(a) * 34)
		Kit.cylinder(plaza, "Planter", 1.4, 7, CFrame.new(p + Vector3.new(0, 0.7, 0)), Color3.fromRGB(180, 140, 110), Enum.Material.Brick)
		Kit.tree(plaza, CFrame.new(p + Vector3.new(0, 1.4, 0)), "round", Color3.fromRGB(110, 190, 90))
		local bp = Vector3.new(math.cos(a) * 26, 0.6, math.sin(a) * 26)
		Kit.bench(plaza, CFrame.lookAt(bp, Vector3.new(0, 0.6, 0)))
	end
	for i = 0, 11 do
		local a = math.rad(i * 30)
		if i % 3 ~= 0 and i ~= 7 and i ~= 8 then
			Kit.lamp(plaza, CFrame.lookAt(Vector3.new(math.cos(a) * 50, 0.6, math.sin(a) * 50), Vector3.new(0, 0.6, 0)), Color3.fromRGB(50, 55, 70))
		end
	end
	-- Escenario social (norte-oeste) y kioscos
	stage(plaza, CFrame.lookAt(Vector3.new(-33, 0.6, -33), Vector3.new(0, 0.6, 0)))
	kiosk(plaza, CFrame.lookAt(Vector3.new(34, 0.6, -30), Vector3.new(0, 0.6, 0)), "Helados", Color3.fromRGB(255, 120, 170), "🍦")
	kiosk(plaza, CFrame.lookAt(Vector3.new(-36, 0.6, 30), Vector3.new(0, 0.6, 0)), "Palomitas", Color3.fromRGB(255, 80, 80), "🍿")
	kiosk(plaza, CFrame.lookAt(Vector3.new(36, 0.6, 30), Vector3.new(0, 0.6, 0)), "Globos", Color3.fromRGB(90, 160, 255), "🎈")

	-- Cartel de bienvenida
	local arch = Kit.model(plaza, "WelcomeArch")
	for _, x in ipairs({ -11, 11 }) do
		Kit.box(arch, "Pillar", Vector3.new(2.4, 16, 2.4), CFrame.new(x, 8.6, -56), Color3.fromRGB(255, 200, 70), Enum.Material.SmoothPlastic)
	end
	local title = Kit.box(arch, "Title", Vector3.new(26, 5, 1.2), CFrame.new(0, 17, -56), Color3.fromRGB(255, 110, 70))
	Kit.surfaceText(title, "🏙️ TINY EMPIRE TYCOON", Enum.NormalId.Front, Color3.fromRGB(255, 110, 70), WHITE)
	Kit.surfaceText(title, "🏙️ TINY EMPIRE TYCOON", Enum.NormalId.Back, Color3.fromRGB(255, 110, 70), WHITE)
	local glow = Kit.box(arch, "Glow", Vector3.new(26.4, 0.4, 1.4), CFrame.new(0, 14.3, -56), Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
	Kit.light(glow, Color3.fromRGB(255, 220, 150), 24, 2)

	-- Paneles informativos (tutorial integrado en el mundo)
	infoBoard(plaza, CFrame.lookAt(Vector3.new(-16, 0.6, 46), Vector3.new(0, 0.6, 0)), "📘 CÓMO JUGAR", {
		"1. Sigue la flecha hasta TU parcela.",
		"2. Pisa los botones verdes para construir.",
		"3. Tus negocios ganan dinero solos.",
		"4. Mejora negocios (botones azules) y",
		"   compra Mejoras de Imperio en el menú.",
		"5. Expande tu parcela y completa retos.",
		"6. ¡Recoge maletines 💼 aquí en la plaza!",
	}, Color3.fromRGB(80, 160, 255))
	local _, lb = infoBoard(plaza, CFrame.lookAt(Vector3.new(16, 0.6, 46), Vector3.new(0, 0.6, 0)), "🏆 RANKING DEL SERVIDOR", { "Cargando..." }, Color3.fromRGB(255, 180, 40))
	lb.Name = "LeaderboardBoard"

	signpost(plaza, CFrame.new(16, 0.6, 62), {
		{ text = "Barrio Pastel", dir = Vector3.new(1, 0, 0.3), color = Color3.fromRGB(255, 130, 180) },
		{ text = "Distrito Verde", dir = Vector3.new(-1, 0, 0.3), color = Color3.fromRGB(80, 170, 90) },
	})
	signpost(plaza, CFrame.new(-16, 0.6, -62), {
		{ text = "Puerto Industrial", dir = Vector3.new(-1, 0, -0.3), color = Color3.fromRGB(230, 150, 40) },
		{ text = "Costa Sol", dir = Vector3.new(1, 0, -0.3), color = Color3.fromRGB(40, 180, 200) },
	})
	-- Banderas y parada de autobus
	Details.flag(plaza, CFrame.new(28, 0.6, 50), Color3.fromRGB(255, 110, 70), "TINY EMPIRE")
	Details.flag(plaza, CFrame.new(-28, 0.6, 50), Color3.fromRGB(80, 160, 255), "⭐")
	Details.flag(plaza, CFrame.new(28, 0.6, -50), Color3.fromRGB(90, 200, 120), "⭐")
	Details.flag(plaza, CFrame.new(-28, 0.6, -50), Color3.fromRGB(255, 200, 60), "TINY EMPIRE")
	Details.busStop(plaza, CFrame.new(72, 0.2, 30))
	-- Zona de recogida de maletines
	local crates = Instance.new("Folder")
	crates.Name = "Crates"
	crates.Parent = map
	return plaza
end

------------------------------------------------------------------------------
-- CARRETERAS
------------------------------------------------------------------------------

local function buildRoads(map)
	local roads = Kit.model(map, "Roads")
	local RX, RZ = WorldBuilder.RingX, WorldBuilder.RingZ
	-- Avenidas principales en cruz
	road(roads, Vector3.new(RX * 2, 0.3, 24), CFrame.new(0, 0.15, 0), true)
	road(roads, Vector3.new(24, 0.3, RZ * 2), CFrame.new(0, 0.15, 0), false)
	for _, s in ipairs({ -1, 1 }) do
		sidewalk(roads, Vector3.new(RX * 2, 0.5, 4), CFrame.new(0, 0.25, s * 14))
		sidewalk(roads, Vector3.new(4, 0.5, RZ * 2), CFrame.new(s * 14, 0.25, 0))
	end
	-- Anillo exterior
	for _, s in ipairs({ -1, 1 }) do
		road(roads, Vector3.new(RX * 2 + 20, 0.3, 20), CFrame.new(0, 0.16, s * RZ), true)
		road(roads, Vector3.new(20, 0.3, RZ * 2 + 20), CFrame.new(s * RX, 0.16, 0), false)
	end
	-- Calles laterales entre parcelas
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			road(roads, Vector3.new(18, 0.3, RZ - 22), CFrame.new(sx * 175, 0.15, sz * (12 + (RZ - 22) / 2 - 0.5)), false)
		end
	end
	return roads
end

------------------------------------------------------------------------------
-- BARRIOS: decoracion, tiendas y elementos tematicos
------------------------------------------------------------------------------

local SHOPS = {
	{ "Supermercado", "🛒" },
	{ "Floristería", "🌷" },
	{ "Banco", "🏦" },
	{ "Cine", "🎬" },
	{ "Heladería", "🍨" },
	{ "Librería", "📚" },
	{ "Gimnasio", "🏋️" },
	{ "Pizzería", "🍕" },
	{ "Farmacia", "💊" },
	{ "Peluquería", "💈" },
	{ "Tienda Surf", "🏄" },
	{ "Ferretería", "🔨" },
	{ "Hotel", "🏨" },
	{ "Museo", "🏛️" },
	{ "Arcade", "🕹️" },
	{ "Mercado", "🧺" },
}

local function shop(parent, cf, pal, name, icon, floors)
	local m = Kit.model(parent, "Shop")
	local w, d = 16, 12
	local h = floors * 6
	local wall = (floors % 2 == 0) and pal.wall or pal.wall2
	Kit.box(m, "Wall", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), wall)
	Kit.windows(m, cf * CFrame.new(0, h / 2 + 2, -d / 2 - 0.1), w - 2, h - 5, math.max(1, floors - 1), 3, Color3.fromRGB(170, 220, 255), pal.trim)
	Kit.box(m, "Storefront", Vector3.new(w - 3, 3.6, 0.3), cf * CFrame.new(0, 2.2, -d / 2 - 0.15), Color3.fromRGB(170, 220, 255), Enum.Material.Glass, { Transparency = 0.3 })
	Kit.awning(m, cf * CFrame.new(0, 4.6, -d / 2 - 1.3), w - 2, 2.6, pal.accent, WHITE)
	Kit.box(m, "Cornice", Vector3.new(w + 0.8, 0.8, d + 0.8), cf * CFrame.new(0, h + 0.4, 0), pal.trim)
	local sign = Kit.box(m, "Sign", Vector3.new(10, 2, 0.4), cf * CFrame.new(0, h + 1.8, -d / 2 + 0.6), WHITE)
	Kit.surfaceText(sign, icon .. " " .. name, Enum.NormalId.Front, WHITE, pal.accent:Lerp(Color3.new(0, 0, 0), 0.25))
	local glow = Kit.box(m, "Glow", Vector3.new(w - 3, 0.2, 0.2), cf * CFrame.new(0, 4.1, -d / 2 - 0.4), Color3.fromRGB(255, 230, 170), Enum.Material.Neon)
	Kit.light(glow, Color3.fromRGB(255, 220, 160), 14, 1.2)
	Details.rooftop(m, cf * CFrame.new(0, h + 0.8, 0), w, d, Random.new(#name * 31 + floors))
	-- Escalon de entrada y macetas
	Kit.box(m, "Step", Vector3.new(4, 0.4, 1.4), cf * CFrame.new(0, 0.2, -d / 2 - 0.7), Color3.fromRGB(200, 200, 205), Enum.Material.Concrete)
	for _, x in ipairs({ -w / 2 + 1.2, w / 2 - 1.2 }) do
		Kit.box(m, "Pot", Vector3.new(1.4, 1, 1.4), cf * CFrame.new(x, 0.5, -d / 2 - 1), Color3.fromRGB(190, 120, 80), Enum.Material.Brick)
		Kit.ball(m, "Plant", 1.8, cf * CFrame.new(x, 1.6, -d / 2 - 1), Color3.fromRGB(80, 170, 80), Enum.Material.Grass, { CanCollide = false })
	end
	return m
end

local function containers(parent, cf)
	local colors = { Color3.fromRGB(220, 70, 60), Color3.fromRGB(60, 120, 200), Color3.fromRGB(240, 180, 40), Color3.fromRGB(60, 170, 110) }
	for i = 0, 3 do
		for j = 0, 1 do
			local c = Kit.box(parent, "Container", Vector3.new(6, 6, 14), cf * CFrame.new(i * 6.4, 3 + j * 6.05, 0), colors[((i + j * 2) % 4) + 1], Enum.Material.CorrodedMetal)
			c.Name = "Container"
		end
	end
end

local function portCrane(parent, cf)
	local m = Kit.model(parent, "PortCrane")
	local y = Color3.fromRGB(240, 180, 40)
	for _, x in ipairs({ -5, 5 }) do
		for _, z in ipairs({ -4, 4 }) do
			Kit.box(m, "Leg", Vector3.new(1.2, 24, 1.2), cf * CFrame.new(x, 12, z), y, Enum.Material.Metal)
		end
	end
	Kit.box(m, "Top", Vector3.new(12, 2, 10), cf * CFrame.new(0, 25, 0), y, Enum.Material.Metal)
	local arm = Kit.box(m, "Boom", Vector3.new(2, 1.6, 34), cf * CFrame.new(0, 27, -10), y, Enum.Material.Metal)
	arm.Name = "Boom"
	Kit.box(m, "Cabin", Vector3.new(3, 3, 3), cf * CFrame.new(0, 23, -3), Color3.fromRGB(60, 60, 70))
	local hook = Kit.box(m, "Hook", Vector3.new(4, 1, 6), cf * CFrame.new(0, 16, -18), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	hook:AddTag("TE_Slide")
	hook:SetAttribute("SlideOffset", Vector3.new(0, 8, 0))
	hook:SetAttribute("SlideSpeed", 0.08)
	hook:SetAttribute("SlideMode", "pingpong")
	return m
end

local function pond(parent, cf, r)
	Kit.cylinder(parent, "PondEdge", 0.8, r * 2 + 3, cf * CFrame.new(0, 0.4, 0), Color3.fromRGB(150, 140, 120), Enum.Material.Slate)
	Kit.cylinder(parent, "Pond", 0.85, r * 2, cf * CFrame.new(0, 0.45, 0), Color3.fromRGB(70, 160, 220), Enum.Material.Glass, { Transparency = 0.15 })
	for i = 0, 2 do
		local a = math.rad(i * 120 + 20)
		Kit.cylinder(parent, "LilyPad", 0.1, 2.2, cf * CFrame.new(math.cos(a) * r * 0.5, 0.95, math.sin(a) * r * 0.5), Color3.fromRGB(90, 180, 80))
	end
end

local function beach(parent, sx, sz)
	local RX = WorldBuilder.RingX
	local cx = sx * (RX + 50)
	Kit.box(parent, "Sand", Vector3.new(80, 0.6, 360), CFrame.new(cx, 0.2, sz * 120), Color3.fromRGB(240, 220, 160), Enum.Material.Sand)
	Kit.box(parent, "Sea", Vector3.new(220, 0.6, 520), CFrame.new(cx + sx * 150, 0.05, 0), Color3.fromRGB(60, 170, 230), Enum.Material.Glass, { Transparency = 0.1, CanCollide = true })
	for i = 0, 4 do
		local z = sz * (40 + i * 55)
		local u = Kit.model(parent, "BeachUmbrella")
		local c = CFrame.new(cx + sx * 10, 0.5, z)
		Kit.cylinder(u, "Pole", 7, 0.3, c * CFrame.new(0, 3.5, 0), WHITE)
		Kit.cylinder(u, "Top", 0.5, 8, c * CFrame.new(0, 7, 0), (i % 2 == 0) and Color3.fromRGB(255, 100, 90) or Color3.fromRGB(60, 190, 210), Enum.Material.Fabric)
		Kit.box(u, "Towel", Vector3.new(3, 0.1, 6), c * CFrame.new(2, 0.35, 0), Color3.fromRGB(255, 220, 90), Enum.Material.Fabric)
		Kit.tree(parent, CFrame.new(cx - sx * 22, 0.5, z + 20), "palm")
	end
end

local function buildNeighborhood(map, q, hoodIndex)
	local pal = Palettes.Neighborhoods[hoodIndex]
	local hood = Kit.model(map, "Barrio_" .. pal.id)
	local sx, sz = q.sx, q.sz
	local RX, RZ = WorldBuilder.RingX, WorldBuilder.RingZ

	-- Suelo del barrio
	Kit.box(hood, "HoodGround", Vector3.new(RX - 14, 0.2, RZ - 24), CFrame.new(sx * (14 + (RX - 14) / 2), 0.05, sz * (14 + (RZ - 24) / 2 - 2)), pal.ground, pal.groundMaterial, { CastShadow = false })

	-- Arco de entrada del barrio sobre la calle lateral
	local archCF = CFrame.new(sx * 175, 0, sz * 22)
	for _, dx in ipairs({ -10, 10 }) do
		Kit.box(hood, "ArchPillar", Vector3.new(2, 14, 2), archCF * CFrame.new(dx, 7, 0), pal.trim)
	end
	local archSign = Kit.box(hood, "ArchSign", Vector3.new(22, 4, 1), archCF * CFrame.new(0, 15, 0), pal.accent)
	Kit.surfaceText(archSign, pal.name, Enum.NormalId.Front, pal.accent, WHITE)
	Kit.surfaceText(archSign, pal.name, Enum.NormalId.Back, pal.accent, WHITE)

	-- Farolas y arboles a lo largo de las calles
	for i = 0, 6 do
		local x = sx * (40 + i * 44)
		Kit.lamp(hood, CFrame.lookAt(Vector3.new(x, 0.2, sz * 18), Vector3.new(x, 0.2, 0)), nil, pal.lamp)
		Kit.tree(hood, CFrame.new(x + sx * 20, 0.2, sz * 21), pal.tree, pal.treeColor)
	end
	for i = 0, 3 do
		local z = sz * (40 + i * 40)
		Kit.lamp(hood, CFrame.lookAt(Vector3.new(sx * 18, 0.2, z), Vector3.new(0, 0.2, z)), nil, pal.lamp)
		Kit.tree(hood, CFrame.new(sx * 30, 0.2, z + sz * 10), pal.tree, pal.treeColor)
	end

	-- Tiendas decorativas mas alla del anillo exterior
	for i = 0, 3 do
		local x = sx * (50 + i * 70)
		local shopInfo = SHOPS[(hoodIndex - 1) * 4 + i + 1]
		local cf = CFrame.lookAt(Vector3.new(x, 0.2, sz * (RZ + 22)), Vector3.new(x, 0.2, 0))
		shop(hood, cf, pal, shopInfo[1], shopInfo[2], 2 + (i % 3))
		Kit.tree(hood, CFrame.new(x + sx * 35, 0.2, sz * (RZ + 20)), pal.tree, pal.treeColor)
		Kit.lamp(hood, CFrame.lookAt(Vector3.new(x + sx * 12, 0.2, sz * (RZ + 13)), Vector3.new(x + sx * 12, 0.2, 0)), nil, pal.lamp)
	end
	-- Acera exterior
	Kit.box(hood, "OuterSidewalk", Vector3.new(RX, 0.5, 6), CFrame.new(sx * RX / 2, 0.25, sz * (RZ + 13)), pal.path, pal.pathMaterial)

	-- Elementos tematicos
	if pal.id == "pastel" then
		for i = 0, 5 do
			Kit.tree(hood, CFrame.new(sx * (360 + (i % 2) * 15), 0.2, sz * (30 + i * 28)), "blossom", pal.treeColor)
		end
		Kit.flowerBed(hood, CFrame.new(sx * 175, 0.2, sz * 172), 14, 4)
	elseif pal.id == "green" then
		pond(hood, CFrame.new(sx * 370, 0.2, sz * 80), 16)
		for i = 0, 8 do
			Kit.tree(hood, CFrame.new(sx * (355 + (i % 3) * 14), 0.2, sz * (10 + i * 20)), "pine", pal.treeColor)
		end
		Kit.fence(hood, Vector3.new(sx * 343, 0.2, sz * 5), Vector3.new(sx * 343, 0.2, sz * 175), pal.fence)
	elseif pal.id == "industrial" then
		containers(hood, CFrame.new(sx * 350, 0.2, sz * 40) * CFrame.Angles(0, math.rad(90), 0))
		containers(hood, CFrame.new(sx * 350, 0.2, sz * 110) * CFrame.Angles(0, math.rad(90), 0))
		portCrane(hood, CFrame.new(sx * 385, 0.2, sz * 75) * CFrame.Angles(0, math.rad(sx > 0 and -90 or 90), 0))
		Kit.box(hood, "Dock", Vector3.new(60, 1, 200), CFrame.new(sx * 380, 0.3, sz * 90), Color3.fromRGB(150, 150, 155), Enum.Material.Concrete)
	elseif pal.id == "coast" then
		beach(hood, sx, sz)
	end
	return hood, pal
end

------------------------------------------------------------------------------
-- AFUERAS: arboledas, colinas y casitas para que el horizonte no quede vacio
------------------------------------------------------------------------------

local function house(parent, cf, wall, roof)
	local m = Kit.model(parent, "House")
	Kit.box(m, "Wall", Vector3.new(12, 8, 10), cf * CFrame.new(0, 4, 0), wall)
	Kit.wedge(m, "Roof", Vector3.new(13, 4, 5.5), cf * CFrame.new(0, 10, -2.75), roof)
	Kit.wedge(m, "Roof", Vector3.new(13, 4, 5.5), cf * CFrame.new(0, 10, 2.75) * CFrame.Angles(0, math.rad(180), 0), roof)
	Kit.box(m, "Door", Vector3.new(2.6, 4.6, 0.3), cf * CFrame.new(0, 2.3, -5.1), Color3.fromRGB(120, 80, 55), Enum.Material.Wood)
	Kit.windows(m, cf * CFrame.new(0, 5, -5.1), 10, 3, 1, 2, Color3.fromRGB(170, 220, 255), WHITE)
	return m
end

local function buildOutskirts(map)
	local out = Kit.model(map, "Outskirts")
	local rng = Random.new(2024)
	local styles = { "round", "pine", "round", "blossom" }
	local RX, RZ = WorldBuilder.RingX, WorldBuilder.RingZ
	-- Arboledas al norte y al sur (detras de las tiendas)
	for _, sz in ipairs({ -1, 1 }) do
		for i = 0, 40 do
			local x = -470 + i * 23 + rng:NextNumber(-6, 6)
			local z = sz * (RZ + 78 + rng:NextNumber(0, 80))
			local inCoast = x > RX + 5
			if not inCoast then
				local style = styles[rng:NextInteger(1, #styles)]
				Kit.tree(out, CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), style)
			end
		end
		-- Casitas
		for i = 0, 6 do
			local x = -300 + i * 95
			if x < RX - 20 then
				local z = sz * (RZ + 58)
				local wall = Color3.fromHSV(rng:NextNumber(0, 1), 0.25, 0.95)
				local roof = Color3.fromHSV(rng:NextNumber(0, 1), 0.55, 0.7)
				house(out, CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0)), wall, roof)
			end
		end
	end
	-- Colinas en el horizonte oeste
	for i = 0, 6 do
		local z = -280 + i * 95
		local d = 70 + rng:NextNumber(0, 40)
		Kit.ball(out, "Hill", d, CFrame.new(-500 - rng:NextNumber(0, 30), -d * 0.28, z), Color3.fromRGB(95, 160, 85):Lerp(Color3.fromRGB(70, 130, 70), rng:NextNumber(0, 1)), Enum.Material.Grass)
	end
	for i = 0, 5 do
		local x = -420 + i * 150
		local d = 60 + rng:NextNumber(0, 40)
		if x < RX then
			Kit.ball(out, "Hill", d, CFrame.new(x, -d * 0.3, -360 - rng:NextNumber(0, 20)), Color3.fromRGB(100, 165, 90), Enum.Material.Grass)
			Kit.ball(out, "Hill", d, CFrame.new(x + 60, -d * 0.3, 360 + rng:NextNumber(0, 20)), Color3.fromRGB(100, 165, 90), Enum.Material.Grass)
		end
	end
	return out
end

------------------------------------------------------------------------------
-- VEHICULOS DECORATIVOS (el cliente los mueve por el anillo)
------------------------------------------------------------------------------

local function buildVehicles(map)
	local folder = Instance.new("Folder")
	folder.Name = "Vehicles"
	folder:SetAttribute("RingX", WorldBuilder.RingX)
	folder:SetAttribute("RingZ", WorldBuilder.RingZ)
	folder.Parent = map
	local colors = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(80, 160, 255),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(120, 220, 120),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(190, 120, 255),
		Color3.fromRGB(255, 150, 60),
		Color3.fromRGB(60, 200, 200),
	}
	local kinds = { "car", "car", "van", "car", "truck", "car", "van", "car", "car", "truck", "car", "van" }
	for i = 1, 12 do
		local car = Kit.car(folder, CFrame.new(0, 0.3, 0), colors[(i - 1) % #colors + 1], kinds[i])
		car:AddTag("TE_Car")
		car:SetAttribute("Phase", (i - 1) / 12 + (i % 2) * 0.03)
		car:SetAttribute("Lane", i % 2 == 0 and 1 or -1)
		car:SetAttribute("Speed", 24 + (i % 4) * 4)
	end
	-- Autobus aparcado en la plaza
	local bus = Kit.model(map, "Bus")
	local bc = CFrame.new(64, 0.3, 30) * CFrame.Angles(0, 0, 0)
	Kit.box(bus, "Body", Vector3.new(6, 6, 22), bc * CFrame.new(0, 4, 0), Color3.fromRGB(255, 200, 40))
	Kit.box(bus, "Windows", Vector3.new(6.1, 2, 20), bc * CFrame.new(0, 5, 0), Color3.fromRGB(150, 200, 240), Enum.Material.Glass, { Transparency = 0.2 })
	local busSign = Kit.box(bus, "Sign", Vector3.new(5, 1, 0.2), bc * CFrame.new(0, 6.5, -11.1), Color3.fromRGB(20, 20, 20))
	Kit.surfaceText(busSign, "PLAZA ⭐", Enum.NormalId.Front, Color3.fromRGB(20, 20, 20), Color3.fromRGB(255, 160, 40))
	for _, z in ipairs({ -7, 7 }) do
		for _, x in ipairs({ -3, 3 }) do
			Kit.cylinderX(bus, "Wheel", 1, 2.6, bc * CFrame.new(x, 1.3, z), Color3.fromRGB(30, 30, 35))
		end
	end
end

------------------------------------------------------------------------------

function WorldBuilder.build()
	local existing = workspace:FindFirstChild("TinyEmpireMap")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "TinyEmpireMap"

	lighting()

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	Kit.box(map, "Ground", Vector3.new(1100, 4, 800), CFrame.new(0, -2, 0), Color3.fromRGB(120, 190, 100), Enum.Material.Grass)

	buildRoads(map)
	buildPlaza(map)

	local plots = {}
	for qi, q in ipairs(QUADRANTS) do
		local _, pal = buildNeighborhood(map, q, q.hood)
		for k, px in ipairs({ 100, 250 }) do
			local center = Vector3.new(q.sx * px, 0.2, q.sz * 105)
			local cf = CFrame.lookAt(center, center + Vector3.new(0, 0, -q.sz))
			table.insert(plots, {
				index = (qi - 1) * 2 + k,
				cframe = cf,
				neighborhood = pal,
				hoodIndex = q.hood,
			})
		end
	end

	buildVehicles(map)
	buildOutskirts(map)
	Details.crossings(map, WorldBuilder.RingX, WorldBuilder.RingZ)
	Details.streetFurniture(map)
	Details.pedestrians(map)
	Details.clouds(map)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.6, -44)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = map
	local oldSpawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if oldSpawn and oldSpawn ~= spawn then
		oldSpawn:Destroy()
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map

	map.Parent = workspace
	return map, plots
end

return WorldBuilder
