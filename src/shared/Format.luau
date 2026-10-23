--!nonstrict
-- Formateo de numeros y tiempos para la interfaz.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.short(n: number): string
	n = tonumber(n) or 0
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local text
	if i == 1 then
		text = tostring(math.floor(n))
	elseif n >= 100 then
		text = string.format("%d%s", math.floor(n), SUFFIXES[i])
	elseif n >= 10 then
		text = string.format("%.1f%s", math.floor(n * 10) / 10, SUFFIXES[i])
	else
		text = string.format("%.2f%s", math.floor(n * 100) / 100, SUFFIXES[i])
	end
	text = text:gsub("%.0+([%a]+)$", "%1"):gsub("(%.%d-)0+([%a]+)$", "%1%2")
	return (negative and "-" or "") .. text
end

function Format.cash(n: number): string
	return "$" .. Format.short(n)
end

function Format.commas(n: number): string
	local s = tostring(math.floor(tonumber(n) or 0))
	local result = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if result:sub(1, 1) == "." then
		result = result:sub(2)
	end
	return result
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.percent(x: number): string
	return string.format("+%d%%", math.floor(x * 100 + 0.5))
end

return Format
