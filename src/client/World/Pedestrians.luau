--!nonstrict
-- Peatones con comportamiento natural:
--  * aceleran y frenan suavemente, giran poco a poco
--  * al final de cada acera se detienen, miran alrededor y dan la vuelta
--  * de vez en cuando paran a mirar la fuente
--  * esquivan / esperan si un jugador se cruza delante
--  * paso con balanceo de brazos y piernas y rebote del cuerpo proporcional a la velocidad

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Pedestrians = {}

local walkers = {}
local HIP = CFrame.new(0, 2, 0)
local SHOULDER = CFrame.new(0, 3.9, 0)
local ACCEL = 5
local TURN_RATE = 5
local ACTIVE_RANGE = 260

local function yawOf(dir)
	return math.atan2(-dir.X, -dir.Z)
end

local function lerpAngle(a, b, alpha)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * alpha
end

local function register(model)
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
			elseif d.Name == "Head" or d.Name == "Hair" or d.Name == "Cap" or d.Name == "Visor" or d.Name:sub(1, 3) == "Eye" then
				limb = "head"
			end
			table.insert(parts, { part = d, rel = rel, limb = limb })
		end
	end
	local phase = model:GetAttribute("Phase") or 0
	local w = {
		model = model,
		parts = parts,
		mode = model:GetAttribute("WalkMode") or "circle",
		cx = model:GetAttribute("CenterX") or 0,
		cz = model:GetAttribute("CenterZ") or 0,
		radius = model:GetAttribute("Radius") or 20,
		a = model:GetAttribute("A") or Vector3.zero,
		b = model:GetAttribute("B") or Vector3.new(10, 0, 0),
		cruise = math.abs(model:GetAttribute("Speed") or 4),
		sign = (model:GetAttribute("Speed") or 1) >= 0 and 1 or -1,
		baseY = model:GetAttribute("BaseY") or 0.5,
		v = 0,
		step = phase * 10,
		state = "walk",
		timer = 0,
		nextIdle = 8 + phase * 20,
		lookYaw = 0,
		active = true,
		seed = phase * 100,
	}
	if w.mode == "line" then
		local len = (w.b - w.a).Magnitude
		local u = (phase * 2 * len) % (2 * len)
		w.leg = u < len and 1 or -1
		w.u = u < len and u or u - len
		w.len = len
	else
		w.angle = phase * math.pi * 2
	end
	local _, dir = Pedestrians._pose(w)
	w.yaw = yawOf(dir)
	table.insert(walkers, w)
end

-- Posicion y direccion de marcha actuales
function Pedestrians._pose(w)
	if w.mode == "line" then
		local delta = (w.b - w.a)
		local unit = delta.Unit
		if w.leg > 0 then
			return w.a + unit * w.u, unit
		end
		return w.b - unit * w.u, -unit
	end
	local pos = Vector3.new(w.cx + math.cos(w.angle) * w.radius, 0, w.cz + math.sin(w.angle) * w.radius)
	local dir = Vector3.new(-math.sin(w.angle), 0, math.cos(w.angle)) * w.sign
	return pos, dir
end

local function blocked(pos, dir)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local rel = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
			local forward = rel:Dot(dir)
			if forward > 0 and forward < 5 and (rel - dir * forward).Magnitude < 2.5 then
				return true
			end
		end
	end
	return false
end

local function stepWalker(w, dt, t)
	local pos, dir = Pedestrians._pose(w)
	local targetSpeed = w.cruise
	local targetYaw = yawOf(dir)

	if w.state == "turn" then
		-- Fin de la acera: se para, mira a un lado y da media vuelta
		w.timer -= dt
		targetSpeed = 0
		local progress = 1 - math.max(0, w.timer) / 1.6
		targetYaw = yawOf(dir) + math.sin(progress * math.pi) * 0.6 + (progress > 0.5 and math.pi or 0)
		if w.timer <= 0 then
			w.leg = -w.leg
			w.u = 0
			w.state = "walk"
			pos, dir = Pedestrians._pose(w)
			targetYaw = yawOf(dir)
		end
	elseif w.state == "idle" then
		-- Parada para mirar la fuente / el escaparate
		w.timer -= dt
		targetSpeed = 0
		local toCenter = Vector3.new(w.cx - pos.X, 0, w.cz - pos.Z)
		if w.mode == "circle" and toCenter.Magnitude > 0.1 then
			targetYaw = yawOf(toCenter.Unit)
		end
		w.lookYaw = math.sin(t * 1.3 + w.seed) * 0.5
		if w.timer <= 0 then
			w.state = "walk"
			w.nextIdle = 14 + (w.seed * 7.3) % 18
		end
	else
		w.lookYaw *= 1 - math.min(1, dt * 3)
		w.nextIdle -= dt
		if w.nextIdle <= 0 then
			w.state = "idle"
			w.timer = 2.2 + (w.seed % 1.5)
		end
		if blocked(pos, dir) then
			targetSpeed = 0
		end
	end

	-- Velocidad con aceleracion suave
	local dv = targetSpeed - w.v
	w.v = math.max(0, w.v + math.clamp(dv, -ACCEL * 1.6 * dt, ACCEL * dt))
	if w.mode == "line" then
		w.u += w.v * dt
		if w.u >= w.len and w.state == "walk" then
			w.u = w.len
			w.state = "turn"
			w.timer = 1.6
		end
		w.u = math.min(w.u, w.len)
	else
		w.angle += w.sign * w.v * dt / w.radius
	end
	pos = Pedestrians._pose(w)

	-- Giro suave
	w.yaw = lerpAngle(w.yaw, targetYaw, math.min(1, dt * TURN_RATE))

	-- Paso: frecuencia proporcional a la velocidad
	local speedFactor = math.clamp(w.v / math.max(w.cruise, 0.1), 0, 1)
	w.step += w.v * dt * 1.9
	local swing = math.sin(w.step) * 0.6 * speedFactor
	local bounce = math.abs(math.sin(w.step)) * 0.16 * speedFactor
	local breathe = math.sin(t * 2 + w.seed) * 0.03 * (1 - speedFactor)
	local pivot = CFrame.new(pos.X, w.baseY + bounce, pos.Z) * CFrame.Angles(0, w.yaw, 0)
	-- Ligera inclinacion hacia delante al andar
	pivot *= CFrame.Angles(-0.06 * speedFactor, 0, 0)
	local idleArm = (1 - speedFactor) * 0.08

	for _, p in ipairs(w.parts) do
		local cf
		if p.limb == "legL" or p.limb == "legR" then
			local a = p.limb == "legL" and swing or -swing
			cf = pivot * HIP * CFrame.Angles(a, 0, 0) * HIP:Inverse() * p.rel
		elseif p.limb == "armL" or p.limb == "armR" then
			local a = (p.limb == "armL" and -swing or swing) * 0.85
			local side = p.limb == "armL" and idleArm or -idleArm
			cf = pivot * SHOULDER * CFrame.Angles(a, 0, side) * SHOULDER:Inverse() * p.rel
		elseif p.limb == "head" then
			cf = pivot * CFrame.new(0, 4.65 + breathe, 0) * CFrame.Angles(0, w.lookYaw, 0) * CFrame.new(0, -4.65, 0) * p.rel
		else
			cf = pivot * CFrame.new(0, breathe, 0) * p.rel
		end
		p.part.CFrame = cf
	end
end

function Pedestrians.start()
	for _, m in ipairs(CollectionService:GetTagged("TE_Walker")) do
		register(m)
	end
end

function Pedestrians.step(dt, t, camPos)
	dt = math.min(dt, 0.1)
	for _, w in ipairs(walkers) do
		if w.model.Parent then
			local pos = Pedestrians._pose(w)
			if (pos - camPos).Magnitude < ACTIVE_RANGE then
				stepWalker(w, dt, t)
			end
		end
	end
end

Pedestrians._walkers = walkers

return Pedestrians
