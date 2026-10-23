--!nonstrict
-- Kit de construccion: piezas basicas para levantar el mundo por codigo.

local Kit = {}

local DEFAULTS = {
	Anchored = true,
	CanCollide = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Material = Enum.Material.SmoothPlastic,
	CastShadow = true,
}

function Kit.apply(inst, props)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	return inst
end

function Kit.part(parent, props, className)
	local p = Instance.new(className or "Part")
	for k, v in pairs(DEFAULTS) do
		p[k] = v
	end
	Kit.apply(p, props)
	p.Parent = parent
	return p
end

-- Caja: tamano, CFrame, color, material
function Kit.box(parent, name, size, cf, color, material, extra)
	local p = Kit.part(parent, {
		Name = name or "Part",
		Size = size,
		CFrame = cf,
		Color = color or Color3.new(1, 1, 1),
		Material = material or Enum.Material.SmoothPlastic,
	})
	Kit.apply(p, extra)
	return p
end

function Kit.wedge(parent, name, size, cf, color, material)
	return Kit.part(parent, {
		Name = name or "Wedge",
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, "WedgePart")
end

-- Cilindro vertical (el eje del cilindro de Roblox es X, se rota para ponerlo en Y)
function Kit.cylinder(parent, name, height, diameter, cf, color, material, extra)
	local p = Kit.part(parent, {
		Name = name or "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	Kit.apply(p, extra)
	return p
end

-- Cilindro horizontal a lo largo del eje X local
function Kit.cylinderX(parent, name, length, diameter, cf, color, material)
	return Kit.part(parent, {
		Name = name or "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Kit.ball(parent, name, diameter, cf, color, material, extra)
	local p = Kit.part(parent, {
		Name = name or "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	Kit.apply(p, extra)
	return p
end

function Kit.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.tag(inst, tag)
	inst:AddTag(tag)
	return inst
end

-- Luz que se enciende de noche (DayNightService busca la etiqueta TE_Lamp)
function Kit.light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.fromRGB(255, 220, 160)
	l.Range = range or 16
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Enabled = false
	l.Parent = part
	part:AddTag("TE_Lamp")
	return l
end

-- Texto en una cara de una pieza
function Kit.surfaceText(part, text, face, bg, fg, props)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or Color3.new(0, 0, 0)
	label.BackgroundTransparency = bg and 0 or 1
	label.TextColor3 = fg or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Transparency = 0.3
	stroke.Parent = label
	Kit.apply(label, props)
	return gui, label
end

-- Letrero: tablero con texto a ambos lados
function Kit.sign(parent, name, size, cf, text, bg, fg, frameColor)
	local board = Kit.box(parent, name or "Sign", size, cf, frameColor or Color3.fromRGB(60, 50, 45), Enum.Material.Wood)
	Kit.surfaceText(board, text, Enum.NormalId.Front, bg, fg)
	Kit.surfaceText(board, text, Enum.NormalId.Back, bg, fg)
	return board
end

function Kit.billboard(adornee, text, size, offset, color, maxDistance)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromOffset(200, 50)
	bb.StudsOffset = offset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDistance or 120
	bb.LightInfluence = 0
	bb.Adornee = adornee
	bb.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(25, 25, 35)
	stroke.Parent = label
	return bb, label
end

-- Ventanas en una fachada. `faceCF` mira hacia fuera (LookVector = normal)
function Kit.windows(parent, faceCF, width, height, rows, cols, color, frameColor)
	local wW = width / cols
	local wH = height / rows
	for r = 1, rows do
		for c = 1, cols do
			local x = -width / 2 + wW * (c - 0.5)
			local y = -height / 2 + wH * (r - 0.5)
			local cf = faceCF * CFrame.new(x, y, 0)
			local win = Kit.box(parent, "Window", Vector3.new(wW * 0.7, wH * 0.65, 0.3), cf, color or Color3.fromRGB(170, 220, 255), Enum.Material.Glass, {
				Transparency = 0.15,
				Reflectance = 0.2,
				CastShadow = false,
			})
			win:AddTag("TE_Window")
			if frameColor then
				Kit.box(parent, "Sill", Vector3.new(wW * 0.8, 0.25, 0.6), cf * CFrame.new(0, -wH * 0.35, 0.1), frameColor)
			end
		end
	end
end

-- Toldo de rayas
function Kit.awning(parent, cf, width, depth, colorA, colorB)
	local stripes = math.max(2, math.floor(width / 1.5))
	local sw = width / stripes
	for i = 1, stripes do
		local x = -width / 2 + sw * (i - 0.5)
		Kit.wedge(parent, "Awning", Vector3.new(sw, 1.2, depth), cf * CFrame.new(x, 0, 0), (i % 2 == 0) and colorA or colorB)
	end
end

-- Particulas de humo / chispas
function Kit.smoke(part, color, rate)
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/smoke_main.dds"
	p.Color = ColorSequence.new(color or Color3.fromRGB(230, 230, 235))
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(2, 3.5)
	p.Rate = rate or 4
	p.Speed = NumberRange.new(3, 5)
	p.SpreadAngle = Vector2.new(10, 10)
	p.EmissionDirection = Enum.NormalId.Top
	p.LightInfluence = 0.6
	p.Parent = part
	return p
end

function Kit.sparkles(part, color, rate)
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(color or Color3.fromRGB(255, 240, 150))
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	p.Lifetime = NumberRange.new(0.8, 1.4)
	p.Rate = rate or 6
	p.Speed = NumberRange.new(1, 3)
	p.SpreadAngle = Vector2.new(180, 180)
	p.LightEmission = 1
	p.Parent = part
	return p
end

------------------------------------------------------------------------------
-- DECORACION REUTILIZABLE
------------------------------------------------------------------------------

local TRUNK = Color3.fromRGB(110, 75, 50)

function Kit.tree(parent, cf, style, color)
	local m = Kit.model(parent, "Tree")
	if style == "pine" then
		Kit.cylinder(m, "Trunk", 4, 1.4, cf * CFrame.new(0, 2, 0), TRUNK, Enum.Material.Wood)
		local c = color or Color3.fromRGB(45, 125, 70)
		for i = 0, 3 do
			local s = 8.5 - i * 2
			Kit.box(m, "Leaves", Vector3.new(s, 3, s), cf * CFrame.new(0, 4.5 + i * 2.6, 0) * CFrame.Angles(0, math.rad(45 * i), 0), c:Lerp(Color3.new(0.2, 0.5, 0.3), i * 0.08), Enum.Material.Grass)
		end
	elseif style == "palm" then
		local h = 12
		for i = 0, 5 do
			Kit.cylinder(m, "Trunk", 2.2, 1.3 - i * 0.08, cf * CFrame.new(i * 0.25, 1.1 + i * 2, 0) * CFrame.Angles(0, 0, math.rad(-4)), Color3.fromRGB(160, 120, 75), Enum.Material.Wood)
		end
		local top = cf * CFrame.new(1.5, h, 0)
		for i = 0, 5 do
			local leaf = top * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0, -3.5) * CFrame.Angles(math.rad(-20), 0, 0)
			Kit.box(m, "Frond", Vector3.new(1.6, 0.4, 7), leaf, color or Color3.fromRGB(60, 170, 70), Enum.Material.Grass)
		end
		Kit.ball(m, "Coconut", 1.1, top * CFrame.new(0.5, -0.6, 0.3), Color3.fromRGB(110, 80, 40))
		Kit.ball(m, "Coconut", 1.1, top * CFrame.new(-0.4, -0.6, -0.4), Color3.fromRGB(110, 80, 40))
	elseif style == "blossom" then
		Kit.cylinder(m, "Trunk", 6, 1.3, cf * CFrame.new(0, 3, 0), Color3.fromRGB(95, 60, 55), Enum.Material.Wood)
		local c = color or Color3.fromRGB(255, 170, 200)
		Kit.ball(m, "Leaves", 8, cf * CFrame.new(0, 8, 0), c, Enum.Material.Grass)
		Kit.ball(m, "Leaves", 5.5, cf * CFrame.new(2.6, 7, 1), c:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Grass)
		Kit.ball(m, "Leaves", 5, cf * CFrame.new(-2.5, 7.5, -1.2), c:Lerp(Color3.new(1, 0.6, 0.8), 0.2), Enum.Material.Grass)
	else
		Kit.cylinder(m, "Trunk", 5, 1.3, cf * CFrame.new(0, 2.5, 0), TRUNK, Enum.Material.Wood)
		local c = color or Color3.fromRGB(80, 175, 80)
		Kit.ball(m, "Leaves", 7, cf * CFrame.new(0, 7, 0), c, Enum.Material.Grass)
		Kit.ball(m, "Leaves", 5, cf * CFrame.new(2.2, 6, 0.8), c:Lerp(Color3.new(0, 0.4, 0), 0.15), Enum.Material.Grass)
		Kit.ball(m, "Leaves", 4.5, cf * CFrame.new(-2, 6.2, -1), c:Lerp(Color3.new(1, 1, 0.5), 0.12), Enum.Material.Grass)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = d.Name == "Trunk"
		end
	end
	-- Balanceo suave con el viento (lo anima el cliente desde la base del tronco)
	m.WorldPivot = cf
	m:AddTag("TE_Sway")
	m:SetAttribute("SwayMode", "tilt")
	m:SetAttribute("SwayAngle", style == "palm" and 3.5 or 2)
	m:SetAttribute("SwaySpeed", 0.25 + (math.abs(cf.Position.X * 7 + cf.Position.Z * 13) % 10) / 60)
	return m
end

function Kit.lamp(parent, cf, poleColor, lightColor)
	local m = Kit.model(parent, "StreetLamp")
	poleColor = poleColor or Color3.fromRGB(45, 50, 60)
	Kit.cylinder(m, "Base", 0.6, 1.6, cf * CFrame.new(0, 0.3, 0), poleColor, Enum.Material.Metal)
	Kit.cylinder(m, "Pole", 11, 0.5, cf * CFrame.new(0, 5.8, 0), poleColor, Enum.Material.Metal)
	Kit.box(m, "Arm", Vector3.new(0.4, 0.4, 2.4), cf * CFrame.new(0, 11.2, -1), poleColor, Enum.Material.Metal)
	local bulb = Kit.box(m, "Bulb", Vector3.new(1.4, 0.6, 1.4), cf * CFrame.new(0, 10.9, -2), lightColor or Color3.fromRGB(255, 240, 200), Enum.Material.Neon, { CastShadow = false })
	Kit.light(bulb, lightColor or Color3.fromRGB(255, 220, 160), 24, 2)
	return m
end

function Kit.bench(parent, cf, color)
	local m = Kit.model(parent, "Bench")
	color = color or Color3.fromRGB(150, 100, 60)
	local metal = Color3.fromRGB(50, 50, 60)
	Kit.box(m, "Seat", Vector3.new(5, 0.4, 1.6), cf * CFrame.new(0, 1.6, 0), color, Enum.Material.Wood)
	Kit.box(m, "Back", Vector3.new(5, 1.4, 0.3), cf * CFrame.new(0, 2.6, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), color, Enum.Material.Wood)
	Kit.box(m, "Leg", Vector3.new(0.3, 1.5, 1.6), cf * CFrame.new(-2.2, 0.75, 0), metal, Enum.Material.Metal)
	Kit.box(m, "Leg", Vector3.new(0.3, 1.5, 1.6), cf * CFrame.new(2.2, 0.75, 0), metal, Enum.Material.Metal)
	local seat = Instance.new("Seat")
	seat.Name = "SitHere"
	seat.Size = Vector3.new(4, 0.3, 1.4)
	seat.CFrame = cf * CFrame.new(0, 1.85, 0)
	seat.Anchored = true
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Parent = m
	return m
end

function Kit.flowerBed(parent, cf, w, d, colors)
	local m = Kit.model(parent, "FlowerBed")
	Kit.box(m, "Border", Vector3.new(w, 0.8, d), cf * CFrame.new(0, 0.4, 0), Color3.fromRGB(150, 140, 130), Enum.Material.Brick)
	Kit.box(m, "Soil", Vector3.new(w - 0.6, 0.85, d - 0.6), cf * CFrame.new(0, 0.45, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Ground)
	colors = colors or { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(180, 120, 255) }
	local n = math.floor(w / 1.4)
	local rows = math.max(1, math.floor(d / 1.4))
	for i = 1, n do
		for j = 1, rows do
			local x = -w / 2 + (i - 0.5) * (w / n)
			local z = -d / 2 + (j - 0.5) * (d / rows)
			Kit.ball(m, "Flower", 0.9, cf * CFrame.new(x, 1.1, z), colors[((i + j) % #colors) + 1], Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
		end
	end
	return m
end

function Kit.bush(parent, cf, color)
	local c = color or Color3.fromRGB(70, 150, 70)
	local m = Kit.model(parent, "Bush")
	Kit.ball(m, "Leaves", 3, cf * CFrame.new(0, 1.2, 0), c, Enum.Material.Grass, { CanCollide = false })
	Kit.ball(m, "Leaves", 2.4, cf * CFrame.new(1.2, 1, 0.5), c:Lerp(Color3.new(0, 0.3, 0), 0.2), Enum.Material.Grass, { CanCollide = false })
	return m
end

function Kit.fence(parent, fromPos, toPos, color, height)
	local m = Kit.model(parent, "Fence")
	height = height or 3
	local dir = toPos - fromPos
	local len = dir.Magnitude
	local cf = CFrame.lookAt(fromPos, toPos)
	local posts = math.max(1, math.floor(len / 4))
	for i = 0, posts do
		Kit.box(m, "Post", Vector3.new(0.5, height, 0.5), cf * CFrame.new(0, height / 2, -len * i / posts), color, Enum.Material.Wood)
	end
	Kit.box(m, "Rail", Vector3.new(0.25, 0.4, len), cf * CFrame.new(0, height * 0.75, -len / 2), color, Enum.Material.Wood)
	Kit.box(m, "Rail", Vector3.new(0.25, 0.4, len), cf * CFrame.new(0, height * 0.35, -len / 2), color, Enum.Material.Wood)
	return m
end

-- Coche decorativo (el cliente lo mueve por la carretera)
function Kit.car(parent, cf, bodyColor, kind)
	local m = Kit.model(parent, "Car")
	local dark = Color3.fromRGB(35, 35, 40)
	if kind == "van" then
		Kit.box(m, "Body", Vector3.new(4.6, 4, 9), cf * CFrame.new(0, 2.8, 0), bodyColor)
		Kit.box(m, "Windshield", Vector3.new(4.2, 1.6, 0.3), cf * CFrame.new(0, 3.6, -4.5), Color3.fromRGB(160, 210, 240), Enum.Material.Glass, { Transparency = 0.2 })
		Kit.box(m, "Stripe", Vector3.new(4.7, 0.6, 7), cf * CFrame.new(0, 2.4, 0.5), Color3.new(1, 1, 1))
	elseif kind == "truck" then
		Kit.box(m, "Cab", Vector3.new(4.6, 4, 3.6), cf * CFrame.new(0, 2.8, -4), bodyColor)
		Kit.box(m, "Windshield", Vector3.new(4.2, 1.6, 0.3), cf * CFrame.new(0, 3.8, -5.85), Color3.fromRGB(160, 210, 240), Enum.Material.Glass, { Transparency = 0.2 })
		Kit.box(m, "Cargo", Vector3.new(4.8, 5, 8), cf * CFrame.new(0, 3.5, 2.2), Color3.fromRGB(235, 235, 240), Enum.Material.Metal)
	else
		Kit.box(m, "Body", Vector3.new(4.4, 1.6, 8), cf * CFrame.new(0, 1.6, 0), bodyColor)
		Kit.box(m, "Cabin", Vector3.new(4, 1.6, 4.4), cf * CFrame.new(0, 3.2, 0.4), bodyColor:Lerp(Color3.new(1, 1, 1), 0.15))
		Kit.box(m, "Glass", Vector3.new(4.1, 1.2, 4.5), cf * CFrame.new(0, 3.2, 0.4), Color3.fromRGB(160, 210, 240), Enum.Material.Glass, { Transparency = 0.3 })
	end
	for _, x in ipairs({ -2.1, 2.1 }) do
		for _, z in ipairs({ -2.7, 2.7 }) do
			local w = Kit.cylinderX(m, "Wheel", 0.8, 1.8, cf * CFrame.new(x, 0.9, z), dark, Enum.Material.SmoothPlastic)
			w.CanCollide = false
		end
	end
	Kit.box(m, "Headlight", Vector3.new(0.8, 0.5, 0.2), cf * CFrame.new(-1.5, 1.8, -4.05), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	Kit.box(m, "Headlight", Vector3.new(0.8, 0.5, 0.2), cf * CFrame.new(1.5, 1.8, -4.05), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	Kit.box(m, "Taillight", Vector3.new(0.8, 0.5, 0.2), cf * CFrame.new(-1.5, 1.8, 4.05), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	Kit.box(m, "Taillight", Vector3.new(0.8, 0.5, 0.2), cf * CFrame.new(1.5, 1.8, 4.05), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CastShadow = false
		end
	end
	m.WorldPivot = cf
	return m
end

return Kit
