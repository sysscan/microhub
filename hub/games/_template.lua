--[[
	1. Copy to games/your-game.lua
	2. Add entry in manifest.lua with placeIds
	3. print(game.PlaceId) in the target game to get the id
]]

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local Config = {
	ExampleFeature = false,
	ShowHUD = true,
}

local HubUI = UILib.create({
	title = "MY GAME",
	config = Config,
	sections = {
		{
			title = "FEATURES",
			toggles = {
				{ key = "ExampleFeature", label = "Example", hud = "Example" },
				{ key = "ShowHUD", label = "Module HUD", hud = nil },
			},
		},
	},
	footer = {
		items = {
			{ type = "hint", text = "RightShift toggles menu" },
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "ExampleFeature" then
			print("[MicroHub] ExampleFeature:", value)
		end
	end,
})

print("[MicroHub] template loaded — replace Config, sections, and onToggle with your game logic")
