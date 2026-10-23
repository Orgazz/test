--!nonstrict
-- Ciclo dia/noche: 10 minutos de dia y 4 de noche. Enciende farolas y ventanas.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DayNightService = {}

local DAY_SECONDS = 600
local NIGHT_SECONDS = 240
local isNight = nil

local WINDOW_DAY = Color3.fromRGB(160, 215, 245)
local WINDOW_NIGHT = Color3.fromRGB(255, 215, 130)

local function setNight(night)
	if isNight == night then
		return
	end
	isNight = night
	workspace:SetAttribute("IsNight", night)
	for _, part in ipairs(CollectionService:GetTagged("TE_Lamp")) do
		for _, l in ipairs(part:GetChildren()) do
			if l:IsA("Light") then
				l.Enabled = night
			end
		end
	end
	for _, w in ipairs(CollectionService:GetTagged("TE_Window")) do
		if w:IsA("BasePart") then
			w.Material = night and Enum.Material.Neon or Enum.Material.Glass
			w.Color = night and WINDOW_NIGHT or WINDOW_DAY
			w.Transparency = night and 0.1 or 0.15
		end
	end
	local cc = Lighting:FindFirstChild("TE_Color")
	if cc then
		cc.TintColor = night and Color3.fromRGB(205, 215, 255) or Color3.new(1, 1, 1)
	end
end

-- Aplica el estado actual a piezas nuevas (edificios construidos de noche)
function DayNightService.applyTo(model)
	if not isNight then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Light") and d.Parent and d.Parent:HasTag("TE_Lamp") then
			d.Enabled = true
		elseif d:IsA("BasePart") and d:HasTag("TE_Window") then
			d.Material = Enum.Material.Neon
			d.Color = WINDOW_NIGHT
		end
	end
end

function DayNightService.isNight()
	return isNight == true
end

function DayNightService.start()
	local cycle = DAY_SECONDS + NIGHT_SECONDS
	local t = 0
	isNight = nil
	setNight(false)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		t = (t + dt) % cycle
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local clock
		if t < DAY_SECONDS then
			-- 6:30 -> 18:30
			clock = 6.5 + 12 * (t / DAY_SECONDS)
		else
			-- 18:30 -> 6:30
			clock = (18.5 + 12 * ((t - DAY_SECONDS) / NIGHT_SECONDS)) % 24
		end
		Lighting.ClockTime = clock
		setNight(clock >= 18.2 or clock < 6.4)
		local nightFactor = 0
		if clock >= 18 or clock < 6 then
			nightFactor = 1
		elseif clock >= 17 then
			nightFactor = clock - 17
		elseif clock < 7 then
			nightFactor = 7 - clock
		end
		Lighting.Brightness = 2.6 - nightFactor * 1.4
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 155):Lerp(Color3.fromRGB(80, 85, 130), nightFactor)
	end)
end

return DayNightService
