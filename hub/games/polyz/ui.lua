local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local Constants = opts.constants
	local onToggle = opts.onToggle

	if not Config or not UILib or not Constants then
		error("[POLYZ] ui.create missing config, uiLib, or constants", 0)
	end

	UILib.create({
		title = "POLYZ",
		config = Config,
		onToggle = onToggle,
		pages = {
			{
				label = "Combat",
				sections = {
					{
						title = "SILENT AIM",
						items = {
							{
								type = "toggle",
								key = "SilentAim",
								label = "Silent Aim",
								hud = "Silent",
							},
							{ type = "hint", text = "Hooks Raycast + ShootEnemy — every shot hits nearest enemy in range." },
							{ type = "toggle", key = "AimAtHead", label = "Aim At Head", hud = "Head" },
							{ type = "slider", key = "AttackRange", label = "Attack Range", min = 50, max = 500, step = 10 },
						},
					},
					{
						title = "AUTO SHOOT",
						items = {
							{ type = "toggle", key = "AutoShoot", label = "Auto Shoot Enemies", hud = "Shoot" },
							{ type = "toggle", key = "AimAssist", label = "Visible Aim Assist", hud = "Aim" },
							{ type = "toggle", key = "PierceShots", label = "Multi-Pierce Shots", hud = "Pierce" },
							{ type = "slider", key = "CombatInterval", label = "Fire Interval", min = 0.04, max = 0.5, step = 0.01 },
							{ type = "slider", key = "AimFOV", label = "Aim Assist FOV", min = 40, max = 400, step = 5 },
							{ type = "toggle", key = "ShowAimFOV", label = "Show Aim FOV Circle", hud = "FOV" },
						},
					},
					{
						title = "DEBUG",
						items = {
							{
								type = "toggle",
								key = "DebugRemotes",
								label = "Remote Debugger",
								hud = "Debug",
							},
							{
								type = "hint",
								text = "Logs ShootEnemy + silent Raycast rewrites. Errors always warn in console.",
							},
						},
					},
					{
						title = "WEAPON",
						items = {
							{ type = "toggle", key = "NoRecoil", label = "No Recoil", hud = "Recoil" },
							{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Ammo" },
							{ type = "toggle", key = "AutoReload", label = "Auto Refill Empty Mag", hud = "Reload" },
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
							{ type = "toggle", key = "EnemyESP", label = "Enemy ESP", hud = "Enemies" },
							{ type = "toggle", key = "EnemyESPBoxes", label = "Enemy Boxes", hud = "Boxes" },
							{ type = "toggle", key = "ESPSnaplines", label = "Enemy Snaplines", hud = "Lines" },
							{ type = "toggle", key = "ShowEnemyHealth", label = "Show Enemy HP", hud = "HP" },
							{ type = "toggle", key = "PlayerESP", label = "Player ESP", hud = "Players" },
						},
					},
					{
						title = "WORLD",
						items = {
							{ type = "toggle", key = "FullBright", label = "Fullbright", hud = "Bright" },
							{ type = "slider", key = "CameraFOV", label = "Camera FOV", min = 50, max = 120, step = 1 },
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
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = Constants.MAX_SAFE_WALKSPEED, step = 1 },
							{ type = "toggle", key = "AlwaysSprint", label = "Always Sprint", hud = "Sprint" },
							{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 20, max = Constants.MAX_SPRINT_SPEED, step = 1 },
							{ type = "toggle", key = "InfiniteStamina", label = "Infinite Stamina", hud = "Stamina" },
							{ type = "toggle", key = "JumpBoost", label = "Jump Boost", hud = "Jump" },
							{ type = "slider", key = "JumpPower", label = "Jump Power", min = 16, max = Constants.MAX_SAFE_JUMP, step = 1 },
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
		},
		hud = { showKey = "ShowHUD" },
	})
end

return M
