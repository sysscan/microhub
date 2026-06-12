return {
	GAME_BUILD = "7-tp-lab",
	GAME_ID = 7932544707,

	-- ReplicatedStorage.SharedAssets.Info.PlaceIds.IDMap.MainGame
	PLACE_IDS = {
		Hub = 6270290407,
		InnerWorld = 9861495985,
		ValleyOfScreams = 10626511620,
		HumanWorld = 14219489601,
		TestPlace = 119777193083785,
		SoulSocietyOutskirts = 14218523102,
		SnowyMountain = 14321102147,
		ArcticPlains = 15079707729,
		ArcticCave = 15645525857,
		SnowCamp = 18972283841,
		HuecoMundo = 11131834995,
		Wandenreich = 11780443293,
		SoulSociety = 12337012844,
		LasNoches = 11127942816,
		Tournament = 13229243486,
		MenosForest = 16914874220,
		Dangai = 17083682617,
		OutskirtsSwamp = 95787471190312,
		Matchmaking = 121345602945775,
		TradeRealm = 102123868363969,
		SoftShutdownPlace = 132224751888154,
	},

	TELEPORT_PLACES = {
		"Hub",
		"HumanWorld",
		"HuecoMundo",
		"SoulSocietyOutskirts",
		"SoulSociety",
		"LasNoches",
		"Wandenreich",
		"ArcticPlains",
		"OutskirtsSwamp",
		"MenosForest",
		"Dangai",
		"TradeRealm",
		"Matchmaking",
		"Tournament",
	},

	MISSION_CLASSES = {
		{ id = 1, label = "Errand-Class" },
		{ id = 2, label = "Low-Class" },
		{ id = 3, label = "Squad-Class" },
		{ id = 4, label = "Extreme-Class" },
	},

	FACTION_COLORS = {
		SoulReaper = Color3.fromRGB(72, 168, 255),
		Quincy = Color3.fromRGB(200, 220, 255),
		Hollow = Color3.fromRGB(180, 72, 255),
		Arrancar = Color3.fromRGB(255, 140, 72),
		DefaultEnemy = Color3.fromRGB(255, 72, 88),
	},

	HOLLOW_STAGE_COLORS = {
		Base = Color3.fromRGB(255, 120, 120),
		Adjuchas = Color3.fromRGB(255, 180, 72),
		Menos = Color3.fromRGB(200, 72, 255),
		VastoLorde = Color3.fromRGB(255, 72, 200),
	},

	BOSS_COLOR = Color3.fromRGB(255, 60, 120),
	QUEST_COLOR = Color3.fromRGB(85, 200, 255),
	CHEST_COLOR = Color3.fromRGB(255, 220, 80),

	MAX_ESP_DIST = 2500,
	FARM_RANGE = 400,

	FARM_MOVE_MODES = { "step", "walk", "instant" },
	INSTANT_TP_VARIANTS = { "flat", "mob_y", "ground", "raw" },
}
