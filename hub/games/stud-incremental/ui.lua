local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local UILib = opts.uiLib
	local movement = opts.movement
	local redeemNow = opts.redeemNow
	local exploits = opts.exploits

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
							{ type = "toggle", key = "AutoAddXP", label = "Auto Add XP", hud = "Auto XP" },
							{ type = "toggle", key = "AutoAfkStudPlatform", label = "AFK Stud Platform", hud = "AFK Studs" },
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
						title = "RUNES",
						items = {
							{ type = "toggle", key = "AutoOpenRunes", label = "Auto Open Runes", hud = "Auto Runes" },
							{
								type = "slider",
								key = "MinRuneStuds",
								label = "Min Studs Per Roll",
								min = 5000,
								max = 1000000,
								step = 1000,
							},
							{ type = "button", label = "TP Rune Sensor", onClick = movement.teleportToRuneSensor },
							{ type = "toggle", key = "AutoUnlockSpaceRunes", label = "Auto Unlock Space Runes", hud = "Space Runes" },
							{ type = "button", label = "TP Space Runes Unlock", onClick = movement.teleportToSpaceRunesUnlock },
						},
					},
					{
						title = "AREA 2-3",
						items = {
							{ type = "toggle", key = "AutoPoints", label = "Auto Points (Tier 6+)", hud = "Auto Points" },
							{ type = "toggle", key = "AutoBlocks", label = "Auto Blocks Gain", hud = "Auto Blocks" },
							{ type = "button", label = "TP Block Button", onClick = movement.teleportToBlockButton },
						},
					},
					{
						title = "AREA 5 PLANTS",
						items = {
							{
								type = "toggle",
								key = "AutoCollectPlantShards",
								label = "Auto Collect Shards",
								hud = "Plant Shards",
							},
							{
								type = "toggle",
								key = "CollectPlantShardsAnywhere",
								label = "Collect Shards Off Farm",
								hud = "Shard Anywhere",
							},
							{ type = "toggle", key = "AutoAfkPlantArea", label = "AFK Plant Farm", hud = "AFK Plants" },
							{ type = "button", label = "TP Plant Farm", onClick = movement.teleportToPlantFarm },
						},
					},
					{
						title = "WORLD 2",
						items = {
							{ type = "toggle", key = "AutoCollectStars", label = "Auto Collect Stars", hud = "Auto Stars" },
							{ type = "toggle", key = "CollectStarsAnywhere", label = "Collect All Stars", hud = "All Stars" },
							{ type = "toggle", key = "AutoRocketBuild", label = "Auto Rocket Build", hud = "Rocket" },
							{ type = "button", label = "TP Star Volume", onClick = movement.teleportToWorld2Stars },
						},
					},
				},
			},
			{
				label = "Upgrades",
				sections = {
					{
						title = "AREA 1-2",
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
						title = "AREA 3",
						items = {
							{ type = "toggle", key = "AutoBuyBlockUpgrades", label = "Block Upgrades", hud = "Block Up" },
							{ type = "toggle", key = "AutoBuyBlockMax", label = "Block Buy Max", hud = "Block Max" },
							{ type = "toggle", key = "AutoBuyUpgradeTree", label = "Upgrade Tree", hud = "Tree Up" },
						},
					},
					{
						title = "AREA 4-5",
						items = {
							{ type = "toggle", key = "AutoBuyDropperUpgrades", label = "Dropper Upgrades", hud = "Dropper Up" },
							{ type = "toggle", key = "AutoBuyDropperMax", label = "Dropper Buy Max", hud = "Drop Max" },
							{ type = "toggle", key = "AutoBuyFuserUpgrades", label = "Fuser Upgrades", hud = "Fuser Up" },
							{ type = "toggle", key = "AutoBuyFuserMax", label = "Fuser Buy Max", hud = "Fuse Max" },
							{ type = "toggle", key = "AutoBuyResearchUpgrades", label = "Research Upgrades", hud = "Research" },
							{ type = "toggle", key = "AutoBuyResearchMax", label = "Research Buy Max", hud = "Res Max" },
							{ type = "toggle", key = "AutoBuyRuneUpgrades", label = "Rune Upgrades", hud = "Rune Up" },
							{ type = "toggle", key = "AutoBuyRuneUpgradesMax", label = "Rune Buy Max", hud = "Rune Max" },
							{
								type = "select",
								key = "RuneUpgradePriority",
								label = "Rune Research Priority",
								options = { "RuneSpeed", "RuneLuck", "RuneBulk" },
							},
							{ type = "toggle", key = "AutoFuse", label = "Auto Fuse Cores", hud = "Auto Fuse" },
							{ type = "toggle", key = "AutoBuyPlantUpgrades", label = "Plant Upgrades", hud = "Plant Up" },
							{ type = "toggle", key = "AutoBuyPlantMax", label = "Plant Buy Max", hud = "Plant Max" },
							{
								type = "select",
								key = "PlantUpgradePriority",
								label = "Plant Upgrade Priority",
								options = { "MoreTokens", "GrowSpeed", "UnlockChallengeBoard" },
							},
							{ type = "toggle", key = "AutoPlantTierUp", label = "Auto Plant Tier Up", hud = "Plant Tier" },
							{ type = "toggle", key = "AutoPlantReset", label = "Auto Plant Reset", hud = "Plant Reset" },
							{
								type = "toggle",
								key = "PlantResetRequiresChallenge",
								label = "Reset Needs Challenge Board",
								hud = "Reset Gate",
							},
						},
					},
					{
						title = "WORLD 2 UPGRADES",
						items = {
							{ type = "toggle", key = "AutoBuyStarUpgrades", label = "Star Upgrades", hud = "Star Up" },
							{ type = "toggle", key = "AutoBuyStarMax", label = "Star Buy Max", hud = "Star Max" },
							{ type = "toggle", key = "AutoBuyStardustUpgrades", label = "Stardust Upgrades", hud = "Dust Up" },
							{ type = "toggle", key = "AutoBuyStardustMax", label = "Stardust Buy Max", hud = "Dust Max" },
						},
					},
					{
						title = "RESETS",
						items = {
							{ type = "toggle", key = "AutoRebirth", label = "Auto Rebirth", hud = "Auto Rebirth" },
							{
								type = "slider",
								key = "MinRebirthStuds",
								label = "Min Rebirth Studs",
								min = 1000,
								max = 1000000,
								step = 1000,
							},
							{ type = "toggle", key = "AutoTierUp", label = "Auto Tier Up", hud = "Auto Tier" },
							{ type = "toggle", key = "AutoAscend", label = "Auto Ascend", hud = "Auto Ascend" },
						},
					},
				},
			},
			{
				label = "Exploits",
				sections = {
					{
						title = "CURRENCY SPAM",
						items = {
							{ type = "toggle", key = "ExploitGodlyStudSpam", label = "Godly Stud Spam", hud = "Godly Spam" },
							{ type = "toggle", key = "ExploitRemotePoints", label = "Remote Points Spam", hud = "Pt Spam" },
							{ type = "toggle", key = "ExploitRemoteBlocks", label = "Remote Blocks Spam", hud = "Blk Spam" },
							{ type = "toggle", key = "ExploitFastXP", label = "Fast XP Spam", hud = "XP Spam" },
							{ type = "toggle", key = "ExploitTokenFarm", label = "Token ID Farm", hud = "Token Farm" },
							{
								type = "select",
								key = "ExploitTokenPlant",
								label = "Token Plant ID",
								options = Constants.PLANT_TOKEN_IDS,
							},
						},
					},
					{
						title = "AREA 4-5",
						items = {
							{ type = "toggle", key = "ExploitCoreGain", label = "Core Gain Amount", hud = "Core Gain" },
							{
								type = "slider",
								key = "ExploitCoreGainAmount",
								label = "Core Amount",
								min = 1,
								max = 1000000,
								step = 100,
							},
							{ type = "button", label = "Burst Core Gain", onClick = exploits.burstCoreGain },
							{ type = "toggle", key = "ExploitFuseLoop", label = "Fuse + Core Loop", hud = "Fuse Loop" },
							{ type = "toggle", key = "ExploitCoreGainAfterFuse", label = "Core Gain After Fuse", hud = "Fuse Core" },
							{ type = "toggle", key = "ExploitParticleSpam", label = "Particle Gain Spam", hud = "Particles" },
							{
								type = "slider",
								key = "ExploitParticleSlot",
								label = "Particle Slot (0=rotate)",
								min = 0,
								max = 3,
								step = 1,
							},
							{ type = "button", label = "Burst Token Farm", onClick = exploits.burstTokenFarm },
						},
					},
					{
						title = "UPGRADE TREE",
						items = {
							{ type = "toggle", key = "ExploitUpgradeTreeMulti", label = "Inflated Tree Multi", hud = "Tree Multi" },
							{
								type = "slider",
								key = "ExploitUpgradeTreeMultiValue",
								label = "Tree Multi Value",
								min = 1,
								max = 500,
								step = 1,
							},
							{ type = "button", label = "Burst All Tree Nodes", onClick = exploits.burstUpgradeTree },
							{ type = "toggle", key = "ExploitRogueTreeSync", label = "Rogue Tree Resync", hud = "Rogue Sync" },
						},
					},
					{
						title = "MISC EXPLOITS",
						items = {
							{ type = "toggle", key = "ExploitCurrentStudsZero", label = "Reset CurrentStuds (0)", hud = "Studs 0" },
							{ type = "toggle", key = "ExploitCurrentStudsMax", label = "Spoof CurrentStuds High", hud = "Studs Max" },
							{
								type = "slider",
								key = "ExploitCurrentStudsCount",
								label = "CurrentStuds Value",
								min = 0,
								max = 50000,
								step = 100,
							},
							{ type = "toggle", key = "ExploitStarCollectSpam", label = "Star Collect Spam", hud = "Star Spam" },
							{
								type = "slider",
								key = "ExploitTickInterval",
								label = "Exploit Tick Rate",
								min = 0.02,
								max = 0.5,
								step = 0.01,
							},
							{
								type = "slider",
								key = "ExploitBurstCount",
								label = "Burst Count",
								min = 1,
								max = 25,
								step = 1,
							},
							{
								type = "hint",
								text = "Exploits abuse server-trusted remotes. High rates may kick. CoreGain and Tree Multi are the strongest.",
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
						title = "REWARDS",
						items = {
							{ type = "toggle", key = "AutoClaimGroupReward", label = "Auto Group Reward", hud = "Group" },
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
