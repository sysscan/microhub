--[[
	1. Copy to games/your-game.lua
	2. Add entry in loader.lua GAMES with placeIds
	3. print(game.PlaceId) in the target game to get the id
]]

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local Config = {
	ExampleFeature = false,
	ExampleMode = "A",
	ExampleValue = 50,
	ExampleColor = Color3.fromRGB(99, 102, 241),
	ShowHUD = true,
}

local HubUI = UILib.create({
	title = "MY GAME",
	config = Config,
	pages = {
		{
			label = "Main",
			sections = {
				{
					title = "FEATURES",
					items = {
						{ type = "toggle", key = "ExampleFeature", label = "Example", hud = "Example" },
						{ type = "select", key = "ExampleMode", label = "Mode", options = { "A", "B", "C" } },
						{ type = "slider", key = "ExampleValue", label = "Power", min = 0, max = 100, step = 5 },
						{ type = "color", key = "ExampleColor", label = "Accent" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "ExampleFeature" then
			print("[MicroHub] ExampleFeature:", value)
		end
	end,
})

print("[MicroHub] template loaded — replace pages, Config, and callbacks with your game logic")
