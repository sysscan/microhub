local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local Constants = opts.constants
	local teleport = opts.teleport
	local wood = opts.wood
	local chop = opts.chop
	local extras = opts.extras
	local remotes = opts.remotes

	UILib.create({
		title = "LUMBER TYCOON 2",
		config = Config,
		pages = {
			{
				label = "Wood",
				sections = {
					{
						title = "AUTO CHOP",
						items = {
							{ type = "toggle", key = "AutoChop", label = "Auto Chop Nearest Tree", hud = "Chop" },
							{ type = "toggle", key = "AutoEquipAxe", label = "Auto Equip Axe", hud = "Axe" },
							{ type = "toggle", key = "ChopTeleport", label = "Teleport To Tree", hud = "TP Tree" },
							{ type = "toggle", key = "ChopPlayerWood", label = "Include Plot Wood", hud = "Plot Chop" },
							{ type = "toggle", key = "ChopRareOnly", label = "Rare Trees Only", hud = "Rare" },
							{
								type = "select",
								key = "ChopWoodType",
								label = "Wood Type",
								options = Constants.CHOP_WOOD_TYPES,
							},
							{ type = "slider", key = "ChopRange", label = "Search Range", min = 8, max = 120, step = 1 },
							{ type = "slider", key = "ChopInterval", label = "Chop Interval", min = 0.2, max = 1.5, step = 0.05 },
							{ type = "slider", key = "ChopDamageMult", label = "Damage Multiplier", min = 0.5, max = 5, step = 0.1 },
							{ type = "button", label = "Chop Once", callback = function()
								chop.tryAutoChop(true)
							end },
							{ type = "button", label = "TP Nearest Rare Wood", callback = function()
								chop.teleportToNearestRareWood()
							end },
						},
					},
					{
						title = "LOGS & SELL",
						items = {
							{ type = "toggle", key = "BringLogs", label = "Bring Owned Logs", hud = "Logs" },
							{ type = "slider", key = "BringLogsRange", label = "Bring Range", min = 20, max = 500, step = 10 },
							{ type = "toggle", key = "AutoSellWood", label = "Auto Sell Wood", hud = "Sell" },
							{ type = "slider", key = "SellWoodRange", label = "Sell Range", min = 50, max = 2000, step = 25 },
							{ type = "toggle", key = "BringPlanks", label = "Bring Plot Wood/Planks", hud = "Planks" },
							{ type = "slider", key = "BringPlanksRange", label = "Plank Range", min = 20, max = 500, step = 10 },
							{ type = "button", label = "Bring Logs Now", callback = function()
								wood.bringLogsNow()
							end },
							{ type = "button", label = "Sell Wood Now", callback = function()
								wood.sellWoodNow()
							end },
							{ type = "button", label = "Bring Planks Now", callback = function()
								wood.bringPlanksNow()
							end },
						},
					},
				},
			},
			{
				label = "Player",
				sections = {
					{
						title = "MOVEMENT",
						items = {
							{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed" },
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = 80, step = 1 },
							{ type = "toggle", key = "JumpBoost", label = "Jump Boost", hud = "Jump" },
							{ type = "slider", key = "JumpPower", label = "Jump Power", min = 16, max = 120, step = 1 },
							{ type = "toggle", key = "InfiniteJump", label = "Infinite Jump", hud = "Inf Jump" },
							{ type = "toggle", key = "Fly", label = "Fly (WASD Space/Ctrl)", hud = "Fly" },
							{ type = "slider", key = "FlySpeed", label = "Fly Speed", min = 20, max = 150, step = 5 },
							{ type = "toggle", key = "NoClip", label = "NoClip", hud = "Noclip" },
							{ type = "toggle", key = "FullBright", label = "Fullbright", hud = "Bright" },
							{ type = "slider", key = "CameraFOV", label = "Camera FOV", min = 40, max = 120, step = 1 },
							{ type = "toggle", key = "AntiAfk", label = "Anti AFK", hud = "AFK" },
						},
					},
					{
						title = "TELEPORT",
						items = {
							{
								type = "select",
								key = "TeleportLocation",
								label = "Location",
								options = Constants.TELEPORT_LOCATIONS,
							},
							{ type = "button", label = "Teleport", callback = function()
								teleport.teleportConfigured()
							end },
							{ type = "button", label = "TP Sell Wood", callback = function()
								teleport.teleportToSellWood()
							end },
							{ type = "button", label = "TP My Plot", callback = function()
								teleport.teleportToMyPlot()
							end },
							{ type = "button", label = "TP Nearest Player", callback = function()
								teleport.teleportNearestPlayer()
							end },
						},
					},
					{
						title = "PROTECTION",
						items = {
							{ type = "toggle", key = "AntiBlacklistWalls", label = "Remove Blacklist Walls", hud = "Anti BL" },
							{ type = "toggle", key = "AutoBlockVisitors", label = "Auto Block Visitors", hud = "Block" },
							{ type = "button", label = "Block All Players Now", callback = function()
								extras.blockAllPlayers()
							end },
							{ type = "button", label = "Print Money", callback = function()
								extras.printMoney()
							end },
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
							{ type = "toggle", key = "WoodESP", label = "Wood ESP", hud = "Wood" },
							{ type = "toggle", key = "WoodESPAll", label = "Show All Wood Types", hud = "All Wood" },
							{ type = "slider", key = "WoodESPRange", label = "Wood ESP Range", min = 50, max = 2000, step = 25 },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						},
					},
				},
			},
		},
		hud = { showKey = "ShowHUD" },
	})

	task.defer(function()
		remotes.refreshPing()
	end)
end

return M
