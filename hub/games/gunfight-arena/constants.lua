return {
	GAME_BUILD = "67-modular",
	GREY_TEAM = BrickColor.new("Medium stone grey"),
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
}
