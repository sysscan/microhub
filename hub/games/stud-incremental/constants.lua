return {
	GAME_BUILD = "3-exploits",
	PLACE_ID = 127675063398240,

	STUD_UPGRADES = {
		{ name = "MoreStuds", single = 1, max = 4 },
		{ name = "SpawnSpeed", single = 2, max = 5 },
		{ name = "MaxStuds", single = 3, max = 6 },
	},

	REBIRTH_UPGRADES = {
		{ name = "MoreStuds", single = 1, max = 4 },
		{ name = "MaxStuds", single = 2, max = 5 },
		{ name = "MoreRadius", single = 3, max = 6 },
	},

	POINT_UPGRADES = {
		{ name = "MoreStuds", single = 1, max = 4 },
		{ name = "StudSpawnSpeed", single = 2, max = 5 },
		{ name = "MoreStudLuck", single = 3, max = 6 },
		{ name = "RuneSpeed", single = 4, max = 7 },
	},

	BLOCK_UPGRADES = {
		{ name = "MoreBlocks", single = 1, max = 6 },
		{ name = "BlockSpawnSpeed", single = 2, max = 7 },
		{ name = "MoreStuds", single = 3, max = 8 },
		{ name = "MoreRP", single = 4, max = 9 },
		{ name = "MorePoints", single = 5, max = 10 },
		{ name = "UnlockUpgradeTree", single = 11, max = 12 },
	},

	DROPPER_UPGRADES = {
		{ name = "DenserParticles", single = 1, max = 3 },
		{ name = "MoreDroppers", single = 2, max = 4 },
	},

	FUSER_UPGRADES = {
		{ name = "UpgradeSeller", single = 1, max = 3 },
		{ name = "ParticleLimit", single = 2, max = 4 },
	},

	PLANT_UPGRADES = {
		{ name = "MoreTokens", single = 1, max = 5 },
		{ name = "GrowSpeed", single = 2, max = 6 },
		{ name = "UnlockChallengeBoard", single = 4, max = 8 },
	},

	RESEARCH_UPGRADES = {
		{ name = "FuserMaxCapacity", single = 1, max = 101, currency = "Cores" },
		{ name = "CoresConvertedClick", single = 2, max = 102, currency = "Cores" },
		{ name = "StudMultiplier", single = 3, max = 103, currency = "Cores" },
		{ name = "StudCapacity", single = 4, max = 104, currency = "Cores" },
		{ name = "StudSpawnBulk", single = 5, max = 105, currency = "Cores" },
		{ name = "PointMultiplier", single = 6, max = 106, currency = "Cores" },
		{ name = "PointMaxUpgradeLimit", single = 7, max = 107, currency = "Cores" },
		{ name = "BlockMultiplier", single = 8, max = 108, currency = "Cores" },
		{ name = "BlockMaxUpgradeLimit", single = 9, max = 109, currency = "Cores" },
		{ name = "RuneLuck", single = 10, max = 110, currency = "Cores" },
		{ name = "RuneSpeed", single = 11, max = 111, currency = "Cores" },
		{ name = "RuneBulk", single = 12, max = 112, currency = "Cores" },
		{ name = "TokensMultiplier", single = 13, max = 113, currency = "Tokens" },
		{ name = "StudMultiplier2", single = 14, max = 114, currency = "Tokens" },
	},

	WORLD2_STAR_UPGRADES = { "MoreStars", "SpawnSpeed", "MaxCapacity" },
	WORLD2_STARDUST_UPGRADES = { "ButtonSpeed", "MoreStars", "Radius" },

	PLANT_TOKEN_IDS = {
		"WHEAT_V7_ALPHA_99",
		"CARROT_X2_BETA_21",
		"STRAWBERRY_Z5_GAMMA_44",
		"BLUEBERRY_Q9_DELTA_12",
		"BLOSSOM_K3_OMEGA_88",
	},

	STAR_RARITIES = {
		Common = true,
		Uncommon = true,
		Rare = true,
		Epic = true,
		Legendary = true,
	},

	UPGRADE_TREE_ORDER = {
		{ id = "B1", multi = 0.5 },
		{ id = "B2", multi = 0.5 },
		{ id = "B3", multi = -0.1 },
		{ id = "B4", multi = 1 },
		{ id = "B5", multi = -0.1 },
		{ id = "B6", multi = 1 },
		{ id = "B7", multi = 1 },
		{ id = "P1", multi = 1 },
		{ id = "P2", multi = 1 },
		{ id = "R1", multi = 1 },
		{ id = "R2", multi = 1 },
		{ id = "R3", multi = 0.5 },
		{ id = "R4", multi = 1 },
		{ id = "R5", multi = 0.25 },
		{ id = "R6", multi = 1 },
		{ id = "S1", multi = 1 },
		{ id = "S2", multi = 0.5 },
		{ id = "S3", multi = 1 },
		{ id = "S4", multi = -0.1 },
		{ id = "S5", multi = 0.5 },
	},
}
