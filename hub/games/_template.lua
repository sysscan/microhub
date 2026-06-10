--[[
	Template for a new game module.

	1. Copy this file to games/your-game.lua
	2. Add an entry in manifest.lua with placeIds + module path
	3. Test with: print(game.PlaceId) in the target game

	This file is NOT loaded automatically. It is a starting point only.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

print("[YourHub] Game script loaded for", LocalPlayer.Name, "in PlaceId", game.PlaceId)

-- Put game-specific logic here.
