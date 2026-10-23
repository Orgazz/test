--!nonstrict
-- Estructura fisica de una parcela: base, zonas, entrada, botones y extras.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Buildings = require(script.Parent.Buildings)
local Config = require(ReplicatedStorage.TinyEmpireShared.Config)

local PlotBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local SIZE = 120

-- Posicion local (x, z) y tamano de cada solar
PlotBuilder.Slots = {
	{ x = -39, z = -28, size = 20, padZ = -42.5 },
	{ x = -13, z = -28, size = 20, padZ = -42.5 },
	{ x = 13, z = -28, size = 20, padZ = -42.5 },
	{ x = 39, z = -28, size = 20, padZ = -42.5 },
	{ x = -34, z = 6, size = 24, padZ = -11.5 },
	{ x = 0, z = 6, size = 24, padZ = -11.5 },
	{ x = 34, z = 6, size = 24, padZ = -11.5 },
	{ x = -36, z = 40, size = 26, padZ = 22.5 },
	{ x = 0, z = 40, size = 26, padZ = 22.5 },
	{ x = 36, z = 40, size = 26, padZ = 22.5 },
}

-- Zonas: rango Z local
PlotBuilder.Zones = {
	{ z1 = -60, z2 = -17 },
	{ z1 = -17, z2 = 19.5 },
	{ z1 = 19.5, z2 = 60 },
}

PlotBuilder.SpawnOffset = CFrame.new(0, 3, -52) * CFrame.Angles(0, math.pi, 0)

function PlotBuilder.local_(plotCF, x, y, z)
	return plotCF * CFrame.new(x, y, z)
end

local function zoneCF(plotCF, zone)
	local z = PlotBuilder.Zones[zone]
	return plotCF * CFrame.new(0, 0, (z.z1 + z.z2) / 2), z.z2 - z.z1
end

-- Crea un boton de compra (pad). Devuelve el modelo y la parte pisable.
local function makePad(parent, name, cf)
	local m = Kit.model(parent, name)
	Kit.cylinder(m, "Ring", 0.4, 6.6, cf * CFrame.new(0, 0.2, 0), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)
	local button = Kit.cylinder(m, "Button", 0.5, 5.4, cf * CFrame.new(0, 0.45, 0), Color3.fromRGB(80, 230, 110), Enum.Material.Neon)
	button.CanCollide = false
	local touch = Kit.box(m, "Touch", Vector3.new(5, 3, 5), cf * CFrame.new(0, 1.6, 0), WHITE, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
	})
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(230, 92)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	bb.Adornee = button
	bb.Parent = button
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
	frame.BackgroundTransparency = 0.15
	frame.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(80, 230, 110)
	stroke.Parent = frame
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.06)
	title.Size = UDim2.fromScale(0.9, 0.45)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = WHITE
	title.Text = ""
	title.Parent = frame
	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromScale(0.05, 0.52)
	price.Size = UDim2.fromScale(0.9, 0.42)
	price.Font = Enum.Font.FredokaOne
	price.TextScaled = true
	price.TextColor3 = Color3.fromRGB(120, 255, 140)
	price.Text = ""
	price.Parent = frame
	m:SetAttribute("Visible", true)
	return m, touch, button
end

-- Muestra / oculta un pad sin destruirlo
function PlotBuilder.setPadVisible(pad, visible)
	if pad:GetAttribute("Visible") == visible then
		return
	end
	pad:SetAttribute("Visible", visible)
	for _, d in ipairs(pad:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Touch" then
			d.Transparency = visible and 0 or 1
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") then
			d.Enabled = visible
		end
	end
	local touch = pad:FindFirstChild("Touch")
	if touch then
		touch.CanTouch = visible
	end
end

function PlotBuilder.setPadStyle(pad, title, priceText, color)
	local button = pad:FindFirstChild("Button")
	if not button then
		return
	end
	if button.Color ~= color then
		button.Color = color
	end
	local card = button.Info.Card
	if card.Title.Text ~= title then
		card.Title.Text = title
	end
	if card.Price.Text ~= priceText then
		card.Price.Text = priceText
	end
	card.Price.TextColor3 = color:Lerp(WHITE, 0.35)
	card.Stroke.Color = color
end

-- Estructura base de la parcela (se construye una vez al iniciar el servidor)
function PlotBuilder.create(parent, def)
	local cf = def.cframe
	local pal = def.neighborhood
	local plot = Kit.model(parent, "Plot" .. def.index)
	plot:SetAttribute("Index", def.index)
	plot:SetAttribute("Owner", 0)
	plot:SetAttribute("Neighborhood", pal.name)
	plot.WorldPivot = cf

	local static = Kit.model(plot, "Static")
	Kit.box(static, "Base", Vector3.new(SIZE, 1, SIZE), cf * CFrame.new(0, -0.5, 0), pal.ground:Lerp(Color3.new(1, 1, 1), 0.08), pal.groundMaterial)
	-- Bordillo con hueco de entrada
	local curb = pal.curb
	Kit.box(static, "CurbBack", Vector3.new(SIZE, 1, 1), cf * CFrame.new(0, 0.5, SIZE / 2 - 0.5), curb, Enum.Material.Concrete)
	Kit.box(static, "CurbL", Vector3.new(1, 1, SIZE), cf * CFrame.new(-SIZE / 2 + 0.5, 0.5, 0), curb, Enum.Material.Concrete)
	Kit.box(static, "CurbR", Vector3.new(1, 1, SIZE), cf * CFrame.new(SIZE / 2 - 0.5, 0.5, 0), curb, Enum.Material.Concrete)
	Kit.box(static, "CurbFL", Vector3.new(SIZE / 2 - 9, 1, 1), cf * CFrame.new(-(SIZE / 4 + 4.5), 0.5, -SIZE / 2 + 0.5), curb, Enum.Material.Concrete)
	Kit.box(static, "CurbFR", Vector3.new(SIZE / 2 - 9, 1, 1), cf * CFrame.new(SIZE / 4 + 4.5, 0.5, -SIZE / 2 + 0.5), curb, Enum.Material.Concrete)
	-- Calzadas interiores
	Kit.box(static, "FrontWalk", Vector3.new(SIZE - 2, 0.1, 14), cf * CFrame.new(0, 0.05, -52), pal.path, pal.pathMaterial)
	-- Entrada
	local gate = Kit.model(static, "Gate")
	for _, x in ipairs({ -9.5, 9.5 }) do
		Kit.box(gate, "Pillar", Vector3.new(2, 14, 2), cf * CFrame.new(x, 7, -59), pal.trim)
		Kit.box(gate, "Cap", Vector3.new(2.6, 0.8, 2.6), cf * CFrame.new(x, 14.4, -59), pal.accent)
	end
	local sign = Kit.box(gate, "OwnerSign", Vector3.new(20, 4, 0.8), cf * CFrame.new(0, 12.5, -59), pal.accent)
	local _, label = Kit.surfaceText(sign, "🏗️ PARCELA LIBRE", Enum.NormalId.Front, pal.accent, WHITE)
	label.Name = "OwnerLabel"
	local _, backLabel = Kit.surfaceText(sign, "🏗️ PARCELA LIBRE", Enum.NormalId.Back, pal.accent, WHITE)
	backLabel.Name = "OwnerLabel"
	local glow = Kit.box(gate, "Glow", Vector3.new(20.4, 0.3, 1), cf * CFrame.new(0, 10.3, -59), pal.lamp, Enum.Material.Neon)
	Kit.light(glow, pal.lamp, 20, 1.5)

	-- Panel de ingresos junto a la entrada
	local stats = Kit.box(gate, "StatsBoard", Vector3.new(8, 4.5, 0.5), cf * CFrame.new(-17, 4.5, -58), Color3.fromRGB(35, 40, 55))
	Kit.box(gate, "StatsLeg", Vector3.new(0.5, 2.5, 0.5), cf * CFrame.new(-17, 1.25, -58), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	local _, statsLabel = Kit.surfaceText(stats, "$0/s", Enum.NormalId.Front, Color3.fromRGB(35, 40, 55), Color3.fromRGB(120, 255, 140))
	statsLabel.Name = "StatsLabel"

	-- Punto de aparicion
	local spawnPad = Kit.cylinder(static, "SpawnPad", 0.3, 9, cf * CFrame.new(0, 0.15, -52), pal.accent, Enum.Material.SmoothPlastic)
	Kit.cylinder(static, "SpawnInner", 0.32, 6, cf * CFrame.new(0, 0.16, -52), WHITE, Enum.Material.SmoothPlastic)
	spawnPad.CanCollide = true

	-- Cartel flotante visible desde lejos
	local beacon = Kit.box(static, "Beacon", Vector3.new(1, 1, 1), cf * CFrame.new(0, 34, 0), WHITE, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	local bb, bbLabel = Kit.billboard(beacon, "Parcela libre", UDim2.fromOffset(320, 60), Vector3.new(0, 0, 0), WHITE, 600)
	bb.Name = "OwnerBillboard"
	bbLabel.Name = "OwnerLabel"

	-- Seto trasero y laterales, buzon con el nombre del dueno
	local hedgeColor = Color3.fromRGB(60, 140, 70)
	for i = 0, 4 do
		Kit.box(static, "Hedge", Vector3.new(18, 2.4, 2), cf * CFrame.new(-44 + i * 22, 1.2, 57.5), hedgeColor, Enum.Material.Grass)
	end
	for _, x in ipairs({ -57.5, 57.5 }) do
		Kit.box(static, "Hedge", Vector3.new(2, 2.4, 16), cf * CFrame.new(x, 1.2, 46), hedgeColor, Enum.Material.Grass)
	end
	local mail = cf * CFrame.new(-25, 0, -58)
	Kit.box(static, "MailPost", Vector3.new(0.4, 3, 0.4), mail * CFrame.new(0, 1.5, 0), Color3.fromRGB(110, 80, 60), Enum.Material.Wood)
	Kit.box(static, "Mailbox", Vector3.new(1.4, 1.2, 2), mail * CFrame.new(0, 3.4, 0), pal.accent, Enum.Material.Metal)
	Kit.box(static, "MailFlag", Vector3.new(0.15, 0.9, 0.3), mail * CFrame.new(0.78, 3.7, 0.4), Color3.fromRGB(230, 50, 50))

	-- Arboles de la esquina trasera (decoracion fija)
	Kit.tree(static, cf * CFrame.new(-55, 0, 56), pal.tree, pal.treeColor)
	Kit.tree(static, cf * CFrame.new(55, 0, 56), pal.tree, pal.treeColor)
	Kit.lamp(static, cf * CFrame.new(-56, 0, -56) * CFrame.Angles(0, math.rad(180), 0), nil, pal.lamp)
	Kit.lamp(static, cf * CFrame.new(56, 0, -56) * CFrame.Angles(0, math.rad(180), 0), nil, pal.lamp)

	-- Carpetas dinamicas
	local zones = Kit.model(plot, "Zones")
	local buildings = Kit.model(plot, "Buildings")
	local pads = Kit.model(plot, "Pads")
	local extras = Kit.model(plot, "Extras")
	local _ = { zones, buildings, extras }

	-- Pads de negocios
	local padMap = {}
	for _, b in ipairs(Config.Businesses) do
		local slot = PlotBuilder.Slots[b.slot]
		local pad, touch = makePad(pads, "Pad_" .. b.id, cf * CFrame.new(slot.x, 0, slot.padZ))
		pad:SetAttribute("Kind", "business")
		pad:SetAttribute("Target", b.id)
		padMap[b.id] = { model = pad, touch = touch }
	end
	-- Pads de expansion
	for i, exp in ipairs(Config.Expansions) do
		local zone = PlotBuilder.Zones[i + 1]
		local pad, touch = makePad(pads, "Pad_exp" .. i, cf * CFrame.new(0, 0, zone.z1 + 3.5))
		pad:SetAttribute("Kind", "expansion")
		pad:SetAttribute("Target", i)
		padMap["exp" .. i] = { model = pad, touch = touch }
		local _ = exp
	end

	return plot, padMap
end

-- Dibuja el estado de las zonas (bloqueada = obra; desbloqueada = cesped)
function PlotBuilder.buildZones(plot, def, expansions)
	local cf = def.cframe
	local pal = def.neighborhood
	local zones = plot.Zones
	zones:ClearAllChildren()
	for zone = 2, 3 do
		local zcf, depth = zoneCF(cf, zone)
		local z = PlotBuilder.Zones[zone]
		local unlocked = zone <= expansions + 1
		if unlocked then
			-- Caminos delante de los pads
			local padZ = (zone == 2) and -11.5 or 22.5
			Kit.box(zones, "PadWalk", Vector3.new(SIZE - 2, 0.1, 6), cf * CFrame.new(0, 0.05, padZ), pal.path, pal.pathMaterial)
		else
			Kit.box(zones, "Dirt", Vector3.new(SIZE - 2, 0.12, depth), zcf * CFrame.new(0, 0.06, 0), Color3.fromRGB(150, 115, 80), Enum.Material.Ground)
			-- Valla de obra
			local fz = z.z1 + 1
			Kit.fence(zones, (cf * CFrame.new(-58, 0, fz)).Position, (cf * CFrame.new(-6, 0, fz)).Position, Color3.fromRGB(255, 190, 60), 2.5)
			Kit.fence(zones, (cf * CFrame.new(6, 0, fz)).Position, (cf * CFrame.new(58, 0, fz)).Position, Color3.fromRGB(255, 190, 60), 2.5)
			for i = -2, 2 do
				if i ~= 0 then
					local cone = Kit.model(zones, "Cone")
					local c = cf * CFrame.new(i * 18, 0, z.z1 + 8)
					Kit.box(cone, "Base", Vector3.new(1.6, 0.3, 1.6), c * CFrame.new(0, 0.15, 0), Color3.fromRGB(255, 120, 30))
					Kit.cylinder(cone, "Cone", 2, 0.9, c * CFrame.new(0, 1.2, 0), Color3.fromRGB(255, 120, 30))
					Kit.cylinder(cone, "Stripe", 0.4, 1, c * CFrame.new(0, 1.3, 0), WHITE)
				end
			end
			local exp = Config.Expansions[zone - 1]
			local sign = Kit.sign(zones, "ForSale", Vector3.new(14, 5, 0.5), zcf * CFrame.new(0, 7, 0), "🚧 " .. exp.name .. "\n¡Expándete aquí!", Color3.fromRGB(255, 200, 60), Color3.fromRGB(40, 35, 30), Color3.fromRGB(100, 80, 60))
			Kit.box(zones, "SignLeg", Vector3.new(0.6, 4.5, 0.6), zcf * CFrame.new(-5, 2.25, 0), Color3.fromRGB(100, 80, 60), Enum.Material.Wood)
			Kit.box(zones, "SignLeg", Vector3.new(0.6, 4.5, 0.6), zcf * CFrame.new(5, 2.25, 0), Color3.fromRGB(100, 80, 60), Enum.Material.Wood)
			local _ = sign
		end
	end
end

-- Construye un negocio en su solar
function PlotBuilder.buildBusiness(plot, def, id, level, palette)
	local b = Config.BusinessById[id]
	local slot = PlotBuilder.Slots[b.slot]
	local existing = plot.Buildings:FindFirstChild(id)
	if existing then
		existing:Destroy()
	end
	local cf = def.cframe * CFrame.new(slot.x, 0, slot.z)
	local m = Buildings.build(plot.Buildings, id, cf, level, palette, slot.size)
	return m
end

-- Elementos extra: mejoras visuales y decoracion premium
function PlotBuilder.buildExtras(plot, def, data, palette, hasDecor)
	local cf = def.cframe
	local extras = plot.Extras
	extras:ClearAllChildren()
	local up = data.upgrades or {}

	if up["u_vans"] then
		for i, x in ipairs({ -44, -34 }) do
			local van = Kit.car(extras, cf * CFrame.new(x, 0, -52), (i == 1) and palette.accent or palette.accent2, "van")
			van.Name = "DeliveryVan"
			local logo = Kit.box(van, "Logo", Vector3.new(0.2, 2, 4), cf * CFrame.new(x - 2.4, 3, -52), WHITE)
			Kit.surfaceText(logo, "TINY EXPRESS", Enum.NormalId.Left, WHITE, palette.accent)
		end
	end
	if up["u_solar"] then
		for i = 0, 6 do
			local z = -15 + i * 10
			local pcf = cf * CFrame.new(53, 0, z)
			Kit.box(extras, "SolarLeg", Vector3.new(0.4, 2.4, 0.4), pcf * CFrame.new(0, 1.2, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
			Kit.box(extras, "SolarPanel", Vector3.new(7, 0.3, 8), pcf * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(40, 70, 140), Enum.Material.Glass, { Reflectance = 0.3 })
		end
	end
	if up["u_heli"] then
		local hcf = cf * CFrame.new(-52, 0, 6)
		Kit.cylinder(extras, "Helipad", 0.4, 10, hcf * CFrame.new(0, 0.2, 0), Color3.fromRGB(50, 55, 65))
		local mark = Kit.box(extras, "HMark", Vector3.new(4, 0.05, 4), hcf * CFrame.new(0, 0.43, 0), Color3.fromRGB(50, 55, 65))
		Kit.surfaceText(mark, "H", Enum.NormalId.Top, nil, Color3.fromRGB(255, 220, 60))
		local heli = Kit.model(extras, "Helicopter")
		Kit.ball(heli, "Cabin", 4.4, hcf * CFrame.new(0, 3, 0), Color3.fromRGB(230, 60, 60))
		Kit.box(heli, "Tail", Vector3.new(0.8, 0.8, 6), hcf * CFrame.new(0, 3.3, 4.5), Color3.fromRGB(230, 60, 60))
		Kit.box(heli, "SkidL", Vector3.new(0.3, 0.3, 5), hcf * CFrame.new(-1.6, 0.9, 0), Color3.fromRGB(40, 40, 45))
		Kit.box(heli, "SkidR", Vector3.new(0.3, 0.3, 5), hcf * CFrame.new(1.6, 0.9, 0), Color3.fromRGB(40, 40, 45))
		local rotor = Kit.model(heli, "Rotor")
		local rc = hcf * CFrame.new(0, 5.5, 0)
		Kit.box(rotor, "Blade", Vector3.new(11, 0.2, 0.7), rc, Color3.fromRGB(40, 40, 45))
		Kit.box(rotor, "Blade", Vector3.new(0.7, 0.2, 11), rc, Color3.fromRGB(40, 40, 45))
		rotor.WorldPivot = rc
		rotor:AddTag("TE_Spin")
		rotor:SetAttribute("SpinSpeed", 600)
		rotor:SetAttribute("SpinAxis", "Y")
	end
	if up["u_statue"] then
		local scf = cf * CFrame.new(40, 0, -52)
		local gold = Color3.fromRGB(255, 200, 60)
		Kit.box(extras, "Plinth", Vector3.new(5, 3, 5), scf * CFrame.new(0, 1.5, 0), Color3.fromRGB(230, 230, 235), Enum.Material.Marble)
		local st = Kit.model(extras, "Statue")
		Kit.box(st, "Legs", Vector3.new(2, 3, 1.2), scf * CFrame.new(0, 4.5, 0), gold, Enum.Material.Foil)
		Kit.box(st, "Torso", Vector3.new(2.6, 3, 1.4), scf * CFrame.new(0, 7.5, 0), gold, Enum.Material.Foil)
		Kit.ball(st, "Head", 1.8, scf * CFrame.new(0, 9.9, 0), gold, Enum.Material.Foil)
		Kit.box(st, "Arm", Vector3.new(0.8, 3.2, 0.8), scf * CFrame.new(1.7, 9, 0) * CFrame.Angles(0, 0, math.rad(-30)), gold, Enum.Material.Foil)
		Kit.box(st, "TopHat", Vector3.new(1.4, 1.2, 1.4), scf * CFrame.new(0, 11.2, 0), Color3.fromRGB(30, 30, 35))
		Kit.sparkles(st.Torso, gold, 6)
	end

	if hasDecor and (data.settings == nil or data.settings.decor ~= false) then
		local deco = Kit.model(extras, "PremiumDecor")
		-- Arco de neon en la entrada
		local arc = Kit.model(deco, "NeonArch")
		for i = 0, 8 do
			local a = math.rad(i * 22.5)
			local p = cf * CFrame.new(math.cos(a) * 12, 3 + math.sin(a) * 12, -60.5)
			local seg = Kit.box(arc, "Seg", Vector3.new(1.2, 4.6, 0.8), p * CFrame.Angles(0, 0, a), (i % 2 == 0) and Color3.fromRGB(255, 80, 200) or Color3.fromRGB(80, 220, 255), Enum.Material.Neon, { CanCollide = false })
			seg:AddTag("TE_Pulse")
			seg:SetAttribute("PulseSpeed", 1 + i * 0.1)
		end
		-- Fuente premium
		local fcf = cf * CFrame.new(20, 0, -52)
		Kit.cylinder(deco, "Rim", 1.6, 9, fcf * CFrame.new(0, 0.8, 0), Color3.fromRGB(255, 215, 120), Enum.Material.Marble)
		Kit.cylinder(deco, "Water", 0.3, 7.6, fcf * CFrame.new(0, 1.5, 0), Color3.fromRGB(90, 190, 255), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
		local spout = Kit.ball(deco, "Spout", 1.4, fcf * CFrame.new(0, 3.5, 0), Color3.fromRGB(120, 220, 255), Enum.Material.Neon, { CanCollide = false })
		Kit.cylinder(deco, "Column", 2.5, 1, fcf * CFrame.new(0, 2.2, 0), Color3.fromRGB(255, 215, 120), Enum.Material.Marble)
		Kit.sparkles(spout, Color3.fromRGB(160, 230, 255), 25)
		-- Estatuas de leon junto a la entrada
		for _, x in ipairs({ -13, 13 }) do
			local lcf = cf * CFrame.new(x, 0, -57)
			Kit.box(deco, "Pedestal", Vector3.new(3, 2, 3), lcf * CFrame.new(0, 1, 0), Color3.fromRGB(240, 240, 245), Enum.Material.Marble)
			Kit.ball(deco, "LionBody", 2.4, lcf * CFrame.new(0, 3, 0.3), Color3.fromRGB(255, 200, 60), Enum.Material.Foil)
			Kit.ball(deco, "LionHead", 1.8, lcf * CFrame.new(0, 4.3, -0.6), Color3.fromRGB(255, 200, 60), Enum.Material.Foil)
		end
		-- Palmeras y jardines en las esquinas
		for _, x in ipairs({ -56, 56 }) do
			Kit.tree(deco, cf * CFrame.new(x, 0, -45), "palm")
			Kit.flowerBed(deco, cf * CFrame.new(x, 0, -33), 4, 12, { Color3.fromRGB(255, 80, 160), Color3.fromRGB(255, 210, 60), Color3.fromRGB(150, 110, 255) })
		end
		-- Alfombra roja
		Kit.box(deco, "RedCarpet", Vector3.new(6, 0.12, 14), cf * CFrame.new(0, 0.12, -53), Color3.fromRGB(200, 30, 50), Enum.Material.Fabric, { CanCollide = false })
	end
end

function PlotBuilder.setOwnerText(plot, text, color)
	local gate = plot.Static.Gate
	for _, d in ipairs(gate.OwnerSign:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "OwnerLabel" then
			d.Text = text
		end
	end
	local bb = plot.Static.Beacon.OwnerBillboard
	bb.OwnerLabel.Text = text
	bb.OwnerLabel.TextColor3 = color or WHITE
end

function PlotBuilder.setStatsText(plot, text)
	local label = plot.Static.Gate.StatsBoard:FindFirstChildWhichIsA("SurfaceGui").StatsLabel
	label.Text = text
end

return PlotBuilder
