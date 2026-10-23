--!nonstrict
-- Fisica del lado del cliente (el personaje local es propiedad del cliente):
--  * Trampolines: impulso vertical + lona con muelle amortiguado
--  * Sprint (Shift o boton tactil) con aceleracion suave y cambio de FOV
--  * Rafagas de monedas y escombros: piezas fisicas que rebotan y se desvanecen
--    (grupo de colision TE_Effects: chocan con el suelo pero no con jugadores)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.UI.Theme)

local Physics = {}

local player = Players.LocalPlayer
local springs = {} -- lonas de trampolin con muelle
local effects = {} -- piezas fisicas temporales
local MAX_EFFECTS = 90

Physics.WALK_SPEED = 16
Physics.SPRINT_SPEED = 26
Physics.BASE_FOV = 70
Physics.SPRINT_FOV = 80

------------------------------------------------------------------------------
-- Trampolines
------------------------------------------------------------------------------

local function setupTrampoline(mat)
	if springs[mat] then
		return
	end
	local spring = { part = mat, base = mat.CFrame, x = 0, v = 0, debounce = 0 }
	springs[mat] = spring
	mat.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return
		end
		local now = os.clock()
		if now - spring.debounce < 0.35 then
			return
		end
		spring.debounce = now
		local power = mat:GetAttribute("Power") or 110
		local vel = root.AssemblyLinearVelocity
		-- Conserva el impulso horizontal y suma un poco si se llega corriendo
		root.AssemblyLinearVelocity = Vector3.new(vel.X * 1.1, power, vel.Z * 1.1)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		spring.v -= 22 -- la lona se hunde
		Theme.play("coin")
	end)
end

local function stepSprings(dt)
	for mat, s in pairs(springs) do
		if mat.Parent then
			-- Oscilador amortiguado: x'' = -k x - c x'
			local k, c = 220, 9
			local acc = -k * s.x - c * s.v
			s.v += acc * dt
			s.x += s.v * dt
			if math.abs(s.x) > 0.001 or math.abs(s.v) > 0.01 then
				mat.CFrame = s.base * CFrame.new(math.clamp(s.x, -1.2, 0.6), 0, 0) -- eje X del cilindro = vertical
			end
		else
			springs[mat] = nil
		end
	end
end

------------------------------------------------------------------------------
-- Sprint
------------------------------------------------------------------------------

local sprinting = false
local currentSpeed = Physics.WALK_SPEED

function Physics.setSprint(on)
	sprinting = on
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { FieldOfView = on and Physics.SPRINT_FOV or Physics.BASE_FOV }):Play()
	end
end

function Physics.isSprinting()
	return sprinting
end

local function stepSprint(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local target = sprinting and Physics.SPRINT_SPEED or Physics.WALK_SPEED
	-- Aceleracion progresiva en lugar de un salto brusco de velocidad
	currentSpeed += (target - currentSpeed) * math.min(1, dt * 4)
	if math.abs(humanoid.WalkSpeed - currentSpeed) > 0.05 then
		humanoid.WalkSpeed = currentSpeed
	end
end

------------------------------------------------------------------------------
-- Rafagas de piezas fisicas
------------------------------------------------------------------------------

local function spawnEffect(cf, size, color, material, velocity, angular, lifetime, shape)
	if #effects >= MAX_EFFECTS then
		local old = table.remove(effects, 1)
		if old.part.Parent then
			old.part:Destroy()
		end
	end
	local p = Instance.new("Part")
	p.Name = "TE_Effect"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CollisionGroup = "TE_Effects"
	p.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.4, 0.5, 1, 1)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = workspace
	p.AssemblyLinearVelocity = velocity
	p.AssemblyAngularVelocity = angular
	table.insert(effects, { part = p, born = os.clock(), life = lifetime })
	return p
end

local rng = Random.new()

-- Monedas que saltan y rebotan
function Physics.coinBurst(position, count)
	count = count or 12
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local out = rng:NextNumber(6, 14)
		local vel = Vector3.new(math.cos(a) * out, rng:NextNumber(26, 40), math.sin(a) * out)
		local cf = CFrame.new(position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, a, math.rad(90))
		spawnEffect(cf, Vector3.new(0.25, 1.3, 1.3), Color3.fromRGB(255, 205, 60), Enum.Material.Foil, vel, Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12)), rng:NextNumber(1.6, 2.4), Enum.PartType.Cylinder)
	end
end

-- Escombros de obra al construir/mejorar (ladrillos y tablas)
local DEBRIS_COLORS = {
	Color3.fromRGB(190, 110, 80),
	Color3.fromRGB(170, 130, 90),
	Color3.fromRGB(220, 220, 225),
	Color3.fromRGB(255, 200, 60),
}
function Physics.debrisBurst(position, count)
	count = count or 14
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local out = rng:NextNumber(5, 16)
		local size = Vector3.new(rng:NextNumber(0.5, 1.4), rng:NextNumber(0.4, 0.8), rng:NextNumber(0.5, 1.6))
		local vel = Vector3.new(math.cos(a) * out, rng:NextNumber(18, 34), math.sin(a) * out)
		local cf = CFrame.new(position + Vector3.new(math.cos(a) * 3, 1.5, math.sin(a) * 3)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local material = rng:NextNumber() < 0.5 and Enum.Material.Brick or Enum.Material.Wood
		spawnEffect(cf, size, DEBRIS_COLORS[rng:NextInteger(1, #DEBRIS_COLORS)], material, vel, Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)), rng:NextNumber(1.8, 2.6))
	end
end

local function stepEffects()
	local now = os.clock()
	for i = #effects, 1, -1 do
		local e = effects[i]
		local age = now - e.born
		if not e.part.Parent then
			table.remove(effects, i)
		elseif age > e.life then
			e.part:Destroy()
			table.remove(effects, i)
		elseif age > e.life - 0.5 then
			-- desvanecer y encoger al final
			local k = (e.life - age) / 0.5
			e.part.LocalTransparencyModifier = 1 - k
		end
	end
end

------------------------------------------------------------------------------

function Physics.start(hud)
	for _, mat in ipairs(CollectionService:GetTagged("TE_Trampoline")) do
		setupTrampoline(mat)
	end
	CollectionService:GetInstanceAddedSignal("TE_Trampoline"):Connect(setupTrampoline)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			Physics.setSprint(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			Physics.setSprint(false)
		end
	end)
	-- Boton de sprint para moviles
	if UserInputService.TouchEnabled and hud then
		local btn = Theme.button({
			Name = "SprintButton",
			Text = "🏃",
			Size = UDim2.fromOffset(74, 74),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -150, 1, -150),
			Color = Theme.C.purple,
			Radius = 37,
			MaxText = 36,
			Parent = hud,
			OnClick = function()
				Physics.setSprint(not sprinting)
			end,
		})
		local _ = btn
	end
	player.CharacterAdded:Connect(function()
		currentSpeed = Physics.WALK_SPEED
	end)

	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		stepSprings(dt)
		stepSprint(dt)
		stepEffects()
	end)
end

Physics._effects = effects
Physics._springs = springs

return Physics
