--!nonstrict
-- Animaciones del mundo en el cliente (suaves y sin coste de red).
--   TE_Spin / TE_Bob / TE_Slide  movimiento de maquinas y objetos (con aceleracion
--                                al aparecer y "squash & stretch" al flotar)
--   TE_Pulse                     neones que laten
--   TE_Sway                      balanceo: "yaw" (giro) o "tilt" (arboles al viento)
--   TE_Flag                      banderas por segmentos que ondean como tela
--   TE_Cloud                     nubes a la deriva
-- Ademas: construccion animada, "+$" con trayectoria parabolica, botones de compra
-- que laten, trafico (World/Traffic) y peatones (World/Pedestrians).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("TinyEmpireShared").Format)
local Traffic = require(script.Parent.World.Traffic)
local Pedestrians = require(script.Parent.World.Pedestrians)

local Animator = {}

local entries = {} -- [Instance] = entry
local flags = {}
local clouds = {}
local trafficLights = {}
local pads = {}
local popups = {}
local ACTIVE_RANGE = 320

-- Viento global: rafagas lentas que modulan arboles y banderas
local function wind(t)
	return 0.75 + 0.25 * math.sin(t * 0.21) + 0.15 * math.sin(t * 0.83 + 1.3)
end

local function pivotOf(inst)
	if inst:IsA("Model") then
		return inst:GetPivot()
	end
	return inst.CFrame
end

local function setPivot(inst, cf)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	else
		inst.CFrame = cf
	end
end

local function register(inst)
	if entries[inst] then
		entries[inst].dirtyTags = true
		return
	end
	if not (inst:IsA("BasePart") or inst:IsA("Model")) then
		return
	end
	entries[inst] = {
		inst = inst,
		base = pivotOf(inst),
		baseTransparency = inst:IsA("BasePart") and inst.Transparency or 0,
		seed = math.random() * 10,
		born = os.clock(),
		active = true,
		dirtyTags = true,
	}
end

local function unregister(inst)
	entries[inst] = nil
end

local function refreshTags(e)
	local inst = e.inst
	e.spin = inst:HasTag("TE_Spin")
	e.bob = inst:HasTag("TE_Bob")
	e.slide = inst:HasTag("TE_Slide")
	e.pulse = inst:HasTag("TE_Pulse") and inst:IsA("BasePart")
	e.sway = inst:HasTag("TE_Sway")
	e.swayMode = inst:GetAttribute("SwayMode") or "yaw"
	e.swayAngle = math.rad(inst:GetAttribute("SwayAngle") or 15)
	e.swaySpeed = inst:GetAttribute("SwaySpeed") or 0.5
	e.spinSpeed = math.rad(inst:GetAttribute("SpinSpeed") or 45)
	e.spinAxis = inst:GetAttribute("SpinAxis") or "Y"
	e.bobHeight = inst:GetAttribute("BobHeight") or 1
	e.bobSpeed = inst:GetAttribute("BobSpeed") or 1
	e.slideOffset = inst:GetAttribute("SlideOffset") or Vector3.zero
	e.slideSpeed = inst:GetAttribute("SlideSpeed") or 0.3
	e.slideMode = inst:GetAttribute("SlideMode") or "pingpong"
	e.slidePhase = inst:GetAttribute("SlidePhase") or 0
	e.pulseSpeed = inst:GetAttribute("PulseSpeed") or 1
	e.spinAngle = e.spinAngle or 0
	e.dirtyTags = false
end

-- Movimiento de vaiven con pausa en los extremos (como una maquina real)
local function easedPingPong(phase)
	local x = phase % 1
	local f = x < 0.5 and x * 2 or (1 - x) * 2 -- triangulo 0..1..0
	f = math.clamp((f - 0.08) / 0.84, 0, 1) -- pequenas pausas en los extremos
	return f * f * (3 - 2 * f)
end

local function step(t, dt)
	local w = wind(t)
	for inst, e in pairs(entries) do
		if not e.active then
			continue
		end
		if e.dirtyTags then
			refreshTags(e)
		end
		local moved = e.spin or e.bob or e.slide or e.sway
		if moved then
			local cf = e.base
			if e.slide then
				local phase = t * e.slideSpeed + e.slidePhase
				local f = e.slideMode == "loop" and (phase % 1) or easedPingPong(phase)
				cf = cf * CFrame.new(e.slideOffset * f)
			end
			if e.bob then
				cf = cf + Vector3.new(0, math.sin((t + e.seed) * e.bobSpeed * math.pi) * e.bobHeight, 0)
			end
			if e.sway then
				local s = math.sin((t + e.seed) * e.swaySpeed * math.pi * 2)
				if e.swayMode == "tilt" then
					-- Arbol: se inclina desde la base, con rafagas de viento
					local s2 = math.sin((t + e.seed) * e.swaySpeed * 1.7 * math.pi * 2 + 1.1)
					cf = cf * CFrame.Angles(s * e.swayAngle * w, 0, s2 * e.swayAngle * 0.6 * w)
				else
					cf = cf * CFrame.Angles(0, s * e.swayAngle, 0)
				end
			end
			if e.spin then
				-- Arranque progresivo durante el primer segundo (inercia)
				local ramp = math.clamp((os.clock() - e.born) / 1.2, 0, 1)
				e.spinAngle += e.spinSpeed * dt * ramp * ramp
				local a = e.spinAngle + e.seed
				if e.spinAxis == "X" then
					cf = cf * CFrame.Angles(a, 0, 0)
				elseif e.spinAxis == "Z" then
					cf = cf * CFrame.Angles(0, 0, a)
				else
					cf = cf * CFrame.Angles(0, a, 0)
				end
			end
			setPivot(inst, cf)
		end
		if e.pulse then
			local s = (math.sin((t + e.seed) * e.pulseSpeed * math.pi * 2) + 1) / 2
			inst.Transparency = e.baseTransparency + s * s * 0.45
		end
	end
end

-- Solo se animan objetos cercanos a la camara
local function updateActive(camPos)
	for _, e in pairs(entries) do
		local ok, pos = pcall(function()
			return e.base.Position
		end)
		e.active = ok and (pos - camPos).Magnitude < ACTIVE_RANGE
	end
end

------------------------------------------------------------------------------
-- Banderas: segmentos encadenados con onda que avanza hacia el extremo
------------------------------------------------------------------------------

local function registerFlag(model)
	local segs = {}
	local n = model:GetAttribute("Segments") or 5
	for i = 1, n do
		local seg = model:FindFirstChild("Seg" .. i)
		if seg then
			table.insert(segs, seg)
		end
	end
	table.insert(flags, {
		model = model,
		segs = segs,
		width = model:GetAttribute("SegmentWidth") or 1,
		hinge = model:GetPivot(),
		seed = math.random() * 10,
	})
end

local function stepFlags(t, camPos)
	local w = wind(t)
	for _, f in ipairs(flags) do
		if f.model.Parent and (f.hinge.Position - camPos).Magnitude < 220 then
			-- La bandera apunta a favor del viento y la onda recorre la tela
			local cf = f.hinge * CFrame.Angles(0, math.sin(t * 0.4 + f.seed) * 0.35 * w, 0) * CFrame.new(0.2, 0, 0)
			for i, seg in ipairs(f.segs) do
				local amp = 0.22 + 0.1 * i
				local bend = math.sin(t * 4.2 * w - i * 0.9 + f.seed) * amp * w
				local droop = (1 - w) * 0.05 * i
				cf = cf * CFrame.Angles(0, bend, -droop)
				seg.CFrame = cf * CFrame.new(f.width / 2, 0, 0)
				cf = cf * CFrame.new(f.width, 0, 0)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Nubes y semaforos
------------------------------------------------------------------------------

local function stepClouds(t)
	for _, c in ipairs(clouds) do
		if c.model.Parent then
			local x = ((c.base.Position.X + t * c.speed + 700) % 1400) - 700
			local bobY = math.sin(t * 0.1 + c.base.Position.Z) * 2
			c.model:PivotTo(CFrame.new(x, c.base.Position.Y + bobY, c.base.Position.Z))
		end
	end
end

local function stepTrafficLights(t)
	for _, tl in ipairs(trafficLights) do
		if tl.model.Parent then
			local state = Traffic.lightState(tl.phase, t)
			if state ~= tl.state then
				tl.state = state
				for _, name in ipairs({ "Red", "Yellow", "Green" }) do
					local lamp = tl.model:FindFirstChild(name)
					if lamp then
						local on = name == state
						lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
						local c = lamp:GetAttribute("OnColor") or Color3.new(1, 1, 1)
						lamp.Color = on and c or c:Lerp(Color3.new(0.1, 0.1, 0.1), 0.75)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Botones de compra: laten y flotan para llamar la atencion
------------------------------------------------------------------------------

local function registerPad(button)
	if pads[button] then
		return
	end
	local info = button:FindFirstChild("Info")
	pads[button] = { button = button, info = info, seed = math.random() * 6 }
end

local function stepPads(t, camPos)
	for button, p in pairs(pads) do
		if not button.Parent then
			pads[button] = nil
		else
			local pad = button.Parent
			if pad:GetAttribute("Visible") and (button.Position - camPos).Magnitude < 120 then
				local s = math.sin(t * 3 + p.seed)
				button.Transparency = 0.12 + (s + 1) * 0.1
				if p.info then
					p.info.StudsOffsetWorldSpace = Vector3.new(0, 5.5 + s * 0.25, 0)
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Animacion de construccion: las piezas crecen desde el suelo con rebote
------------------------------------------------------------------------------

local function isAnimated(inst, root)
	local node = inst
	while node and node ~= root do
		if node:HasTag("TE_Spin") or node:HasTag("TE_Bob") or node:HasTag("TE_Slide") or node:HasTag("TE_Sway") then
			return true
		end
		node = node.Parent
	end
	return false
end

Animator.onBuild = nil -- function(position) (rafaga fisica de escombros)

function Animator.playBuild(model)
	local parts = {}
	local minY, maxY = math.huge, -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not isAnimated(d, model) then
			table.insert(parts, d)
			minY = math.min(minY, d.Position.Y)
			maxY = math.max(maxY, d.Position.Y)
		end
	end
	if #parts == 0 then
		return
	end
	local height = math.max(4, maxY - minY)
	local center = model:GetPivot().Position
	for _, p in ipairs(parts) do
		local targetCF = p.CFrame
		local targetSize = p.Size
		-- Retraso segun altura y distancia al centro: la obra "sube" por plantas
		local radial = Vector3.new(p.Position.X - center.X, 0, p.Position.Z - center.Z).Magnitude
		local delayTime = ((p.Position.Y - minY) / height) * 0.7 + radial * 0.012
		p.LocalTransparencyModifier = 1
		p.Size = targetSize * 0.15
		p.CFrame = targetCF * CFrame.new(0, -2.5, 0)
		task.delay(delayTime, function()
			if not p.Parent then
				return
			end
			p.LocalTransparencyModifier = 0
			local info = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(p, info, { CFrame = targetCF, Size = targetSize }):Play()
		end)
	end
	-- Nube de polvo y destellos en la base
	local puff = Instance.new("Part")
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.CanTouch = false
	puff.Transparency = 1
	puff.Size = Vector3.new(1, 1, 1)
	puff.CFrame = CFrame.new(center)
	puff.Parent = workspace
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(240, 225, 200))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1, 1.8)
	dust.Speed = NumberRange.new(10, 18)
	dust.Drag = 3
	dust.SpreadAngle = Vector2.new(180, 10)
	dust.Parent = puff
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	stars.Lifetime = NumberRange.new(1, 1.8)
	stars.Speed = NumberRange.new(12, 22)
	stars.Acceleration = Vector3.new(0, -20, 0)
	stars.SpreadAngle = Vector2.new(60, 60)
	stars.EmissionDirection = Enum.NormalId.Top
	stars.LightEmission = 1
	stars.Parent = puff
	dust:Emit(30)
	stars:Emit(40)
	task.delay(0.7 + 0.3, function()
		stars:Emit(25) -- segundo destello al terminar
	end)
	task.delay(3, function()
		puff:Destroy()
	end)
	if Animator.onBuild then
		Animator.onBuild(center)
	end
end

------------------------------------------------------------------------------
-- "+$" flotantes: saltan con trayectoria parabolica y se desvanecen
------------------------------------------------------------------------------

local POPUP_INTERVAL = 3
local GRAVITY = 22

local function popup(model, amount)
	local cf = model:GetPivot()
	local size = model:GetExtentsSize()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	local start = cf.Position + Vector3.new(math.random(-3, 3), size.Y * 0.8 + 1, math.random(-3, 3))
	anchor.CFrame = CFrame.new(start)
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(40, 14)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+" .. Format.cash(amount)
	label.TextColor3 = Color3.fromRGB(110, 255, 130)
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 70, 30)
	stroke.Parent = label
	-- Aparece con rebote (escala) y luego cae en parabola
	TweenService:Create(bb, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(140, 44) }):Play()
	local a = math.random() * math.pi * 2
	table.insert(popups, {
		anchor = anchor,
		label = label,
		stroke = stroke,
		pos = start,
		vel = Vector3.new(math.cos(a) * 2.5, 13, math.sin(a) * 2.5),
		age = 0,
		life = 1.6,
	})
end

local function stepPopups(dt)
	for i = #popups, 1, -1 do
		local p = popups[i]
		p.age += dt
		if p.age >= p.life or not p.anchor.Parent then
			if p.anchor.Parent then
				p.anchor:Destroy()
			end
			table.remove(popups, i)
		else
			p.vel += Vector3.new(0, -GRAVITY * dt, 0)
			p.pos += p.vel * dt
			p.anchor.CFrame = CFrame.new(p.pos)
			local fade = math.clamp((p.age - p.life * 0.55) / (p.life * 0.45), 0, 1)
			p.label.TextTransparency = fade
			p.stroke.Transparency = fade
		end
	end
end

local function popupLoop(plotsFolder)
	while true do
		task.wait(POPUP_INTERVAL)
		local cam = workspace.CurrentCamera
		if cam then
			local camPos = cam.CFrame.Position
			local shown = 0
			for _, plot in ipairs(plotsFolder:GetChildren()) do
				local buildings = plot:FindFirstChild("Buildings")
				if buildings then
					for _, m in ipairs(buildings:GetChildren()) do
						local income = m:GetAttribute("Income")
						if income and income > 0 and shown < 24 then
							local dist = (m:GetPivot().Position - camPos).Magnitude
							if dist < 140 then
								shown += 1
								task.delay(math.random() * 1.2, popup, m, income * POPUP_INTERVAL)
							end
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------

function Animator.start(map)
	for _, tag in ipairs({ "TE_Spin", "TE_Bob", "TE_Slide", "TE_Pulse", "TE_Sway" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			register(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(register)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unregister)
	end
	for _, f in ipairs(CollectionService:GetTagged("TE_Flag")) do
		registerFlag(f)
	end
	for _, tl in ipairs(CollectionService:GetTagged("TE_TrafficLight")) do
		table.insert(trafficLights, { model = tl, phase = tl:GetAttribute("Phase") or 0, state = nil })
	end
	for _, c in ipairs(CollectionService:GetTagged("TE_Cloud")) do
		table.insert(clouds, { model = c, base = c:GetPivot(), speed = c:GetAttribute("Speed") or 3 })
	end
	Traffic.start()
	Pedestrians.start()

	local plotsFolder = map:WaitForChild("Plots")
	local function watchPlot(plot)
		local buildings = plot:WaitForChild("Buildings", 10)
		local padFolder = plot:WaitForChild("Pads", 10)
		if padFolder then
			for _, d in ipairs(padFolder:GetDescendants()) do
				if d.Name == "Button" and d:IsA("BasePart") then
					registerPad(d)
				end
			end
		end
		if not buildings then
			return
		end
		buildings.ChildAdded:Connect(function(m)
			local builtAt = m:GetAttribute("BuiltAt")
			if builtAt and workspace:GetServerTimeNow() - builtAt < 4 then
				task.defer(Animator.playBuild, m)
			end
		end)
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		task.spawn(watchPlot, plot)
	end
	plotsFolder.ChildAdded:Connect(watchPlot)

	local start = os.clock()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		acc += dt
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		if acc > 0.5 then
			acc = 0
			updateActive(camPos)
		end
		step(t, dt)
		stepFlags(t, camPos)
		stepClouds(t)
		stepTrafficLights(t)
		stepPads(t, camPos)
		stepPopups(dt)
		Traffic.step(dt, t, camPos)
		Pedestrians.step(dt, t, camPos)
	end)
	task.spawn(popupLoop, plotsFolder)
end

Animator._entries = entries
Animator._flags = flags
Animator._popups = popups

return Animator
