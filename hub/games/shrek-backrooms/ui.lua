local M = {}

function M.create(opts)
	local Config = opts.config
	local UILib = opts.uiLib
	local Constants = opts.constants
	local teleport = opts.teleport
	local automation = opts.automation
	local shop = opts.shop
	local extras = opts.extras
	local combat = opts.combat
	local remotes = opts.remotes
	local redeemNow = opts.redeemNow

	UILib.create({
		title = "SHREK BACKROOMS",
		config = Config,
		pages = {
			{
				label = "Farm",
				sections = {
					{
						title = "REWARDS",
						items = {
							{ type = "toggle", key = "AutoDailyReward", label = "Auto Daily Reward", hud = "Daily" },
							{ type = "toggle", key = "AutoDailyQuest", label = "Auto Claim Quests", hud = "Quests" },
							{ type = "toggle", key = "AutoRedeemCode", label = "Auto Redeem Code", hud = "Code" },
							{ type = "toggle", key = "AutoClaimGifts", label = "Auto Claim Gifts", hud = "Gifts" },
							{ type = "button", label = "Redeem Code Now", callback = redeemNow },
							{ type = "hint", label = "getgenv().__MicroHubShrekCode = 'CODE'" },
						},
					},
					{
						title = "SEARCH",
						items = {
							{ type = "toggle", key = "AutoSearch", label = "Auto Search Cabinets", hud = "Search" },
							{ type = "slider", key = "SearchRange", label = "Search Range", min = 6, max = 40, step = 1 },
							{ type = "slider", key = "SearchInterval", label = "Search Interval", min = 0.15, max = 2, step = 0.05 },
						},
					},
					{
						title = "COMBAT",
						items = {
							{ type = "toggle", key = "AutoAttack", label = "Auto Attack Monsters", hud = "Attack" },
							{ type = "toggle", key = "AutoEquipBest", label = "Auto Equip Best Weapon", hud = "Equip" },
							{ type = "toggle", key = "AimAssist", label = "Aim Assist", hud = "Aim" },
							{ type = "slider", key = "AttackRange", label = "Attack Range", min = 20, max = 200, step = 5 },
							{ type = "slider", key = "AimFOV", label = "Aim FOV", min = 40, max = 300, step = 5 },
						},
					},
				},
			},
			{
				label = "Shop",
				sections = {
					{
						title = "BOXES",
						items = {
							{ type = "toggle", key = "AutoOpenBoxes", label = "Auto Open Weapon Boxes", hud = "Open Box" },
							{ type = "toggle", key = "AutoSpinWheel", label = "Auto Spin Mystery Wheel", hud = "Spin" },
							{
								type = "select",
								key = "SpinWheelSubtype",
								label = "Wheel Box Type",
								options = Constants.SPIN_SUBTYPES,
							},
							{ type = "button", label = "Spin Wheel Now", callback = function()
								shop.trySpinWheel()
							end },
							{ type = "button", label = "Open Boxes Now", callback = function()
								shop.tryOpenBoxes()
							end },
						},
					},
					{
						title = "SHREK COINS",
						items = {
							{ type = "toggle", key = "AutoToolShopBuy", label = "Auto Buy Lobby Tool", hud = "Shop Buy" },
							{
								type = "select",
								key = "ToolShopItem",
								label = "Tool To Buy",
								options = Constants.TOOL_SHOP_ITEMS,
							},
							{ type = "button", label = "Buy Tool Now", callback = function()
								shop.tryToolShopBuy()
							end },
						},
					},
					{
						title = "ROBUX (CAREFUL)",
						items = {
							{ type = "toggle", key = "AutoBuyRobuxBoxes", label = "Auto Buy Robux Boxes", hud = "Robux" },
							{
								type = "select",
								key = "RobuxBoxName",
								label = "Box Name",
								options = { "Classic Box", "Brainrot Box", "67 Box", "Waffle Box" },
							},
							{
								type = "select",
								key = "RobuxBoxPack",
								label = "Pack Size",
								options = { "1 Boxes", "3 Boxes", "10 Boxes" },
							},
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
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = 120, step = 1 },
							{ type = "toggle", key = "AlwaysSprint", label = "Infinite Sprint", hud = "Sprint" },
							{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 16, max = 50, step = 1 },
							{ type = "toggle", key = "JumpBoost", label = "Jump Boost", hud = "Jump" },
							{ type = "slider", key = "JumpPower", label = "Jump Power", min = 16, max = 120, step = 1 },
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
								key = "TeleportLevel",
								label = "Level",
								options = Constants.TELEPORT_LEVELS,
							},
							{ type = "button", label = "Teleport To Level", callback = function()
								teleport.teleportConfigured(Config.TeleportLevel)
							end },
							{ type = "button", label = "Teleport Lobby", callback = function()
								teleport.teleportLobby()
							end },
							{ type = "button", label = "TP Nearest Player", callback = function()
								teleport.teleportNearestPlayer()
							end },
							{ type = "button", label = "Refresh Unlocked Levels", callback = function()
								teleport.printUnlockedLevels()
							end },
						},
					},
					{
						title = "MORPH",
						items = {
							{ type = "button", label = "Become Shrek", callback = function()
								remotes.morphShrek()
							end },
							{ type = "button", label = "Reset Morph", callback = function()
								remotes.resetMorph()
							end },
							{ type = "button", label = "Shrek Taunt", callback = function()
								remotes.morphTaunt()
							end },
							{ type = "button", label = "Toggle Shrek PVP", callback = function()
								remotes.morphPvp()
							end },
							{ type = "button", label = "Shrek Hide", callback = function()
								remotes.morphHide()
							end },
							{ type = "button", label = "Equip Exterminator", callback = function()
								remotes.equipExterminator()
							end },
							{ type = "button", label = "Equip Mech", callback = function()
								remotes.equipMech()
							end },
							{ type = "button", label = "Revert Mech", callback = function()
								remotes.revertMech()
							end },
							{ type = "button", label = "Break Annihilator Wall", callback = function()
								remotes.breakAnnihilatorWall()
							end },
						},
					},
					{
						title = "TEAM",
						items = {
							{ type = "button", label = "Leave Team Session", callback = function()
								remotes.teamLeave()
							end },
						},
					},
				},
			},
			{
				label = "Misc",
				sections = {
					{
						title = "QOL",
						items = {
							{ type = "toggle", key = "AutoSkipTutorial", label = "Auto Skip Tutorial", hud = "Tutorial" },
							{ type = "toggle", key = "DisableWeaponPopups", label = "Disable Weapon Popups", hud = "Popups" },
							{ type = "toggle", key = "YoutubeMode", label = "Youtube / Streamer Mode", hud = "YT Mode" },
							{ type = "button", label = "Claim Gifts Now", callback = function()
								extras.tryClaimGifts()
							end },
							{ type = "button", label = "Equip Best Weapon", callback = function()
								combat.equipBestTool()
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
							{ type = "toggle", key = "MonsterESP", label = "Monster Markers", hud = "Monsters" },
							{ type = "toggle", key = "MonsterESPBoxes", label = "Monster Boxes", hud = "M Boxes" },
							{ type = "toggle", key = "SearchESP", label = "Search Item ESP", hud = "Search ESP" },
							{ type = "toggle", key = "CoinESP", label = "Coin NPC ESP", hud = "Coins" },
							{ type = "toggle", key = "MysteryBoxESP", label = "Mystery Box ESP", hud = "Boxes" },
							{ type = "toggle", key = "ShowAimFOV", label = "Show Aim FOV Circle", hud = "FOV" },
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
