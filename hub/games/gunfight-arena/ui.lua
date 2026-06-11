local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local combat = opts.combat

	UILib.create({
		title = "GUNFIGHT ARENA",
		config = Config,
		pages = {
			{
				label = "Combat",
				sections = {
					{
						title = "Aimbot",
						items = {
							{ type = "toggle", key = "Aimbot", label = "Aimbot", hud = "Aimbot" },
							{ type = "toggle", key = "AimTeamCheck", label = "Team Check", hud = "Team Check" },
							{ type = "toggle", key = "AimHold", label = "Hold RMB", hud = "Hold RMB" },
							{ type = "toggle", key = "AimSticky", label = "Sticky Aim", hud = "Sticky Aim" },
							{
								type = "select",
								key = "AimPart",
								label = "Bone",
								options = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
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
							{ type = "toggle", key = "AimFOVCircle", label = "FOV Circle", hud = "FOV Circle" },
							{
								type = "hint",
								text = "Sticky locks target until RMB release or death. Smoothness: 1 snap, 100 glide.",
							},
						},
					},
					{
						title = "Silent Aim",
						items = {
							{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
							{
								type = "hint",
								text = "Redirects aim via MouseHitSpot + no spread. Use 3rd person. FOV + team check.",
							},
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
							{ type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
							{ type = "toggle", key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
							{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
							{ type = "label", text = "ESP colors — tap swatch" },
							{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
							{ type = "color", key = "ESPAllyColor", label = "Ally" },
							{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						},
					},
				},
			},
		},
		hud = { showKey = "ShowHUD" },
	})
end

return M
