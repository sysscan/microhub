local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local Constants = opts.constants
	local lobby = opts.lobby
	local onToggle = opts.onToggle
	local onChange = opts.onChange

	if not Config or not UILib or not Constants or not lobby then
		error("[POLYZ] ui.create missing config, uiLib, constants, or lobby", 0)
	end

	local camoGunOptions = lobby.getCamoGunOptions()
	local camoSelectOptions = {}
	for _, gunName in camoGunOptions do
		table.insert(camoSelectOptions, gunName)
	end

	UILib.create({
		title = "POLYZ",
		config = Config,
		onToggle = onToggle,
		onChange = onChange,
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
							{
								type = "select",
								key = "TargetMode",
								label = "Target Mode",
								options = { "Closest", "FOV", "Boss", "Lowest HP" },
							},
							{
								type = "hint",
								text = "Closest / FOV / Boss priority / Lowest HP — used by silent aim, auto shoot, and pierce.",
							},
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
							{ type = "toggle", key = "NoSpread", label = "No Spread", hud = "Spread" },
							{
								type = "hint",
								text = "Weapon shots use exact crosshair direction (hooks PlayerControls raycasts).",
							},
							{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Ammo" },
							{ type = "toggle", key = "AutoReload", label = "Auto Refill Empty Mag", hud = "Reload" },
							{ type = "toggle", key = "InstantReload", label = "Instant Reload", hud = "FastR" },
							{
								type = "hint",
								text = "Skips reload lock animation — mag refills immediately (R / auto-reload).",
							},
							{ type = "toggle", key = "InfiniteGrenades", label = "Infinite Grenades", hud = "Nades" },
							{
								type = "hint",
								text = "Keeps Variables.Grenades filled so G / mobile grenade always has ammo client-side.",
							},
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
			{
				label = "Lobby",
				sections = {
					{
						title = "CRATE COUNTS",
						items = {
							{
								type = "hint",
								text = "Lobby-only. Opens call game remotes directly (no crate animations).",
							},
							{ type = "button", label = "Log Crate Counts", onClick = lobby.logCrateCounts },
							{ type = "button", label = "Log Inventory Summary", onClick = lobby.logInventory },
						},
					},
					{
						title = "GUN CRATES",
						items = {
							{
								type = "select",
								key = "GunCrateBatch",
								label = "Open Batch",
								options = Constants.GUN_CRATE_BATCHES,
							},
							{
								type = "button",
								label = "Open Gun Crates Now",
								onClick = function()
									lobby.openGunCrate()
								end,
							},
							{
								type = "toggle",
								key = "AutoOpenGunCrates",
								label = "Auto Open Gun Crates",
								hud = "GunCrate",
							},
						},
					},
					{
						title = "PET CRATES",
						items = {
							{
								type = "select",
								key = "PetCrateBatch",
								label = "Open Batch",
								options = Constants.PET_CRATE_BATCHES,
							},
							{ type = "button", label = "Log Pet Odds", onClick = lobby.logPetOdds },
							{
								type = "button",
								label = "Open Pet Crates Now",
								onClick = function()
									lobby.openPetCrate()
								end,
							},
							{
								type = "toggle",
								key = "AutoOpenPetCrates",
								label = "Auto Open Pet Crates",
								hud = "PetCrate",
							},
						},
					},
					{
						title = "CAMO CRATES",
						items = {
							{
								type = "select",
								key = "CamoRollGun",
								label = "Roll Gun",
								options = camoSelectOptions,
							},
							{
								type = "button",
								label = "Open Camo Crate Now",
								onClick = function()
									lobby.openCamoCrate()
								end,
							},
							{
								type = "toggle",
								key = "AutoOpenCamoCrates",
								label = "Auto Open Camo Crates",
								hud = "CamoCrate",
							},
						},
					},
					{
						title = "OUTFIT CRATES",
						items = {
							{
								type = "select",
								key = "OutfitRollType",
								label = "Roll Category",
								options = Constants.OUTFIT_ROLL_TYPES,
							},
							{
								type = "select",
								key = "OutfitCrateBatch",
								label = "Open Batch",
								options = Constants.OUTFIT_CRATE_BATCHES,
							},
							{
								type = "button",
								label = "Open Outfit Crates Now",
								onClick = function()
									lobby.openOutfitCrate()
								end,
							},
							{
								type = "toggle",
								key = "AutoOpenOutfitCrates",
								label = "Auto Open Outfit Crates",
								hud = "OutfitCrate",
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
