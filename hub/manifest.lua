--[[
	Game registry for the hub loader.

	Each entry can use:
	  - placeIds: array of PlaceIds that load the same script
	  - module: path relative to hub/ (e.g. games/warfare.lua)

	Find your PlaceId in-game: print(game.PlaceId)
	Warfare URL PlaceId: 83902709332473 (verify in your session)
]]

return {
	{
		name = "Warfare",
		module = "games/warfare.lua",
		version = "1.0.0",
		placeIds = {
			83902709332473,
		},
	},
}
