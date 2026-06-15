local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local Constants = opts.constants
	local remotes = opts.remotes
	local automation = opts.automation
	local onToggle = opts.onToggle

	if not Config or not UILib or not Constants then
		error("[Altered Reality] ui.create missing config, uiLib, or constants", 0)
	end

	UILib.create({
		title = "Altered Reality",
		config = Config,
		onToggle = onToggle,
		pages = {
			{
				label = "Combat",
				sections = {
					{
						title = "AIM",
						items = {
							{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent" },
							{ type = "toggle", key = "AutoShoot", label = "Auto Shoot", hud = "Shoot" },
							{ type = "toggle", key = "AimAtHead", label = "Aim At Head", hud = "Head" },
							{
								type = "hint",
								text = "Auto Shoot fires continuously. Silent Aim fires while holding LMB.",
							},
							{ type = "slider", key = "AttackRange", label = "Attack Range", min = 50, max = 750, step = 10 },
							{ type = "slider", key = "CombatInterval", label = "Shot Interval Cap", min = 0.04, max = 0.5, step = 0.01 },
						},
					},
				},
			},
			{
				label = "Movement",
				sections = {
					{
						title = "SPEED",
						items = {
							{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed" },
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 8, max = Constants.MAX_WALK_SPEED, step = 1 },
							{ type = "toggle", key = "AlwaysSprint", label = "Always Sprint", hud = "Sprint" },
							{ type = "toggle", key = "InfiniteStamina", label = "Infinite Stamina", hud = "Stamina" },
						},
					},
					{
						title = "TRAVEL",
						items = {
							{ type = "toggle", key = "NoClip", label = "NoClip", hud = "Clip" },
							{ type = "toggle", key = "Fly", label = "Fly", hud = "Fly" },
							{ type = "slider", key = "FlySpeed", label = "Fly Speed", min = 20, max = Constants.MAX_FLY_SPEED, step = 5 },
						},
					},
					{
						title = "MISC",
						items = {
							{ type = "toggle", key = "AntiAfk", label = "Anti AFK", hud = "AFK" },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						},
					},
				},
			},
			{
				label = "Visuals",
				sections = {
					{
						title = "ESP",
						items = {
							{ type = "toggle", key = "PlayerESP", label = "Player ESP", hud = "Players" },
							{ type = "toggle", key = "PlayerESPBoxes", label = "Player Boxes", hud = "Boxes" },
							{ type = "toggle", key = "ESPSnaplines", label = "Player Snaplines", hud = "Lines" },
							{ type = "toggle", key = "ShowPlayerHealth", label = "Show Player HP", hud = "HP" },
							{ type = "toggle", key = "LootESP", label = "Loot ESP", hud = "Loot" },
						},
					},
					{
						title = "WORLD",
						items = {
							{ type = "toggle", key = "FullBright", label = "Fullbright", hud = "Bright" },
						},
					},
				},
			},
			{
				label = "Loot",
				sections = {
					{
						title = "AUTO LOOT",
						items = {
							{ type = "toggle", key = "AutoLoot", label = "Auto Pickup Loot", hud = "AutoLoot" },
							{ type = "slider", key = "AutoLootRange", label = "Pickup Range", min = 4, max = 40, step = 1 },
							{
								type = "hint",
								text = "Uses PickupLoot remote when spawned in-world.",
							},
						},
					},
					{
						title = "ACTIONS",
						items = {
							{ type = "button", label = "Log Inventory", onClick = automation.logInventory },
							{
								type = "button",
								label = "Spawn Character",
								onClick = function()
									remotes.spawnCharacter()
								end,
							},
						},
					},
				},
			},
		},
		hud = { showKey = "ShowHUD" },
	})
end

return M
