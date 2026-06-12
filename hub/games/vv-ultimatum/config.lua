return {
	-- Visual
	ESPPlayers = true,
	ESPHollows = true,
	ESPBosses = true,
	ESPQuestNPCs = false,
	ESPChests = false,
	ESPSnaplines = true,
	ShowHUD = true,
	ESPEnemyColor = Color3.fromRGB(255, 72, 88),
	ESPAllyColor = Color3.fromRGB(72, 168, 255),

	-- Combat
	AutoAttack = false,
	AutoBlock = false,
	AutoFlashStep = false,
	AutoGrip = false,
	AttackInterval = 0.55,

	-- Automation
	AutoFarm = false,
	FarmBossesOnly = false,
	FarmRange = 400,
	AutoMeditate = false,
	AutoRequestMission = false,
	AutoSecondaryMission = false,
	AutoTakeQuests = false,
	MissionClass = 2,
	TickInterval = 0.2,
	FarmTickInterval = 0.35,

	-- Movement
	SpeedBoost = false,
	Flight = false,
	Noclip = false,
	WalkSpeed = 24,
	FlightSpeed = 48,

	-- Farm movement (safe = limit Y drop per TP, step = hop in studs, walk = Humanoid:MoveTo)
	FarmMoveMode = "safe",
	FarmStepStuds = 14,
	FarmWalkArrive = 14,
	FarmMoveCooldown = 0.35,
	TeleportMaxDrop = 12,

	-- Teleport
	TeleportPlace = "HumanWorld",

	-- Debugger
	DebugMonitorAC = true,
	DebugLivePrint = false,
}
