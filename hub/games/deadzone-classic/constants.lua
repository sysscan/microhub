return {
	GAME_BUILD = "11-deadzone-classic",

	MAX_SAFE_WALK = 22.1,
	MAX_BOOST_VEL = 22,
	MAX_SAFE_JUMP = 27,

	WHITE = Color3.fromRGB(248, 250, 252),
	DIM = Color3.fromRGB(148, 156, 168),
	BAR_BG = Color3.fromRGB(10, 12, 16),
	BACKDROP = Color3.fromRGB(8, 10, 14),
	CORNER_OFFSETS = {
		Vector3.new(1, 1, 1),
		Vector3.new(1, 1, -1),
		Vector3.new(1, -1, 1),
		Vector3.new(1, -1, -1),
		Vector3.new(-1, 1, 1),
		Vector3.new(-1, 1, -1),
		Vector3.new(-1, -1, 1),
		Vector3.new(-1, -1, -1),
	},
	ESP_DRAWABLES = { "backdrop", "name", "hpOutline", "hpFill", "dist", "line" },

	ZONE_NAMES = { "__bankzone", "__storezone", "__missionzone", "__stylistzone" },
}
