local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local combat = opts.combat
	local movement = opts.movement
	local bypass = opts.bypass

	UILib.create({
		title = "BLOODZONE",
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
								options = { "Head", "Torso", "HumanoidRootPart" },
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
							{ type = "toggle", key = "AimSkipSafe", label = "Skip Safe Players", hud = "Skip Safe" },
						},
					},
					{
						title = "Anti-Cheat",
						items = {
							{ type = "toggle", key = "ACBypass", label = "AC Bypass", hud = "AC" },
							{ type = "toggle", key = "DebugLivePrint", label = "AC Debug Log", hud = "AC Log" },
							{
								type = "hint",
								text = "Neutralizes NoNoCheat and blocks PotentialCheat reports. Speeds above 30 need AC bypass.",
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
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 10, max = 48, step = 1 },
							{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 16, max = 48, step = 1 },
							{ type = "toggle", key = "AlwaysSprint", label = "Always Sprint", hud = "Sprint" },
							{ type = "slider", key = "JumpHeight", label = "Jump Height", min = 2.5, max = 20, step = 0.1 },
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
							{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Lines" },
							{
								type = "slider",
								key = "ESPMaxDistance",
								label = "Max Distance",
								min = 200,
								max = 2500,
								step = 50,
							},
							{ type = "color", key = "ESPPlayerColor", label = "Player Color" },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
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
			elseif key == "ACBypass" then
				if bypass then
					bypass.sync()
				end
				movement.applyWalkSpeed()
				movement.ensureSpeedBoost()
			elseif key == "WalkSpeed" or key == "AlwaysSprint" or key == "SprintSpeed" or key == "JumpHeight" then
				movement.applyWalkSpeed()
				movement.ensureSpeedBoost()
			elseif key == "SilentAim" and value == true then
				combat.installCursorHook()
			end
		end,
	})
end

return M
