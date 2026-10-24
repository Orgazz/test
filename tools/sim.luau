--!nocheck
-- Extensiones del arnes SOLO para generar videos (no se usan en las pruebas):
--  * Tweens reales con interpolacion y curvas de suavizado
--  * Fisica aproximada: gravedad, rebote, friccion y rotacion de piezas sueltas
--    (y de los ensamblajes soldados con WeldConstraint), suelo por zonas,
--    trampolines (dispara Touched al aterrizar en la lona)
-- Es una aproximacion para la vista previa: en Roblox la fisica es la del motor.

local roblox = require("@lune/roblox")
local Sim = {}

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local GRAVITY = 196.2

------------------------------------------------------------------------------
-- Tweens
------------------------------------------------------------------------------

local function ease(style, dir, x)
	local name = style and style.Name or "Quad"
	dir = dir and dir.Name or "Out"
	local function easeIn(t)
		if name == "Linear" then
			return t
		elseif name == "Sine" then
			return 1 - math.cos(t * math.pi / 2)
		elseif name == "Back" then
			local c1 = 1.70158
			return (c1 + 1) * t * t * t - c1 * t * t
		elseif name == "Cubic" then
			return t * t * t
		end
		return t * t
	end
	if dir == "In" then
		return easeIn(x)
	elseif dir == "Out" then
		return 1 - easeIn(1 - x)
	end
	if x < 0.5 then
		return easeIn(x * 2) / 2
	end
	return 1 - easeIn((1 - x) * 2) / 2
end

local function lerp(a, b, t)
	local ty = typeof(a)
	if ty == "number" then
		return a + (b - a) * t
	elseif ty == "boolean" or ty == "EnumItem" then
		return t >= 1 and b or a
	end
	return a:Lerp(b, t)
end

function Sim.install(H)
	local active = {}
	H.tweenOverride = function(inst, info, goals)
		local tween = { Completed = H.Signal.new("Completed") }
		local entry
		function tween:Play()
			local start = {}
			for k in pairs(goals) do
				local ok, v = pcall(function()
					return inst[k]
				end)
				start[k] = ok and v or goals[k]
			end
			-- un nuevo tween sobre las mismas propiedades cancela al anterior
			for i = #active, 1, -1 do
				local other = active[i]
				if other.inst == inst then
					for k in pairs(goals) do
						other.goals[k] = nil
					end
				end
			end
			entry = {
				inst = inst,
				goals = table.clone(goals),
				start = start,
				info = info or { Time = 1 },
				t = -((info and info.DelayTime) or 0),
				repeats = (info and info.RepeatCount) or 0,
				reverses = info and info.Reverses,
				forward = true,
				tween = tween,
			}
			table.insert(active, entry)
		end
		function tween:Cancel()
			if entry then
				entry.goals = {}
			end
		end
		tween.Pause = tween.Cancel
		return tween
	end
	table.insert(H.frameHooks, function(dt)
		for i = #active, 1, -1 do
			local e = active[i]
			e.t += dt
			local duration = math.max(e.info.Time or 1, 1e-3)
			local x = math.clamp(e.t / duration, 0, 1)
			local k = ease(e.info.EasingStyle, e.info.EasingDirection, x)
			if not e.forward then
				k = 1 - k
			end
			local alive = true
			for prop, goal in pairs(e.goals) do
				local ok = pcall(function()
					e.inst[prop] = lerp(e.start[prop], goal, k)
				end)
				if not ok then
					alive = false
				end
			end
			if x >= 1 then
				if e.reverses and e.forward then
					e.forward = false
					e.t = 0
				elseif e.repeats == -1 or e.repeats > 0 then
					if e.repeats > 0 then
						e.repeats -= 1
					end
					e.forward = true
					e.t = 0
				else
					table.remove(active, i)
					e.tween.Completed:Fire(roblox.Enum.PlaybackState.Completed)
				end
			elseif not alive or next(e.goals) == nil then
				table.remove(active, i)
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Fisica aproximada
------------------------------------------------------------------------------

local bodies = {} -- piezas sueltas creadas tras activar la fisica
local welds = {} -- [rootProxy] = { child proxies }
local trampolines = {}

-- Altura del suelo en (x, z)
function Sim.groundAt(x, z)
	for _, tr in ipairs(trampolines) do
		local dx, dz = x - tr.x, z - tr.z
		if dx * dx + dz * dz < tr.r * tr.r then
			return tr.top, tr
		end
	end
	if x * x + z * z < 58 * 58 then
		return 0.6, nil
	end
	return 0.3, nil
end

function Sim.enablePhysics(H, game)
	for _, mat in ipairs(game:GetService("CollectionService"):GetTagged("TE_Trampoline")) do
		local p = mat.CFrame.Position
		table.insert(trampolines, { x = p.X, z = p.Z, r = 4.8, top = p.Y + 0.15, mat = mat })
	end
	H.onCreate = function(proxy, className)
		if className == "Part" or className == "WedgePart" then
			table.insert(bodies, proxy)
		elseif className == "WeldConstraint" then
			table.insert(welds, proxy)
		end
	end
	local offsets = {} -- [weld] = offset (Part1 respecto a Part0)
	table.insert(H.frameHooks, function(dt)
		-- Ensamblajes soldados: Part1 sigue a Part0
		local followers = {}
		for i = #welds, 1, -1 do
			local ok, p0, p1 = pcall(function()
				return welds[i].Part0, welds[i].Part1
			end)
			if not ok or not p0 or not p1 or not p0.Parent or not p1.Parent then
				table.remove(welds, i)
			end
		end
		for _, w in ipairs(welds) do
			local p0, p1 = w.Part0, w.Part1
			if p0 and p1 and p0.Parent and p1.Parent then
				followers[p1] = true
				if not offsets[w] then
					offsets[w] = p0.CFrame:ToObjectSpace(p1.CFrame)
				end
			end
		end
		for i = #bodies, 1, -1 do
			local b = bodies[i]
			local okState, inWorld, isAnchored = pcall(function()
				return b.Parent ~= nil and b:IsDescendantOf(H.workspace), b.Anchored
			end)
			if not okState or not inWorld then
				table.remove(bodies, i)
			elseif not isAnchored and not followers[b] then
				local v = b.AssemblyLinearVelocity
				local w = b.AssemblyAngularVelocity
				local cf = b.CFrame
				v += Vector3.new(0, -GRAVITY * dt, 0)
				local pos = cf.Position + v * dt
				local half = math.max(b.Size.Y, math.min(b.Size.X, b.Size.Z)) * 0.5
				local ground, tr = Sim.groundAt(pos.X, pos.Z)
				local rot = cf - cf.Position
				local landedOn = nil
				if pos.Y - half < ground then
					pos = Vector3.new(pos.X, ground + half, pos.Z)
					local e = 0.45
					local ok, props = pcall(function()
						return b.CustomPhysicalProperties
					end)
					if ok and props then
						e = props.Elasticity
					end
					if v.Y < -4 then
						v = Vector3.new(v.X * 0.75, -v.Y * e, v.Z * 0.75)
						w = w * 0.6
					else
						v = Vector3.new(v.X * 0.85, 0, v.Z * 0.85)
						w = w * 0.8
						-- se va asentando: tiende a quedar plano
						rot = rot:Lerp(CFrame.Angles(0, select(2, rot:ToEulerAnglesYXZ()), 0), math.min(1, dt * 6))
					end
					if tr and v.Y >= 0 then
						landedOn = tr
					end
				end
				if w.Magnitude > 1e-3 then
					rot = CFrame.fromAxisAngle(w.Unit, w.Magnitude * dt) * rot
				end
				b.CFrame = CFrame.new(pos) * rot
				b.AssemblyLinearVelocity = v
				b.AssemblyAngularVelocity = w
				-- Touched despues de fijar la velocidad (el trampolin la sobrescribe)
				if landedOn then
					landedOn.mat.Touched:Fire(b)
				end
			end
		end
		for _, w in ipairs(welds) do
			pcall(function()
				local p0, p1 = w.Part0, w.Part1
				if p0 and p1 and offsets[w] then
					p1.CFrame = p0.CFrame * offsets[w]
				end
			end)
		end
	end)
end

-- Registra piezas existentes (p. ej. el personaje) para la fisica
function Sim.addBody(proxy)
	table.insert(bodies, proxy)
end

function Sim.addWeld(proxy)
	table.insert(welds, proxy)
end

return Sim
