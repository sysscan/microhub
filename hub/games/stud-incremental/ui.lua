local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local movement = opts.movement
	local redeemNow = opts.redeemNow

	UILib.create({
		title = "STUD INCREMENTAL",
		config = Config,
		pages = {
			{
				label = "Farm",
				sections = {
					{
						title = "STUDS",
						items = {
							{ type = "toggle", key = "AutoCollectStuds", label = "Auto Collect Studs", hud = "Auto Studs" },
							{ type = "toggle", key = "CollectAnywhere", label = "Collect Off Platform", hud = "Anywhere" },
							{
								type = "slider",
								key = "CollectRadius",
								label = "Collect Radius",
								min = 20,
								max = 500,
								step = 10,
							},
							{ type = "button", label = "TP Stud Platform", onClick = movement.teleportToStudPlatform },
						},
					},
					{
						title = "AREA 2+",
						items = {
							{ type = "toggle", key = "AutoPoints", label = "Auto Points (Tier 6+)", hud = "Auto Points" },
							{ type = "toggle", key = "AutoBlocks", label = "Auto Blocks Gain", hud = "Auto Blocks" },
							{ type = "button", label = "TP Block Button", onClick = movement.teleportToBlockButton },
							{ type = "toggle", key = "AutoCollectStars", label = "Auto Collect Stars", hud = "Auto Stars" },
						},
					},
				},
			},
			{
				label = "Upgrades",
				sections = {
					{
						title = "AUTO BUY",
						items = {
							{ type = "toggle", key = "AutoBuyStudUpgrades", label = "Stud Upgrades", hud = "Stud Up" },
							{ type = "toggle", key = "AutoBuyStudMax", label = "Stud Buy Max", hud = "Stud Max" },
							{
								type = "select",
								key = "StudUpgradePriority",
								label = "Stud Priority",
								options = { "MoreStuds", "SpawnSpeed", "MaxStuds" },
							},
							{ type = "toggle", key = "AutoRebirthUpgrades", label = "Rebirth Upgrades", hud = "RP Up" },
							{ type = "toggle", key = "AutoBuyRebirthMax", label = "Rebirth Buy Max", hud = "RP Max" },
							{ type = "toggle", key = "AutoBuyPointUpgrades", label = "Point Upgrades", hud = "Point Up" },
							{ type = "toggle", key = "AutoBuyPointMax", label = "Point Buy Max", hud = "Point Max" },
						},
					},
					{
						title = "RESETS",
						items = {
							{ type = "toggle", key = "AutoRebirth", label = "Auto Rebirth", hud = "Auto Rebirth" },
							{ type = "toggle", key = "AutoTierUp", label = "Auto Tier Up", hud = "Auto Tier" },
							{ type = "toggle", key = "AutoAscend", label = "Auto Ascend", hud = "Auto Ascend" },
							{
								type = "hint",
								text = "Rebirth needs 1k+ studs. Tier/Ascend spend studs at their walls.",
							},
						},
					},
				},
			},
			{
				label = "Misc",
				sections = {
					{
						title = "MOVEMENT",
						items = {
							{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed" },
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 20, max = 120, step = 2 },
						},
					},
					{
						title = "CODES",
						items = {
							{ type = "toggle", key = "AutoRedeemCode", label = "Auto Redeem Code", hud = "Auto Code" },
							{ type = "button", label = "Redeem Code Now", onClick = redeemNow },
							{
								type = "hint",
								text = "Set getgenv().__MicroHubStudCode = 'YOURCODE' in the executor, then redeem.",
							},
						},
					},
					{
						title = "HUD",
						items = {
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
							{
								type = "slider",
								key = "TickInterval",
								label = "Automation Tick",
								min = 0.05,
								max = 1,
								step = 0.05,
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
