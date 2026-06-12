local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local UILib = opts.uiLib
	local teleport = opts.teleport
	local playerData = opts.playerData

	UILib.create({
		title = "VV ULTIMATUM",
		config = Config,
		pages = {
			{
				label = "Visual",
				sections = {
					{
						title = "ESP",
						items = {
							{ type = "toggle", key = "ESPPlayers", label = "Player ESP", hud = "Players" },
							{ type = "toggle", key = "ESPHollows", label = "Hollow ESP", hud = "Hollows" },
							{ type = "toggle", key = "ESPBosses", label = "Boss ESP", hud = "Bosses" },
							{ type = "toggle", key = "ESPQuestNPCs", label = "Quest NPC ESP", hud = "Quests" },
							{ type = "toggle", key = "ESPChests", label = "Chest ESP", hud = "Chests" },
							{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
							{ type = "color", key = "ESPEnemyColor", label = "Enemy Color" },
							{ type = "color", key = "ESPAllyColor", label = "Ally Color" },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						},
					},
				},
			},
			{
				label = "Combat",
				sections = {
					{
						title = "Assist",
						items = {
							{ type = "toggle", key = "AutoAttack", label = "Auto Attack", hud = "Auto M1" },
							{ type = "toggle", key = "AutoBlock", label = "Auto Block", hud = "Block" },
							{ type = "toggle", key = "AutoFlashStep", label = "Auto Flash Step", hud = "Flash Step" },
							{ type = "toggle", key = "AutoGrip", label = "Auto Grip", hud = "Grip" },
							{
								type = "slider",
								key = "AttackInterval",
								label = "Attack Interval",
								min = 0.3,
								max = 1.5,
								step = 0.05,
							},
						},
					},
					{
						title = "Farm",
						items = {
							{ type = "toggle", key = "AutoFarm", label = "Auto Farm Hollows", hud = "Farm" },
							{ type = "toggle", key = "FarmBossesOnly", label = "Bosses Only", hud = "Boss Farm" },
							{
								type = "slider",
								key = "FarmRange",
								label = "Farm Range",
								min = 50,
								max = 800,
								step = 25,
							},
						},
					},
				},
			},
			{
				label = "Auto",
				sections = {
					{
						title = "Progression",
						items = {
							{ type = "toggle", key = "AutoMeditate", label = "Auto Meditate", hud = "Meditate" },
							{ type = "toggle", key = "AutoTakeQuests", label = "Auto Take Quests", hud = "Quests" },
							{ type = "toggle", key = "AutoRequestMission", label = "Auto Request Mission", hud = "Missions" },
							{ type = "toggle", key = "AutoSecondaryMission", label = "Secondary Mission", hud = "2nd Mission" },
							{
								type = "select",
								key = "MissionClass",
								label = "Mission Class",
								options = { "1", "2", "3", "4" },
							},
						},
					},
				},
			},
			{
				label = "Movement",
				sections = {
					{
						title = "Character",
						items = {
							{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed" },
							{
								type = "slider",
								key = "WalkSpeed",
								label = "Walk Speed",
								min = 16,
								max = 80,
								step = 1,
							},
							{ type = "toggle", key = "Flight", label = "Toggle Flight", hud = "Flight" },
							{ type = "toggle", key = "Noclip", label = "Noclip", hud = "Noclip" },
						},
					},
				},
			},
			{
				label = "Teleport",
				sections = {
					{
						title = "Worlds",
						items = {
							{
								type = "select",
								key = "TeleportPlace",
								label = "Destination",
								options = Constants.TELEPORT_PLACES,
							},
							{
								type = "button",
								label = "Teleport To Place",
								callback = function()
									teleport.teleportToPlace(Config.TeleportPlace)
								end,
							},
							{
								type = "button",
								label = "Server Hop (Current Place)",
								callback = function()
									teleport.serverHop()
								end,
							},
						},
					},
					{
						title = "Info",
						items = {
							{
								type = "button",
								label = "Print Character Summary",
								callback = function()
									local summary = playerData.getSummary()
									if summary then
										print("[VV Ultimatum]", summary.Race, "L" .. tostring(summary.Level), summary.Faction)
									else
										warn("[VV Ultimatum] Character data not ready")
									end
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
