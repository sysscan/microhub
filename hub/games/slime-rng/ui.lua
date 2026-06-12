local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local movement = opts.movement
	local redeemNow = opts.redeemNow

	UILib.create({
		title = "SLIME RNG",
		config = Config,
		pages = {
			{
				label = "Farm",
				sections = {
					{
						title = "ROLL",
						items = {
							{ type = "toggle", key = "AutoRoll", label = "Auto Roll", hud = "Auto Roll" },
							{ type = "toggle", key = "UseGameAutoRoll", label = "Game Auto Roll Setting", hud = "Game Roll" },
							{ type = "toggle", key = "HiddenRoll", label = "Hidden Roll", hud = "Hidden" },
							{ type = "toggle", key = "InstantRoll", label = "Instant Roll Reveal", hud = "Instant" },
							{
								type = "toggle",
								key = "AutoDismissRollPopups",
								label = "Dismiss Roll Popups",
								hud = "Dismiss",
							},
							{ type = "toggle", key = "AutoSkipCutscenes", label = "Skip Rare/Jackpot UI", hud = "Skip Cut" },
							{
								type = "slider",
								key = "RollInterval",
								label = "Roll Interval",
								min = 0.02,
								max = 1,
								step = 0.02,
							},
						},
					},
					{
						title = "PICKUPS",
						items = {
							{
								type = "toggle",
								key = "AutoCollectPickups",
								label = "Auto Collect Coins/Goop",
								hud = "Pickups",
							},
							{ type = "toggle", key = "AutoCollectLoot", label = "Auto Collect Loot/Fruit", hud = "Loot" },
						},
					},
					{
						title = "PROGRESS",
						items = {
							{ type = "toggle", key = "AutoRebirth", label = "Auto Rebirth", hud = "Rebirth" },
							{ type = "toggle", key = "AutoClaimOffline", label = "Auto Claim Offline", hud = "Offline" },
							{ type = "toggle", key = "AutoBuyZone", label = "Auto Buy Next Zone", hud = "Zone Buy" },
						},
					},
					{
						title = "COMBAT",
						items = {
							{ type = "toggle", key = "AutoSlimeGun", label = "Auto Slime Gun", hud = "Gun" },
							{
								type = "slider",
								key = "SlimeGunInterval",
								label = "Gun Fire Interval",
								min = 0.05,
								max = 1,
								step = 0.05,
							},
						},
					},
				},
			},
			{
				label = "Slimes",
				sections = {
					{
						title = "TEAM",
						items = {
							{ type = "toggle", key = "AutoEquipBest", label = "Auto Equip Best", hud = "Equip Best" },
							{
								type = "toggle",
								key = "AutoBuySlimeUpgrades",
								label = "Auto Buy Slime Upgrades",
								hud = "Slime Up",
							},
						},
					},
					{
						title = "FRUITS",
						items = {
							{
								type = "toggle",
								key = "AutoUnlockFruitExtractor",
								label = "Auto Unlock Extractor",
								hud = "Extractor",
							},
							{
								type = "toggle",
								key = "AutoExtractFruits",
								label = "Auto Extract Fruits",
								hud = "Extract",
							},
						},
					},
				},
			},
			{
				label = "Upgrades",
				sections = {
					{
						title = "GLOBAL",
						items = {
							{ type = "toggle", key = "AutoBuyUpgrades", label = "Auto Buy Upgrades", hud = "Upgrades" },
							{
								type = "select",
								key = "UpgradeTreeScope",
								label = "Upgrade Trees",
								options = { "main", "all" },
							},
						},
					},
					{
						title = "CRAFTING",
						items = {
							{
								type = "toggle",
								key = "AutoUnlockCraftMachine",
								label = "Auto Unlock Craft Machine",
								hud = "Craft Unlock",
							},
							{
								type = "toggle",
								key = "AutoBuyCraftRecipes",
								label = "Auto Buy Craft Recipes",
								hud = "Recipes",
							},
							{
								type = "toggle",
								key = "AutoClaimWorldRecipes",
								label = "Auto Claim World Recipes",
								hud = "Claim Recipe",
							},
						},
					},
				},
			},
			{
				label = "Misc",
				sections = {
					{
						title = "TELEPORT",
						items = {
							{
								type = "slider",
								key = "TeleportZone",
								label = "Zone ID",
								min = 1,
								max = 43,
								step = 1,
							},
							{ type = "button", label = "TP Selected Zone", onClick = movement.teleportToConfiguredZone },
							{ type = "button", label = "TP Current Zone", onClick = movement.teleportToCurrentZone },
							{ type = "button", label = "TP Max Unlocked Zone", onClick = movement.teleportToMaxZone },
						},
					},
					{
						title = "MOVEMENT",
						items = {
							{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed" },
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 20, max = 120, step = 2 },
							{ type = "toggle", key = "JumpBoost", label = "Jump Boost", hud = "Jump" },
							{ type = "slider", key = "JumpPower", label = "Jump Power", min = 20, max = 120, step = 2 },
						},
					},
					{
						title = "REWARDS",
						items = {
							{ type = "toggle", key = "AutoLikeGroup", label = "Auto Like/Group Luck", hud = "Group" },
							{ type = "toggle", key = "AutoRedeemCode", label = "Auto Redeem Code", hud = "Auto Code" },
							{ type = "button", label = "Redeem Code Now", onClick = redeemNow },
							{
								type = "hint",
								text = "Set getgenv().__MicroHubSlimeCode = 'YOURCODE' in the executor, then redeem.",
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
