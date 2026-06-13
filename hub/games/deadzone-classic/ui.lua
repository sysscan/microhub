local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local combat = opts.combat
	local movement = opts.movement

	UILib.create({
		title = "DEADZONE CLASSIC",
		config = Config,
		pages = {
			{
				label = "Combat",
				sections = {
					{
						title = "Aim",
						items = {
							{ type = "toggle", key = "Aimbot", label = "Aimbot", hud = "Aimbot" },
							{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent" },
							{ type = "toggle", key = "AimHold", label = "Hold RMB", hud = "Hold RMB" },
							{ type = "toggle", key = "AimSticky", label = "Sticky Aim", hud = "Sticky" },
							{
								type = "select",
								key = "AimPart",
								label = "Bone",
								options = { "Head", "Torso" },
							},
							{
								type = "slider",
								key = "AimFOV",
								label = "FOV",
								min = 20,
								max = 500,
								step = 10,
								onChange = combat.setAimFOV,
							},
							{ type = "slider", key = "AimSmooth", label = "Smoothness", min = 1, max = 100, step = 1 },
							{ type = "toggle", key = "AimFOVCircle", label = "FOV Circle", hud = "FOV" },
						},
					},
					{
						title = "Anti-Cheat",
						items = {
							{ type = "toggle", key = "ACBypass", label = "Block AC Reports", hud = "AC Bypass" },
							{
								type = "hint",
								text = "Blocks ChangePosture codes 5–9 via FireServer hook only (executor-safe).",
							},
						},
					},
				},
			},
			{
				label = "Movement",
				sections = {
					{
						title = "Speed",
						items = {
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 8, max = 50, step = 1 },
							{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 16, max = 50, step = 1 },
							{ type = "toggle", key = "AlwaysSprint", label = "Always Sprint", hud = "Sprint" },
							{ type = "slider", key = "JumpPower", label = "Jump Power", min = 16, max = 50, step = 1 },
							{ type = "toggle", key = "NoClip", label = "NoClip", hud = "NoClip" },
							{ type = "toggle", key = "FullBright", label = "Full Bright", hud = "Bright" },
						},
					},
				},
			},
			{
				label = "Visual",
				sections = {
					{
						title = "ESP",
						items = {
							{ type = "toggle", key = "ESP", label = "Player ESP", hud = "ESP" },
							{ type = "toggle", key = "ESPItems", label = "Item ESP", hud = "Items" },
							{ type = "toggle", key = "ESPZones", label = "Zone ESP", hud = "Zones" },
							{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Lines" },
							{ type = "color", key = "ESPPlayerColor", label = "Player Color" },
							{ type = "color", key = "ESPItemColor", label = "Item Color" },
							{ type = "color", key = "ESPZoneColor", label = "Zone Color" },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						},
					},
				},
			},
			{
				label = "Automation",
				sections = {
					{
						title = "Loot",
						items = {
							{ type = "toggle", key = "AutoLoot", label = "Auto Loot", hud = "Loot" },
							{ type = "slider", key = "AutoLootRange", label = "Loot Range", min = 6, max = 20, step = 1 },
						},
					},
					{
						title = "Survival",
						items = {
							{ type = "toggle", key = "AutoHeal", label = "Auto Heal", hud = "Heal" },
							{ type = "slider", key = "AutoHealBelow", label = "Heal Below Blood", min = 20, max = 95, step = 5 },
							{ type = "toggle", key = "AutoEat", label = "Auto Eat", hud = "Eat" },
							{ type = "slider", key = "AutoEatAbove", label = "Eat Above Hunger", min = 20, max = 90, step = 5 },
							{ type = "toggle", key = "AutoDrink", label = "Auto Drink", hud = "Drink" },
							{ type = "slider", key = "AutoDrinkAbove", label = "Drink Above Thirst", min = 20, max = 90, step = 5 },
						},
					},
					{
						title = "World",
						items = {
							{ type = "toggle", key = "TeleportToggle", label = "Toggle Safezone TP", hud = "TP" },
							{
								type = "hint",
								text = "Calls Teleport remote every 12s while enabled.",
							},
						},
					},
				},
			},
		},
		hud = { showKey = "ShowHUD" },
		onToggle = function(key, value)
			if key == "NoClip" then
				movement.setNoClip(value == true)
			elseif key == "FullBright" then
				movement.applyFullBright()
			elseif key == "WalkSpeed" or key == "AlwaysSprint" or key == "SprintSpeed" or key == "JumpPower" or key == "ACBypass" then
				movement.applyWalkSpeed()
			end
		end,
	})
end

return M
