--!nonstrict
-- Trafico del anillo exterior con un modelo de conduccion sencillo:
--  * recorrido con curvas redondeadas (sin giros bruscos de 90 grados)
--  * aceleracion y frenado realistas (curva de frenado v = sqrt(2·a·d))
--  * distancia de seguridad con el coche de delante
--  * se detienen en los semaforos en rojo y ante jugadores en la calzada
--  * ruedas que giran, cabeceo al frenar, balanceo en las curvas y luces de freno

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Traffic = {}

local CORNER_RADIUS = 16
local LANE_OFFSET = 5
local ACCEL = 9
local BRAKE = 20
local CURVE_SPEED = 13
local SAFE_GAP = 11
local STOP_BEFORE = 17 -- distancia del centro del cruce a la linea de detencion
local ACTIVE_RANGE = 400

local cars = {}
local path = nil
local intersections = {}

------------------------------------------------------------------------------
-- Recorrido: rectangulo de esquinas redondeadas (parametro s = distancia)
------------------------------------------------------------------------------

local function buildPath(rx, rz)
	local rc = CORNER_RADIUS
	local lx = 2 * rx - 2 * rc
	local lz = 2 * rz - 2 * rc
	local arc = math.pi * rc / 2
	local segs = {
		{ kind = "line", from = Vector3.new(-rx + rc, 0, -rz), dir = Vector3.new(1, 0, 0), len = lx },
		{ kind = "arc", center = Vector3.new(rx - rc, 0, -rz + rc), a0 = -math.pi / 2, len = arc },
		{ kind = "line", from = Vector3.new(rx, 0, -rz + rc), dir = Vector3.new(0, 0, 1), len = lz },
		{ kind = "arc", center = Vector3.new(rx - rc, 0, rz - rc), a0 = 0, len = arc },
		{ kind = "line", from = Vector3.new(rx - rc, 0, rz), dir = Vector3.new(-1, 0, 0), len = lx },
		{ kind = "arc", center = Vector3.new(-rx + rc, 0, rz - rc), a0 = math.pi / 2, len = arc },
		{ kind = "line", from = Vector3.new(-rx, 0, rz - rc), dir = Vector3.new(0, 0, -1), len = lz },
		{ kind = "arc", center = Vector3.new(-rx + rc, 0, -rz + rc), a0 = math.pi, len = arc },
	}
	local total = 0
	for _, seg in ipairs(segs) do
		seg.start = total
		total += seg.len
	end
	return { segs = segs, length = total, rc = rc }
end

-- Devuelve posicion, direccion y si es curva para la distancia s
local function sample(s)
	s %= path.length
	for _, seg in ipairs(path.segs) do
		if s < seg.start + seg.len then
			local u = s - seg.start
			if seg.kind == "line" then
				return seg.from + seg.dir * u, seg.dir, false
			end
			local a = seg.a0 + u / path.rc
			local pos = seg.center + Vector3.new(math.cos(a), 0, math.sin(a)) * path.rc
			return pos, Vector3.new(-math.sin(a), 0, math.cos(a)), true
		end
	end
	return path.segs[1].from, path.segs[1].dir, false
end

-- Distancia (en sentido de la marcha) hasta la proxima curva
local function distToCurve(s, lane)
	local best = math.huge
	for _, seg in ipairs(path.segs) do
		if seg.kind == "arc" then
			local entry = lane > 0 and seg.start or (seg.start + seg.len)
			local d
			if lane > 0 then
				d = (entry - s) % path.length
			else
				d = (s - entry) % path.length
			end
			best = math.min(best, d)
		end
	end
	return best
end

local function closestS(point)
	local best, bestS = math.huge, 0
	for s = 0, path.length, 1 do
		local p = sample(s)
		local d = (p - point).Magnitude
		if d < best then
			best, bestS = d, s
		end
	end
	return bestS
end

------------------------------------------------------------------------------
-- Semaforos
------------------------------------------------------------------------------

local function lightState(phase, t)
	local cycle = (t / 12 + phase) % 1
	if cycle < 0.42 then
		return "Green"
	elseif cycle < 0.54 then
		return "Yellow"
	end
	return "Red"
end
Traffic.lightState = lightState

local function setupIntersections()
	local byCenter = {}
	for _, light in ipairs(CollectionService:GetTagged("TE_TrafficLight")) do
		if light:GetAttribute("Road") == "ring" then
			local key = string.format("%d,%d", light:GetAttribute("CenterX") or 0, light:GetAttribute("CenterZ") or 0)
			if not byCenter[key] then
				local center = Vector3.new(light:GetAttribute("CenterX") or 0, 0, light:GetAttribute("CenterZ") or 0)
				byCenter[key] = true
				table.insert(intersections, { s = closestS(center), phase = light:GetAttribute("Phase") or 0 })
			end
		end
	end
end

------------------------------------------------------------------------------
-- Coches
------------------------------------------------------------------------------

local function register(model)
	local pivot = model:GetPivot()
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, {
				part = d,
				rel = pivot:ToObjectSpace(d.CFrame),
				wheel = d.Name == "Wheel",
				tail = d.Name == "Taillight",
			})
		end
	end
	local folder = model.Parent
	if not path then
		path = buildPath(folder:GetAttribute("RingX") or 330, folder:GetAttribute("RingZ") or 185)
	end
	local lane = model:GetAttribute("Lane") or 1
	table.insert(cars, {
		model = model,
		parts = parts,
		lane = lane,
		cruise = model:GetAttribute("Speed") or 25,
		s = ((model:GetAttribute("Phase") or 0) * path.length) % path.length,
		v = 0,
		accel = 0,
		wheelAngle = 0,
		roll = 0,
		pitch = 0,
		braking = false,
		active = true,
	})
end

-- Distancia hacia delante (sentido de la marcha) de a hasta b
local function ahead(car, sOther)
	if car.lane > 0 then
		return (sOther - car.s) % path.length
	end
	return (car.s - sOther) % path.length
end

local function playerBlocking(car, pos, dir)
	local best = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local rel = root.Position - pos
			local forward = rel:Dot(dir)
			local lateral = (rel - dir * forward).Magnitude
			if forward > 0 and forward < 45 and lateral < 4.5 and math.abs(rel.Y) < 8 then
				best = math.min(best, forward)
			end
		end
	end
	return best
end

local function stepCar(car, dt, t, render)
	-- Velocidad deseada: crucero, limitada por curvas, coche delantero, semaforos y jugadores
	local desired = car.cruise
	-- Curva de frenado v = sqrt(2·a·d); por defecto con deceleracion comoda
	local function limitToStopAt(distance, decel)
		local v = math.sqrt(2 * (decel or BRAKE * 0.6) * math.max(0, distance))
		if v < desired then
			desired = v
		end
	end
	local dCurve = distToCurve(car.s, car.lane)
	local _, dir0, inCurve = sample(car.s)
	if inCurve then
		desired = math.min(desired, CURVE_SPEED)
	else
		desired = math.min(desired, math.sqrt(CURVE_SPEED * CURVE_SPEED + 2 * BRAKE * 0.6 * dCurve))
	end
	-- Coche de delante en el mismo carril
	local gap = math.huge
	for _, other in ipairs(cars) do
		if other ~= car and other.lane == car.lane then
			local g = ahead(car, other.s)
			if g > 0 and g < gap then
				gap = g
			end
		end
	end
	if gap < 80 then
		limitToStopAt(gap - SAFE_GAP, BRAKE * 0.8)
	end
	-- Semaforos del anillo. Si al ponerse en ambar/rojo el coche ya no puede detenerse
	-- con comodidad, se "compromete" y cruza (como un conductor real).
	for _, inter in ipairs(intersections) do
		local d = ahead(car, inter.s)
		local distToLine = d - STOP_BEFORE
		if distToLine < -6 or distToLine >= 60 then
			-- ya cruzado (o aun lejos): se olvida la decision tomada
			if car.committed == inter then
				car.committed = nil
			end
			if car.stopping == inter then
				car.stopping = nil
			end
		else
			local state = lightState(inter.phase, t)
			if state == "Green" then
				if car.stopping == inter then
					car.stopping = nil
				end
			elseif car.committed ~= inter then
				-- La decision (parar o cruzar) se toma una vez y se mantiene
				if car.stopping ~= inter then
					local canStop = car.v * car.v <= 2 * BRAKE * math.max(distToLine, 0) + 9
					if canStop then
						car.stopping = inter
					else
						car.committed = inter
					end
				end
				if car.stopping == inter then
					limitToStopAt(math.max(distToLine, 0), BRAKE * 0.6)
				end
			end
		end
	end

	-- Jugadores en la calzada
	local pos0 = sample(car.s)
	local dirTravel = car.lane > 0 and dir0 or -dir0
	local right = dirTravel:Cross(Vector3.yAxis)
	local blocking = playerBlocking(car, pos0 + right * LANE_OFFSET, dirTravel)
	if blocking < math.huge then
		limitToStopAt(blocking - 7, BRAKE)
	end

	-- Integracion (aceleracion limitada)
	local dv = desired - car.v
	local a = math.clamp(dv / math.max(dt, 1e-3), -BRAKE, ACCEL)
	car.v = math.max(0, car.v + a * dt)
	car.accel += (a - car.accel) * math.min(1, dt * 6)
	car.braking = a < -2
	car.s = (car.s + car.lane * car.v * dt) % path.length
	if not render then
		return
	end

	-- Pose
	local pos, dir = sample(car.s)
	if car.lane < 0 then
		dir = -dir
	end
	local r = dir:Cross(Vector3.yAxis)
	local p = pos + r * LANE_OFFSET + Vector3.new(0, 0.3, 0)
	-- Balanceo en curva (aceleracion lateral v^2/r) y cabeceo al acelerar/frenar
	local _, dirAhead = sample(car.s + car.lane * 2)
	if car.lane < 0 then
		dirAhead = -dirAhead
	end
	local turn = dir:Cross(dirAhead).Y -- signo del giro
	local targetRoll = math.clamp(turn * car.v * car.v * 0.0011, -0.07, 0.07)
	car.roll += (targetRoll - car.roll) * math.min(1, dt * 5)
	local targetPitch = math.clamp(car.accel * 0.0035, -0.05, 0.035)
	car.pitch += (targetPitch - car.pitch) * math.min(1, dt * 7)
	local suspension = math.sin(t * 9 + car.s) * 0.04 * math.min(1, car.v / 20)
	local body = CFrame.lookAt(p, p + dir) * CFrame.new(0, suspension, 0) * CFrame.Angles(car.pitch, 0, car.roll)
	local flat = CFrame.lookAt(p, p + dir)
	car.wheelAngle = (car.wheelAngle - car.v * dt / 0.9) % (math.pi * 2)
	for _, info in ipairs(car.parts) do
		if info.wheel then
			info.part.CFrame = flat * info.rel * CFrame.Angles(car.wheelAngle, 0, 0)
		else
			info.part.CFrame = body * info.rel
			if info.tail then
				info.part.Color = car.braking and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(150, 30, 30)
			end
		end
	end
end

function Traffic.start()
	for _, car in ipairs(CollectionService:GetTagged("TE_Car")) do
		register(car)
	end
	if path then
		setupIntersections()
	end
end

function Traffic.step(dt, t, camPos)
	if not path then
		return
	end
	Traffic._time = t
	Traffic._length = path.length
	dt = math.min(dt, 0.1)
	for _, car in ipairs(cars) do
		if car.model.Parent then
			-- Lejos de la camara se simula igual (mismo comportamiento), pero sin mover piezas
			local pos = sample(car.s)
			car.active = (pos - camPos).Magnitude < ACTIVE_RANGE
			stepCar(car, dt, t, car.active)
		end
	end
end

-- Para las pruebas
Traffic._cars = cars
Traffic._sample = function(s)
	return sample(s)
end
Traffic._intersections = intersections

return Traffic
