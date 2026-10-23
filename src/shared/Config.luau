--!nonstrict
-- Tiny Empire Tycoon :: configuracion central del juego.
-- Todos los numeros de balance, negocios, mejoras, retos y productos viven aqui.

local Config = {}

Config.GameName = "Tiny Empire Tycoon"
Config.DataStoreName = "TinyEmpire_Data_v1"
Config.MaxPlots = 8
Config.IncomeTick = 1 -- segundos entre pagos automaticos
Config.AutosaveInterval = 60
Config.StartingCash = 0

---------------------------------------------------------------------------
-- NIVELES DE IMPERIO (segun dinero total ganado en la partida actual)
---------------------------------------------------------------------------
Config.EmpireLevels = {
	{ level = 1, need = 0, title = "Emprendedor" },
	{ level = 2, need = 1_000, title = "Comerciante" },
	{ level = 3, need = 25_000, title = "Empresario" },
	{ level = 4, need = 500_000, title = "Ejecutivo" },
	{ level = 5, need = 10_000_000, title = "Magnate" },
	{ level = 6, need = 150_000_000, title = "Tiburón de los Negocios" },
	{ level = 7, need = 3_000_000_000, title = "Industrial" },
	{ level = 8, need = 25_000_000_000, title = "Leyenda del Imperio" },
}

---------------------------------------------------------------------------
-- EXPANSIONES DE PARCELA (zona 1 incluida desde el inicio)
---------------------------------------------------------------------------
Config.Expansions = {
	{ index = 1, name = "Distrito Comercial", cost = 25_000, needLevel = 3 },
	{ index = 2, name = "Zona Corporativa", cost = 8_000_000, needLevel = 5 },
}

---------------------------------------------------------------------------
-- NEGOCIOS (generadores). slot = posicion en la parcela, zone = 1..3
---------------------------------------------------------------------------
Config.MaxBusinessLevel = 5
Config.LevelIncomeMult = { 1, 2.2, 3.8, 6, 9 }
Config.LevelCostMult = { 1.5, 3.5, 7, 14 } -- coste de subir a nivel 2,3,4,5 (x coste base)

Config.Businesses = {
	{ id = "lemonade", name = "Puesto de Limonada", cost = 0, income = 2, zone = 1, slot = 1, color = Color3.fromRGB(255, 221, 64), icon = "🍋", desc = "Tu primer negocio. ¡Gratis!" },
	{ id = "foodtruck", name = "Food Truck", cost = 100, income = 5, zone = 1, slot = 2, color = Color3.fromRGB(255, 120, 80), icon = "🌮", desc = "Tacos sobre ruedas." },
	{ id = "bakery", name = "Panadería", cost = 900, income = 15, zone = 1, slot = 3, color = Color3.fromRGB(230, 170, 110), icon = "🥐", desc = "Pan recién horneado cada minuto." },
	{ id = "cafe", name = "Cafetería", cost = 7_000, income = 45, zone = 1, slot = 4, color = Color3.fromRGB(150, 95, 70), icon = "☕", desc = "Café de especialidad y wifi gratis." },
	{ id = "toystore", name = "Juguetería", cost = 50_000, income = 135, zone = 2, slot = 5, color = Color3.fromRGB(255, 105, 180), icon = "🧸", desc = "Diversión para toda la ciudad." },
	{ id = "workshop", name = "Taller", cost = 350_000, income = 400, zone = 2, slot = 6, color = Color3.fromRGB(90, 160, 220), icon = "🔧", desc = "Una pequeña fábrica artesanal." },
	{ id = "warehouse", name = "Almacén", cost = 1_800_000, income = 1_200, zone = 2, slot = 7, color = Color3.fromRGB(200, 140, 60), icon = "📦", desc = "Logística para todo tu imperio." },
	{ id = "factory", name = "Fábrica", cost = 12_000_000, income = 3_600, zone = 3, slot = 8, color = Color3.fromRGB(120, 130, 145), icon = "🏭", desc = "Producción industrial a gran escala." },
	{ id = "techlab", name = "Laboratorio Tech", cost = 50_000_000, income = 11_000, zone = 3, slot = 9, color = Color3.fromRGB(80, 220, 210), icon = "🔬", desc = "Inventos del futuro." },
	{ id = "tower", name = "Torre Corporativa", cost = 250_000_000, income = 33_000, zone = 3, slot = 10, color = Color3.fromRGB(110, 120, 255), icon = "🏢", desc = "La sede central de tu imperio." },
}

Config.BusinessById = {}
for i, b in ipairs(Config.Businesses) do
	b.order = i
	Config.BusinessById[b.id] = b
end

---------------------------------------------------------------------------
-- MEJORAS DE IMPERIO (24 mejoras en 4 niveles)
-- kind: "global" (+% a todo), "business" (multiplica un negocio),
--       "crate" (bonificacion maletines), "offline" (ganancias offline)
---------------------------------------------------------------------------
Config.UpgradeTiers = {
	{ tier = 1, name = "Startup", needLevel = 1 },
	{ tier = 2, name = "Negocio Local", needLevel = 3 },
	{ tier = 3, name = "Empresa", needLevel = 5 },
	{ tier = 4, name = "Imperio", needLevel = 6 },
}

Config.Upgrades = {
	-- Tier 1
	{ id = "u_sign", tier = 1, name = "Letrero Llamativo", cost = 250, kind = "global", value = 0.10, icon = "🪧", desc = "+10% ingresos de todos los negocios" },
	{ id = "u_lemons", tier = 1, name = "Limones Premium", cost = 400, kind = "business", target = "lemonade", value = 2, icon = "🍋", desc = "Puesto de Limonada x2" },
	{ id = "u_wheels", tier = 1, name = "Ruedas Nuevas", cost = 1_500, kind = "business", target = "foodtruck", value = 2, icon = "🛞", desc = "Food Truck x2" },
	{ id = "u_bench", tier = 1, name = "Bancos en la Acera", cost = 3_000, kind = "crate", value = 0.5, icon = "🪑", desc = "+50% dinero de los maletines" },
	{ id = "u_oven", tier = 1, name = "Horno Doble", cost = 6_000, kind = "business", target = "bakery", value = 2, icon = "🔥", desc = "Panadería x2" },
	{ id = "u_flyers", tier = 1, name = "Publicidad Local", cost = 12_000, kind = "global", value = 0.15, icon = "📰", desc = "+15% ingresos de todos los negocios" },
	-- Tier 2
	{ id = "u_beans", tier = 2, name = "Café de Especialidad", cost = 40_000, kind = "business", target = "cafe", value = 2, icon = "☕", desc = "Cafetería x2" },
	{ id = "u_display", tier = 2, name = "Vitrinas Brillantes", cost = 250_000, kind = "business", target = "toystore", value = 2, icon = "✨", desc = "Juguetería x2" },
	{ id = "u_vans", tier = 2, name = "Furgonetas de Reparto", cost = 400_000, kind = "global", value = 0.20, visual = "vans", icon = "🚚", desc = "+20% ingresos y furgonetas en tu parcela" },
	{ id = "u_manager", tier = 2, name = "Gerente Nocturno", cost = 600_000, kind = "offline", value = 0.5, icon = "🌙", desc = "Ganancias offline al 50% (máx. 4 h)" },
	{ id = "u_tools", tier = 2, name = "Herramientas Eléctricas", cost = 1_500_000, kind = "business", target = "workshop", value = 2, icon = "🔧", desc = "Taller x2" },
	{ id = "u_solar", tier = 2, name = "Paneles Solares", cost = 3_000_000, kind = "global", value = 0.15, visual = "solar", icon = "☀️", desc = "+15% ingresos y paneles solares" },
	-- Tier 3
	{ id = "u_robots", tier = 3, name = "Estanterías Robotizadas", cost = 12_000_000, kind = "business", target = "warehouse", value = 2, icon = "🤖", desc = "Almacén x2" },
	{ id = "u_carts", tier = 3, name = "Maletines Dorados", cost = 15_000_000, kind = "crate", value = 2, icon = "💼", desc = "+200% dinero de los maletines" },
	{ id = "u_social", tier = 3, name = "Campaña en Redes", cost = 30_000_000, kind = "global", value = 0.25, icon = "📱", desc = "+25% ingresos de todos los negocios" },
	{ id = "u_conveyor", tier = 3, name = "Cinta Turbo", cost = 60_000_000, kind = "business", target = "factory", value = 2, icon = "⚙️", desc = "Fábrica x2" },
	{ id = "u_logistics", tier = 3, name = "Logística Inteligente", cost = 100_000_000, kind = "global", value = 0.25, icon = "🗺️", desc = "+25% ingresos de todos los negocios" },
	{ id = "u_quantum", tier = 3, name = "Laboratorio Cuántico", cost = 250_000_000, kind = "business", target = "techlab", value = 2, icon = "🧪", desc = "Laboratorio Tech x2" },
	-- Tier 4
	{ id = "u_brand", tier = 4, name = "Marca Global", cost = 400_000_000, kind = "global", value = 0.5, icon = "🌍", desc = "+50% ingresos de todos los negocios" },
	{ id = "u_elevator", tier = 4, name = "Ascensores Exprés", cost = 1_200_000_000, kind = "business", target = "tower", value = 2, icon = "🛗", desc = "Torre Corporativa x2" },
	{ id = "u_ai", tier = 4, name = "Inteligencia Artificial", cost = 2_000_000_000, kind = "global", value = 0.3, icon = "🧠", desc = "+30% ingresos de todos los negocios" },
	{ id = "u_heli", tier = 4, name = "Helipuerto", cost = 3_500_000_000, kind = "global", value = 0.4, visual = "heli", icon = "🚁", desc = "+40% ingresos y un helicóptero" },
	{ id = "u_stocks", tier = 4, name = "Bolsa de Valores", cost = 7_000_000_000, kind = "global", value = 0.6, icon = "📈", desc = "+60% ingresos de todos los negocios" },
	{ id = "u_statue", tier = 4, name = "Monumento al Fundador", cost = 15_000_000_000, kind = "global", value = 1.0, visual = "statue", icon = "🗽", desc = "+100% ingresos y una estatua dorada" },
}

Config.UpgradeById = {}
for i, u in ipairs(Config.Upgrades) do
	u.order = i
	Config.UpgradeById[u.id] = u
end

---------------------------------------------------------------------------
-- FRANQUICIA (reinicio opcional con bonus permanente)
---------------------------------------------------------------------------
Config.Franchise = {
	needEarned = 25_000_000_000, -- dinero ganado en la partida actual
	bonusPerFranchise = 0.5, -- +50% permanente por franquicia
}

---------------------------------------------------------------------------
-- GANANCIAS OFFLINE
---------------------------------------------------------------------------
Config.Offline = {
	baseRate = 0.2, -- 20% del ingreso
	baseMaxSeconds = 2 * 3600,
	managerMaxSeconds = 4 * 3600,
	minSeconds = 60,
}

---------------------------------------------------------------------------
-- MALETINES DE BONIFICACION (plaza central)
---------------------------------------------------------------------------
Config.Crates = {
	spawnInterval = 20,
	maxActive = 5,
	incomeSeconds = 30, -- recompensa = ingreso/s * 30
	minReward = 40,
}

---------------------------------------------------------------------------
-- OBJETIVOS DE EXPANSION (secuenciales, con recompensa)
---------------------------------------------------------------------------
Config.Goals = {
	{ id = "g_two", text = "Ten 2 negocios", kind = "businesses", target = 2, reward = 50 },
	{ id = "g_lvl2", text = "Mejora un negocio a nivel 2", kind = "maxLevel", target = 2, reward = 150 },
	{ id = "g_four", text = "Ten 4 negocios", kind = "businesses", target = 4, reward = 3_000 },
	{ id = "g_up3", text = "Compra 3 mejoras de imperio", kind = "upgrades", target = 3, reward = 2_000 },
	{ id = "g_exp1", text = "Desbloquea el Distrito Comercial", kind = "expansions", target = 1, reward = 8_000 },
	{ id = "g_six", text = "Ten 6 negocios", kind = "businesses", target = 6, reward = 150_000 },
	{ id = "g_lvl5", text = "Lleva un negocio a nivel 5", kind = "maxLevel", target = 5, reward = 100_000 },
	{ id = "g_seven", text = "Ten 7 negocios", kind = "businesses", target = 7, reward = 1_000_000 },
	{ id = "g_exp2", text = "Desbloquea la Zona Corporativa", kind = "expansions", target = 2, reward = 3_000_000 },
	{ id = "g_up12", text = "Compra 12 mejoras de imperio", kind = "upgrades", target = 12, reward = 20_000_000 },
	{ id = "g_ten", text = "Construye la Torre Corporativa", kind = "businesses", target = 10, reward = 500_000_000 },
	{ id = "g_allmax", text = "Todos los negocios a nivel 5", kind = "allMax", target = 10, reward = 2_000_000_000 },
	{ id = "g_up24", text = "Compra las 24 mejoras", kind = "upgrades", target = 24, reward = 5_000_000_000 },
	{ id = "g_fran", text = "Abre tu primera franquicia", kind = "franchise", target = 1, reward = 1_000_000 },
}

---------------------------------------------------------------------------
-- RETOS DIARIOS (se eligen 3 al dia, reinicio 00:00 UTC)
---------------------------------------------------------------------------
Config.DailyCount = 3
Config.DailyPool = {
	{ id = "d_earn", text = "Gana %s", kind = "earn", incomeSeconds = 900, min = 500 },
	{ id = "d_levels", text = "Sube de nivel negocios %d veces", kind = "levelUps", target = 3 },
	{ id = "d_upgrades", text = "Compra %d mejoras de imperio", kind = "upgrades", target = 2 },
	{ id = "d_crates", text = "Recoge %d maletines en la plaza", kind = "crates", target = 4 },
	{ id = "d_play", text = "Juega %d minutos", kind = "minutes", target = 15 },
	{ id = "d_plaza", text = "Visita la plaza central", kind = "plaza", target = 1 },
	{ id = "d_build", text = "Construye o mejora %d edificios", kind = "builds", target = 4 },
}
Config.DailyRewardIncomeSeconds = 300
Config.DailyMinReward = 300
Config.DailyAllBonusMult = 2 -- recompensa extra al completar los 3

---------------------------------------------------------------------------
-- MONETIZACION
-- Sustituye los IDs 0 por los IDs reales de tu experiencia (ver README).
-- Con ID 0 y en Roblox Studio, las compras se SIMULAN para poder probarlas.
---------------------------------------------------------------------------
Config.GamePasses = {
	decor = { id = 0, price = 39, name = "Decoraciones Premium", icon = "⛲", desc = "Fuente, estatuas, palmeras y arco de neón en tu parcela." },
	theme = { id = 0, price = 99, name = "Tema Ciudad Dorada", icon = "👑", desc = "Edificios dorados y de neón exclusivos en tu parcela." },
	x2 = { id = 0, price = 149, name = "Productividad x2", icon = "⚡", desc = "Duplica para siempre los ingresos de TUS negocios." },
}
Config.GamePassOrder = { "decor", "theme", "x2" }

Config.Products = {
	small = { id = 0, price = 29, name = "Maletín de Efectivo", icon = "💵", incomeMinutes = 20, min = 2_500 },
	medium = { id = 0, price = 49, name = "Caja Fuerte", icon = "💰", incomeMinutes = 45, min = 7_500 },
	large = { id = 0, price = 79, name = "Camión Blindado", icon = "🚛", incomeMinutes = 90, min = 20_000 },
}
Config.ProductOrder = { "small", "medium", "large" }

-- Zona de la plaza (centro del mapa)
Config.PlazaRadius = 58

return Config
