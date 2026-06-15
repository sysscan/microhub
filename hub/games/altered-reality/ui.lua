local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local Constants = opts.constants
	local remotes = opts.remotes
	local automation = opts.automation
	local vehicles = opts.vehicles
	local probe = opts.probe
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
								text = "Silent Aim hooks weapon raycasts (750 stud shots). Hold LMB and let the game fire — do not rely on hub firing.",
							},
							{ type = "slider", key = "AttackRange", label = "Attack Range", min = 50, max = 750, step = 10 },
							{ type = "slider", key = "AimFOV", label = "Aim FOV", min = 60, max = 720, step = 10 },
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
							{
								type = "select",
								key = "FlyMode",
								label = "Fly Mode",
								options = Constants.FLY_MODES,
							},
							{ type = "toggle", key = "FlySafeSpeed", label = "Safe Speed Cap", hud = "SafeFly" },
							{ type = "toggle", key = "FlySuppressFell", label = "Suppress Fall Remote", hud = "NoFell" },
							{ type = "toggle", key = "FlyNetworkOwner", label = "Network Owner (risky)", hud = "NetOwn" },
							{ type = "toggle", key = "VehicleFlyAutoEnter", label = "Auto Enter Vehicle", hud = "VehEnter" },
							{
								type = "slider",
								key = "VehicleFlyEnterRange",
								label = "Vehicle Enter Range",
								min = 8,
								max = 40,
								step = 1,
							},
							{
								type = "button",
								label = "Enter Nearest Vehicle",
								onClick = function()
									if vehicles then
										local ok = vehicles.tryEnterNearest()
										warn("[Altered Reality] enter nearest vehicle:", ok)
									end
								end,
							},
							{
								type = "slider",
								key = "FlySpeed",
								label = "Fly Speed",
								min = 8,
								max = Constants.MAX_FLY_SPEED,
								step = 1,
							},
							{
								type = "hint",
								text = "Vehicle mode drives Chassis.Root.BodyVelocity while seated. Planes get full 3D thrust.",
							},
							{
								type = "hint",
								text = "Kicks are usually server position checks. Keep Safe Speed on; avoid Network Owner unless needed.",
							},
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
							{ type = "toggle", key = "ESP", label = "Player ESP", hud = "Players" },
							{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Lines" },
							{
								type = "slider",
								key = "ESPRange",
								label = "Player ESP Range",
								min = 25,
								max = Constants.MAX_ESP_DIST,
								step = 25,
							},
						},
					},
					{
						title = "LOOT ESP",
						items = {
							{ type = "toggle", key = "LootESP", label = "Loot ESP", hud = "Loot" },
							{
								type = "slider",
								key = "LootESPRange",
								label = "Loot ESP Range",
								min = 25,
								max = Constants.MAX_LOOT_ESP_RANGE,
								step = 25,
							},
							{
								type = "slider",
								key = "LootESPMaxItems",
								label = "Max Loot Labels",
								min = 10,
								max = Constants.MAX_ESP_LOOT,
								step = 5,
							},
							{ type = "toggle", key = "LootESPShowDistance", label = "Show Distance", hud = "Dist" },
							{ type = "toggle", key = "LootESPShowCategory", label = "Show Category", hud = "Cat" },
							{ type = "toggle", key = "LootESPUseColors", label = "Category Colors", hud = "Colors" },
							{
								type = "slider",
								key = "LootESPTextSize",
								label = "Label Size",
								min = 10,
								max = 20,
								step = 1,
							},
							{
								type = "select",
								key = "LootESPFilter",
								label = "Loot Filter",
								options = Constants.LOOT_FILTER_OPTIONS,
							},
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
				label = "Probe",
				sections = {
					{
						title = "LOGGER",
						items = {
							{ type = "toggle", key = "RemoteProbeLog", label = "Log Remotes To Console", hud = "ProbeLog" },
							{
								type = "button",
								label = "Install Remote Logger",
								onClick = function()
									if probe then
										probe.installRemoteLogger()
									end
								end,
							},
							{
								type = "button",
								label = "List Remotes",
								onClick = function()
									if probe then
										probe.listRemotes()
									end
								end,
							},
							{
								type = "button",
								label = "Log Player State",
								onClick = function()
									if probe then
										probe.logPlayerState()
									end
								end,
							},
							{
								type = "button",
								label = "Dump Probe Logs",
								onClick = function()
									if probe then
										probe.dumpLogs()
									end
								end,
							},
						},
					},
					{
						title = "SAFE PROBES",
						items = {
							{
								type = "hint",
								text = "These fire real remotes. Use in a safe area — reload probe logs after each test.",
							},
							{ type = "button", label = "Probe Fell(0)", onClick = function()
								if probe then
									probe.probeFellZero()
								end
							end },
							{ type = "button", label = "Probe Entangle()", onClick = function()
								if probe then
									probe.probeEntangle()
								end
							end },
							{ type = "button", label = "Probe Crouch(false)", onClick = function()
								if probe then
									probe.probeCrouch()
								end
							end },
							{ type = "button", label = "Scan workspace.Vehicles", onClick = function()
								if probe then
									probe.scanVehicles()
								end
							end },
							{ type = "button", label = "Probe Vehicle Horn", onClick = function()
								if probe then
									probe.probeVehicleHorn()
								end
							end },
							{ type = "button", label = "Probe Vehicle Exit", onClick = function()
								if probe then
									probe.probeVehicleExit()
								end
							end },
							{ type = "button", label = "Probe Tool Reload", onClick = function()
								if probe then
									probe.probeToolReload()
								end
							end },
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
								type = "select",
								key = "AutoLootFilter",
								label = "Pickup Filter",
								options = Constants.LOOT_FILTER_OPTIONS,
							},
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
