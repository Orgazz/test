--!nonstrict
-- Animaciones del mundo en el cliente (suaves y sin coste de red):
-- giros, flotacion, deslizamientos, neones, coches, construccion y "+$" flotantes.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("TinyEmpireShared").Format)

local Animator = {}

local entries = {} -- [Instance] = entry
local cars = {}
local ACTIVE_RANGE = 320

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
	e.dirtyTags = false
end

local function step(t)
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
				local f
				if e.slideMode == "loop" then
					f = phase % 1
				else
					f = (1 - math.cos(phase * math.pi * 2)) / 2
				end
				cf = cf * CFrame.new(e.slideOffset * f)
			end
			if e.bob then
				cf = cf + Vector3.new(0, math.sin((t + e.seed) * e.bobSpeed * math.pi) * e.bobHeight, 0)
			end
			if e.sway then
				cf = cf * CFrame.Angles(0, math.sin((t + e.seed) * e.swaySpeed * math.pi * 2) * e.swayAngle, 0)
			end
			if e.spin then
				local a = (t + e.seed) * e.spinSpeed
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
			inst.Transparency = e.baseTransparency + s * 0.45
		end
	end
end

-- Solo se animan objetos cercanos a la camara
local function updateActive()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	for _, e in pairs(entries) do
		local ok, pos = pcall(function()
			return e.base.Position
		end)
		e.active = ok and (pos - camPos).Magnitude < ACTIVE_RANGE
	end
end

------------------------------------------------------------------------------
-- Coches por el anillo exterior
------------------------------------------------------------------------------

local function pointOnRing(rx, rz, s)
	local w, h = rx * 2, rz * 2
	local perim = 2 * (w + h)
	s = s % perim
	if s < w then
		return Vector3.new(-rx + s, 0, -rz), Vector3.new(1, 0, 0)
	end
	s -= w
	if s < h then
		return Vector3.new(rx, 0, -rz + s), Vector3.new(0, 0, 1)
	end
	s -= h
	if s < w then
		return Vector3.new(rx - s, 0, rz), Vector3.new(-1, 0, 0)
	end
	s -= w
	return Vector3.new(-rx, 0, rz - s), Vector3.new(0, 0, -1)
end

local function stepCars(t)
	for _, car in ipairs(cars) do
		if car.model.Parent then
			local rx, rz = car.rx, car.rz
			local perim = 2 * (rx * 2 + rz * 2)
			local s = car.phase * perim + t * car.speed * car.lane
			local pos, dir = pointOnRing(rx, rz, s)
			if car.lane < 0 then
				dir = -dir
			end
			local right = dir:Cross(Vector3.yAxis)
			local p = pos + right * 5 + Vector3.new(0, 0.3, 0)
			car.model:PivotTo(CFrame.lookAt(p, p + dir))
		end
	end
end

local function registerCar(model)
	local folder = model.Parent
	table.insert(cars, {
		model = model,
		rx = folder:GetAttribute("RingX") or 330,
		rz = folder:GetAttribute("RingZ") or 185,
		phase = model:GetAttribute("Phase") or 0,
		lane = model:GetAttribute("Lane") or 1,
		speed = model:GetAttribute("Speed") or 25,
	})
end

------------------------------------------------------------------------------
-- Peatones, semaforos y nubes
------------------------------------------------------------------------------

local walkers = {}
local trafficLights = {}
local clouds = {}

local function registerWalker(model)
	local pivot = model:GetPivot()
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			local limb = nil
			if d.Name == "LegL" or (d.Name == "Shoe" and rel.Position.X < 0) then
				limb = "legL"
			elseif d.Name == "LegR" or (d.Name == "Shoe" and rel.Position.X > 0) then
				limb = "legR"
			elseif d.Name == "ArmL" then
				limb = "armL"
			elseif d.Name == "ArmR" then
				limb = "armR"
			end
			table.insert(parts, { part = d, rel = rel, limb = limb })
		end
	end
	table.insert(walkers, {
		model = model,
		parts = parts,
		mode = model:GetAttribute("WalkMode") or "circle",
		cx = model:GetAttribute("CenterX") or 0,
		cz = model:GetAttribute("CenterZ") or 0,
		radius = model:GetAttribute("Radius") or 20,
		a = model:GetAttribute("A") or Vector3.zero,
		b = model:GetAttribute("B") or Vector3.new(10, 0, 0),
		speed = model:GetAttribute("Speed") or 4,
		phase = model:GetAttribute("Phase") or 0,
		baseY = model:GetAttribute("BaseY") or 0.5,
		active = true,
	})
end

local HIP = CFrame.new(0, 2, 0)
local SHOULDER = CFrame.new(0, 3.9, 0)

local function stepWalkers(t, camPos)
	for _, w in ipairs(walkers) do
		if w.model.Parent and w.active then
			local pos, dir
			if w.mode == "line" then
				local delta = w.b - w.a
				local len = delta.Magnitude
				local s = (w.phase * 2 * len + t * math.abs(w.speed)) % (2 * len)
				if s < len then
					pos = w.a + delta * (s / len)
					dir = delta.Unit
				else
					pos = w.b - delta * ((s - len) / len)
					dir = -delta.Unit
				end
			else
				local ang = w.phase * math.pi * 2 + t * w.speed / w.radius
				pos = Vector3.new(w.cx + math.cos(ang) * w.radius, 0, w.cz + math.sin(ang) * w.radius)
				dir = Vector3.new(-math.sin(ang), 0, math.cos(ang)) * (w.speed >= 0 and 1 or -1)
			end
			pos = Vector3.new(pos.X, w.baseY, pos.Z)
			local pivot = CFrame.lookAt(pos, pos + dir)
			local swing = math.sin(t * math.abs(w.speed) * 1.9 + w.phase * 10) * 0.55
			for _, p in ipairs(w.parts) do
				local cf
				if p.limb == "legL" or p.limb == "legR" then
					local a = p.limb == "legL" and swing or -swing
					cf = pivot * HIP * CFrame.Angles(a, 0, 0) * HIP:Inverse() * p.rel
				elseif p.limb == "armL" or p.limb == "armR" then
					local a = p.limb == "armL" and -swing or swing
					cf = pivot * SHOULDER * CFrame.Angles(a * 0.8, 0, 0) * SHOULDER:Inverse() * p.rel
				else
					cf = pivot * p.rel
				end
				p.part.CFrame = cf
			end
		end
	end
	local _ = camPos
end

local function updateWalkersActive(camPos)
	for _, w in ipairs(walkers) do
		local root = w.parts[1]
		w.active = root ~= nil and (root.part.Position - camPos).Magnitude < 260
	end
end

local function stepTrafficLights(t)
	for _, tl in ipairs(trafficLights) do
		if tl.model.Parent then
			local cycle = (t / 12 + tl.phase) % 1
			local state = cycle < 0.42 and "Green" or (cycle < 0.54 and "Yellow" or "Red")
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

local function stepClouds(t)
	for _, c in ipairs(clouds) do
		if c.model.Parent then
			local x = ((c.base.Position.X + t * c.speed + 700) % 1400) - 700
			c.model:PivotTo(CFrame.new(x, c.base.Position.Y, c.base.Position.Z))
		end
	end
end

------------------------------------------------------------------------------
-- Animacion de construccion
------------------------------------------------------------------------------

local function isAnimated(inst, root)
	local node = inst
	while node and node ~= root do
		if node:HasTag("TE_Spin") or node:HasTag("TE_Bob") or node:HasTag("TE_Slide") then
			return true
		end
		node = node.Parent
	end
	return false
end

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
	for _, p in ipairs(parts) do
		local target = p.CFrame
		local delayTime = ((p.Position.Y - minY) / height) * 0.6
		p.CFrame = target * CFrame.new(0, -3, 0)
		local origTrans = p.Transparency
		p.LocalTransparencyModifier = 1
		task.delay(delayTime, function()
			if not p.Parent then
				return
			end
			p.LocalTransparencyModifier = 0
			local tween = TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = target })
			tween:Play()
		end)
		local _ = origTrans
	end
	-- Nube de polvo y destellos
	local cf = model:GetPivot()
	local puff = Instance.new("Part")
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.Transparency = 1
	puff.Size = Vector3.new(1, 1, 1)
	puff.CFrame = cf
	puff.Parent = workspace
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(240, 225, 200))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1, 1.6)
	dust.Speed = NumberRange.new(8, 14)
	dust.SpreadAngle = Vector2.new(180, 10)
	dust.Parent = puff
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	stars.Lifetime = NumberRange.new(1, 1.8)
	stars.Speed = NumberRange.new(10, 20)
	stars.SpreadAngle = Vector2.new(60, 60)
	stars.EmissionDirection = Enum.NormalId.Top
	stars.LightEmission = 1
	stars.Parent = puff
	dust:Emit(30)
	stars:Emit(40)
	task.delay(3, function()
		puff:Destroy()
	end)
end

------------------------------------------------------------------------------
-- "+$" flotantes sobre los negocios
------------------------------------------------------------------------------

local POPUP_INTERVAL = 3

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
	anchor.CFrame = CFrame.new(cf.Position + Vector3.new(math.random(-3, 3), size.Y + 1, math.random(-3, 3)))
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(140, 44)
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
	TweenService:Create(anchor, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	task.delay(1.7, function()
		anchor:Destroy()
	end)
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
	for _, car in ipairs(CollectionService:GetTagged("TE_Car")) do
		registerCar(car)
	end
	for _, w in ipairs(CollectionService:GetTagged("TE_Walker")) do
		registerWalker(w)
	end
	for _, tl in ipairs(CollectionService:GetTagged("TE_TrafficLight")) do
		table.insert(trafficLights, { model = tl, phase = tl:GetAttribute("Phase") or 0, state = nil })
	end
	for _, c in ipairs(CollectionService:GetTagged("TE_Cloud")) do
		table.insert(clouds, { model = c, base = c:GetPivot(), speed = c:GetAttribute("Speed") or 3 })
	end

	-- Construccion animada de edificios nuevos (en cualquier parcela)
	local plotsFolder = map:WaitForChild("Plots")
	local function watchPlot(plot)
		local buildings = plot:WaitForChild("Buildings", 10)
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
			updateActive()
			updateWalkersActive(camPos)
			stepTrafficLights(t)
		end
		step(t)
		stepCars(t)
		stepWalkers(t, camPos)
		stepClouds(t)
	end)
	task.spawn(popupLoop, plotsFolder)
end

return Animator
