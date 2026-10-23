--!nonstrict
-- Paletas de los 4 barrios y del tema premium.

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Palettes = {}

Palettes.Neighborhoods = {
	{
		id = "pastel",
		name = "Barrio Pastel",
		ground = rgb(140, 210, 120),
		path = rgb(245, 215, 220),
		curb = rgb(255, 255, 255),
		wall = rgb(255, 210, 225),
		wall2 = rgb(200, 230, 255),
		roof = rgb(235, 110, 140),
		trim = rgb(255, 255, 255),
		accent = rgb(255, 140, 180),
		accent2 = rgb(140, 200, 255),
		tree = "blossom",
		treeColor = rgb(255, 175, 205),
		fence = rgb(255, 255, 255),
		lamp = rgb(255, 200, 230),
		groundMaterial = Enum.Material.Grass,
		pathMaterial = Enum.Material.Pebble,
	},
	{
		id = "green",
		name = "Distrito Verde",
		ground = rgb(95, 165, 85),
		path = rgb(190, 165, 120),
		curb = rgb(130, 105, 80),
		wall = rgb(235, 225, 195),
		wall2 = rgb(170, 200, 150),
		roof = rgb(70, 120, 80),
		trim = rgb(120, 85, 60),
		accent = rgb(110, 190, 90),
		accent2 = rgb(250, 210, 90),
		tree = "pine",
		treeColor = rgb(50, 130, 75),
		fence = rgb(140, 100, 65),
		lamp = rgb(255, 230, 160),
		groundMaterial = Enum.Material.Grass,
		pathMaterial = Enum.Material.Cobblestone,
	},
	{
		id = "industrial",
		name = "Puerto Industrial",
		ground = rgb(120, 150, 110),
		path = rgb(165, 165, 170),
		curb = rgb(90, 90, 95),
		wall = rgb(200, 120, 90),
		wall2 = rgb(150, 170, 190),
		roof = rgb(70, 75, 85),
		trim = rgb(240, 190, 60),
		accent = rgb(255, 170, 40),
		accent2 = rgb(80, 150, 220),
		tree = "round",
		treeColor = rgb(85, 150, 85),
		fence = rgb(110, 110, 120),
		lamp = rgb(255, 210, 140),
		groundMaterial = Enum.Material.Grass,
		pathMaterial = Enum.Material.Concrete,
	},
	{
		id = "coast",
		name = "Costa Sol",
		ground = rgb(150, 205, 110),
		path = rgb(240, 220, 170),
		curb = rgb(255, 245, 225),
		wall = rgb(255, 245, 220),
		wall2 = rgb(130, 220, 215),
		roof = rgb(240, 130, 70),
		trim = rgb(40, 170, 190),
		accent = rgb(40, 190, 200),
		accent2 = rgb(255, 150, 90),
		tree = "palm",
		treeColor = rgb(70, 175, 80),
		fence = rgb(240, 230, 210),
		lamp = rgb(200, 255, 250),
		groundMaterial = Enum.Material.Grass,
		pathMaterial = Enum.Material.Sand,
	},
}

-- Tema premium "Ciudad Dorada" (solo cambia el aspecto de TU parcela)
Palettes.Premium = {
	id = "gold",
	name = "Ciudad Dorada",
	wall = rgb(255, 240, 200),
	wall2 = rgb(40, 35, 60),
	roof = rgb(30, 25, 45),
	trim = rgb(255, 200, 60),
	accent = rgb(255, 200, 60),
	accent2 = rgb(190, 90, 255),
	glow = rgb(255, 210, 90),
}

function Palettes.forPlot(neighborhood, premium: boolean)
	local p = table.clone(neighborhood)
	if premium then
		for k, v in pairs(Palettes.Premium) do
			if k ~= "id" and k ~= "name" then
				p[k] = v
			end
		end
		p.premium = true
	end
	return p
end

return Palettes
