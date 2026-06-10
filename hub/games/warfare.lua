local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Modules = Framework:WaitForChild("Modules")
local BulletSimulator = require(Modules:WaitForChild("BulletSimulator"))

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
	SilentAim = true,
	Teamcheck = true,
	Tracer = true,
	ESP = true,
	ESPAllies = true,
	FOVCircle = false,
	NoRecoil = false,
	StableAim = false,
	BulletTP = false,
	RapidFire = false,
	InfiniteAmmo = false,
	NoJam = false,
	NoOverheat = false,
	SpeedBoost = false,
	InfiniteStamina = false,
	ZoomBoost = false,
	ThermalESP = false,
	HitMarkers = true,
	GrenadeSpam = false,
	RocketSpam = false,
	Flight = false,
	NVG = false,
	FishEye = false,
	Comtacs = false,
	NoSuppression = false,
	StripShield = false,
	FullBright = false,
	ShowHUD = true,
	FOV = 200,
}

local BOOST_WALK_SPEED = 28
local BOOST_SPRINT_SPEED = 36
local FLIGHT_SPEED = 90
local FLIGHT_BOOST_SPEED = 140
local ZOOM_FOV = 12
-- One client interval for every gun; TryFireOnce enforces this via nextShotTime.
local RAPID_FIRE_UNIFIED_INTERVAL = 0.09

local AimPart = "Head"
local FOVSquared = Config.FOV * Config.FOV

local TeamColors = {
	Enemy = Color3.fromRGB(255, 75, 75),
	Ally = Color3.fromRGB(75, 220, 120),
	Neutral = Color3.fromRGB(255, 220, 80),
}

local currentTarget = nil
local killAllForcedTarget = nil
local killAllRunning = false
local killAllNoclip = false
local runKillAll
local applyBulletTP = function() end
local bulletRegistryRef = nil
local nextBulletRegistryScan = 0
local BULLET_TP_SNAP_DIST = 1.35
local BULLET_TP_ROCKET_SNAP_DIST = 2.75
local BULLET_TP_MIN_SPEED = 3500
local BULLET_TP_ROCKET_MIN_SPEED = 4800
local uiVisible = true
local savedMouseBehavior = nil
local UI_INPUT_BLOCK = "WarfareUIInputBlock"

local applyCombatMods = function() end
local updateThermalHighlights = function() end
local updateHitMarkers = function() end
local weaponStateRef = nil

local TeamsService = nil
do
	local gameFolder = ReplicatedStorage:FindFirstChild("Game")
	local modulesFolder = gameFolder and gameFolder:FindFirstChild("Modules")
	local teamsModule = modulesFolder and modulesFolder:FindFirstChild("TeamsService")
	if not teamsModule then
		for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
			if descendant.Name == "TeamsService" and descendant:IsA("ModuleScript") then
				teamsModule = descendant
				break
			end
		end
	end
	if teamsModule then
		local ok, service = pcall(require, teamsModule)
		if ok and typeof(service) == "table" and typeof(service.GetPlayerTeam) == "function" then
			TeamsService = service
		end
	end
end

local function getTeamNameFromService(player)
	if not TeamsService then
		return nil
	end
	local ok, teamInfo = pcall(TeamsService.GetPlayerTeam, TeamsService, player)
	if ok and typeof(teamInfo) == "table" and teamInfo.Name then
		return teamInfo.Name
	end
	return nil
end

local function getPlayerTeamName(player)
	local serviceTeam = getTeamNameFromService(player)
	if serviceTeam then
		return serviceTeam
	end

	local attributeTeam = player:GetAttribute("Team")
	if attributeTeam ~= nil then
		return tostring(attributeTeam)
	end

	local teamValue = player:FindFirstChild("Team") or player:FindFirstChild("TeamColor")
	if teamValue and teamValue:IsA("ValueBase") then
		return tostring(teamValue.Value)
	end

	return nil
end

local function isSameTeam(player)
	if player == LocalPlayer then
		return true
	end

	local localTeamName = getPlayerTeamName(LocalPlayer)
	local playerTeamName = getPlayerTeamName(player)
	if localTeamName and playerTeamName then
		return localTeamName == playerTeamName
	end

	return false
end

local function getTeamRelation(player)
	if player == LocalPlayer then
		return "Ally"
	end
	if isSameTeam(player) then
		return "Ally"
	end
	if not getPlayerTeamName(LocalPlayer) or not getPlayerTeamName(player) then
		return "Neutral"
	end
	return "Enemy"
end

local function getInstanceTeamRelation(instance, teamName)
	local localTeamName = getPlayerTeamName(LocalPlayer)
	if not localTeamName or not teamName then
		return "Neutral"
	end
	if localTeamName == teamName then
		return "Ally"
	end
	return "Enemy"
end

local function hasSpawnProtection(character, player)
	if not character then
		return true
	end
	if character:FindFirstChildOfClass("ForceField") then
		return true
	end
	if player and player:GetAttribute("InMenu") == true then
		return true
	end
	return false
end

local function isPlayerInCombat(player)
	if not player or player == LocalPlayer then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	return not hasSpawnProtection(character, player)
end

local function getDroneAimPart(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local collision = model:FindFirstChild("CollisionPart", true)
	if collision and collision:IsA("BasePart") then
		return collision
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function getTargetColor(target)
	if target.player then
		return TeamColors[getTeamRelation(target.player)]
	end
	if target.drone then
		local teamName = target.drone:GetAttribute("Team")
		return TeamColors[getInstanceTeamRelation(target.drone, teamName and tostring(teamName) or nil)]
	end
	return TeamColors.Enemy
end

local function setFOV(value)
	Config.FOV = math.clamp(math.floor(value), 50, 600)
	FOVSquared = Config.FOV * Config.FOV
end

-- Drawing objects
local Tracer = Drawing.new("Line")
Tracer.Visible = false
Tracer.Color = Color3.fromRGB(255, 255, 255)
Tracer.Thickness = 1.5
Tracer.Transparency = 0

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1
FOVCircle.NumSides = 48
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5
FOVCircle.Color = Color3.fromRGB(255, 255, 255)

local UI = {
	X = 16,
	Y = 16,
	Width = 318,
	HeaderHeight = 36,
	RowHeight = 20,
	SectionGap = 6,
	Padding = 12,
	ColGap = 10,
	Columns = 2,
	Dragging = false,
	DragOffset = Vector2.zero,
	Objects = {},
}

local HUD = {
	Width = 148,
	Padding = 10,
	LineHeight = 15,
	Objects = {},
}

local function createSquare(props)
	local sq = Drawing.new("Square")
	sq.Filled = props.Filled or false
	sq.Thickness = props.Thickness or 1
	sq.Color = props.Color or Color3.fromRGB(255, 255, 255)
	sq.Visible = false
	return sq
end

local function createText(props)
	local txt = Drawing.new("Text")
	txt.Size = props.Size or 14
	txt.Color = props.Color or Color3.fromRGB(255, 255, 255)
	txt.Outline = true
	txt.Center = props.Center or false
	txt.Visible = false
	return txt
end

local UI_THEME = {
	bg = Color3.fromRGB(10, 12, 18),
	header = Color3.fromRGB(24, 28, 46),
	accent = Color3.fromRGB(99, 102, 241),
	border = Color3.fromRGB(42, 48, 72),
	section = Color3.fromRGB(128, 134, 168),
	on = Color3.fromRGB(72, 220, 130),
	off = Color3.fromRGB(52, 56, 72),
	text = Color3.fromRGB(228, 232, 245),
	muted = Color3.fromRGB(118, 124, 150),
}

UI.Objects.Background = createSquare({
	Filled = true,
	Color = UI_THEME.bg,
	Thickness = 1,
})
UI.Objects.Background.Transparency = 0.05

UI.Objects.ModalOverlay = createSquare({
	Filled = true,
	Color = Color3.fromRGB(0, 0, 0),
	Thickness = 1,
})
UI.Objects.ModalOverlay.Transparency = 0.5

UI.Objects.Border = createSquare({
	Filled = false,
	Color = UI_THEME.border,
	Thickness = 1,
})

UI.Objects.Header = createSquare({
	Filled = true,
	Color = UI_THEME.header,
	Thickness = 1,
})
UI.Objects.Header.Transparency = 0.1

UI.Objects.AccentLine = createSquare({
	Filled = true,
	Color = UI_THEME.accent,
	Thickness = 1,
})

UI.Objects.Title = createText({ Size = 16, Color = UI_THEME.text })
UI.Objects.DragHint = createText({ Size = 11, Color = UI_THEME.muted })

UI.Sections = {
	{
		title = "COMBAT",
		toggles = {
			{ key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
			{ key = "Teamcheck", label = "Team Check", hud = "Team Check" },
			{ key = "NoRecoil", label = "No Recoil", hud = "No Recoil" },
			{ key = "StableAim", label = "Stable Aim", hud = "Stable Aim" },
			{ key = "BulletTP", label = "Bullet TP", hud = "Bullet TP" },
		},
	},
	{
		title = "WEAPON",
		toggles = {
			{ key = "RapidFire", label = "Rapid Fire", hud = "Rapid Fire" },
			{ key = "InfiniteAmmo", label = "Inf Ammo", hud = "Inf Ammo" },
			{ key = "NoJam", label = "No Jam", hud = "No Jam" },
			{ key = "NoOverheat", label = "No Heat", hud = "No Heat" },
			{ key = "GrenadeSpam", label = "Grenade", hud = "Grenade" },
			{ key = "RocketSpam", label = "Rocket", hud = "Rocket" },
		},
	},
	{
		title = "MOVEMENT",
		toggles = {
			{ key = "Flight", label = "Flight", hud = "Flight" },
			{ key = "SpeedBoost", label = "Speed", hud = "Speed" },
			{ key = "InfiniteStamina", label = "Stamina", hud = "Stamina" },
		},
	},
	{
		title = "VISUAL",
		toggles = {
			{ key = "ESP", label = "ESP", hud = "ESP" },
			{ key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
			{ key = "Tracer", label = "Tracer", hud = "Tracer" },
			{ key = "FOVCircle", label = "FOV Circle", hud = "FOV Circle" },
			{ key = "ThermalESP", label = "Thermal", hud = "Thermal" },
			{ key = "HitMarkers", label = "Hit Markers", hud = "Hit Markers" },
			{ key = "ZoomBoost", label = "Zoom", hud = "Zoom" },
		},
	},
	{
		title = "CLIENT",
		toggles = {
			{ key = "NVG", label = "NVG", hud = "NVG" },
			{ key = "FishEye", label = "FishEye", hud = "FishEye" },
			{ key = "Comtacs", label = "Comtacs", hud = "Comtacs" },
			{ key = "NoSuppression", label = "No Suppress", hud = "No Suppress" },
			{ key = "StripShield", label = "Strip Shield", hud = "Strip Shield" },
			{ key = "FullBright", label = "Full Bright", hud = "Full Bright" },
			{ key = "ShowHUD", label = "Module HUD", hud = nil },
		},
	},
}

UI.Toggles = {}
for _, section in ipairs(UI.Sections) do
	for _, toggle in ipairs(section.toggles) do
		table.insert(UI.Toggles, toggle)
	end
end

UI.Objects.SectionLabels = {}
UI.Objects.SectionDots = {}
UI.Objects.SectionLines = {}
for sectionIndex in ipairs(UI.Sections) do
	UI.Objects.SectionLabels[sectionIndex] = createText({ Size = 11, Color = UI_THEME.section })
	UI.Objects.SectionDots[sectionIndex] = createSquare({
		Filled = true,
		Color = UI_THEME.accent,
		Thickness = 1,
	})
	UI.Objects.SectionLines[sectionIndex] = createSquare({
		Filled = true,
		Color = UI_THEME.border,
		Thickness = 1,
	})
end

UI.Objects.ToggleIndicators = {}
UI.Objects.ToggleLabels = {}
for _, toggle in ipairs(UI.Toggles) do
	UI.Objects.ToggleIndicators[toggle.key] = createSquare({ Filled = true, Thickness = 1 })
	UI.Objects.ToggleLabels[toggle.key] = createText({ Size = 14 })
end

UI.Objects.FOVLabel = createText({ Size = 13, Color = UI_THEME.text })
UI.Objects.FOVMinus = createSquare({ Filled = true, Color = UI_THEME.border })
UI.Objects.FOVPlus = createSquare({ Filled = true, Color = UI_THEME.border })
UI.Objects.FOVMinusText = createText({ Size = 15, Center = true, Color = UI_THEME.text })
UI.Objects.FOVPlusText = createText({ Size = 15, Center = true, Color = UI_THEME.text })
UI.Objects.Hint = createText({ Size = 10, Color = UI_THEME.muted })
UI.Objects.KillAllButton = createSquare({ Filled = true, Color = Color3.fromRGB(150, 42, 52) })
UI.Objects.KillAllText = createText({ Size = 13, Color = UI_THEME.text, Center = true })

HUD.Objects.Background = createSquare({ Filled = true, Color = Color3.fromRGB(8, 10, 16) })
HUD.Objects.Background.Transparency = 0.22
HUD.Objects.Border = createSquare({ Filled = false, Color = Color3.fromRGB(40, 48, 68), Thickness = 1 })
HUD.Objects.Accent = createSquare({ Filled = true, Color = Color3.fromRGB(72, 220, 130) })
HUD.Objects.Title = createText({ Size = 12, Color = Color3.fromRGB(195, 200, 220) })
HUD.Objects.Empty = createText({ Size = 12, Color = UI_THEME.muted })
HUD.Objects.Lines = {}

local function updateUIColor(indicator, enabled)
	indicator.Color = enabled and UI_THEME.on or UI_THEME.off
end

local function getColumnWidth()
	return (UI.Width - UI.Padding * 2 - UI.ColGap) / UI.Columns
end

local function getUIContentHeight()
	local height = UI.HeaderHeight + UI.Padding
	for _, section in ipairs(UI.Sections) do
		height += 18 + math.ceil(#section.toggles / UI.Columns) * UI.RowHeight + UI.SectionGap
	end
	return height + 76
end

local function getToggleRowPositions()
	local rows = {}
	local cursorY = UI.Y + UI.HeaderHeight + UI.Padding
	local colWidth = getColumnWidth()

	for _, section in ipairs(UI.Sections) do
		cursorY += 18
		for index = 1, #section.toggles, UI.Columns do
			local rowY = cursorY
			local left = section.toggles[index]
			local right = section.toggles[index + 1]

			if left then
				table.insert(rows, {
					key = left.key,
					y = rowY,
					x = UI.X + UI.Padding,
					width = colWidth,
				})
			end
			if right then
				table.insert(rows, {
					key = right.key,
					y = rowY,
					x = UI.X + UI.Padding + colWidth + UI.ColGap,
					width = colWidth,
				})
			end
			cursorY += UI.RowHeight
		end
		cursorY += UI.SectionGap
	end
	return rows
end

local function drawToggleAt(visible, toggle, posX, posY)
	local indicator = UI.Objects.ToggleIndicators[toggle.key]
	local label = UI.Objects.ToggleLabels[toggle.key]
	local enabled = Config[toggle.key]

	indicator.Position = Vector2.new(posX, posY + 2)
	indicator.Size = Vector2.new(10, 10)
	updateUIColor(indicator, enabled)
	indicator.Visible = visible

	label.Position = Vector2.new(posX + 14, posY)
	label.Text = toggle.label
	label.Color = enabled and UI_THEME.text or UI_THEME.muted
	label.Visible = visible
end

local function pointInRect(point, pos, size)
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local flightKeys = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
	[Enum.KeyCode.Space] = false,
	[Enum.KeyCode.LeftControl] = false,
	[Enum.KeyCode.RightControl] = false,
}

local function clearFlightKeys()
	for keyCode in pairs(flightKeys) do
		flightKeys[keyCode] = false
	end
end

local uiBlockedInputs = {
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseButton3,
	Enum.UserInputType.MouseMovement,
	Enum.UserInputType.MouseWheel,
}
for _, action in ipairs(Enum.PlayerActions:GetEnumItems()) do
	table.insert(uiBlockedInputs, action)
end

local function uiInputSink()
	return Enum.ContextActionResult.Sink
end

local function setUIInputBlocked(blocked)
	if blocked then
		ContextActionService:BindActionAtPriority(UI_INPUT_BLOCK, uiInputSink, false, 3000, table.unpack(uiBlockedInputs))
	else
		ContextActionService:UnbindAction(UI_INPUT_BLOCK)
	end
end

local function setMenuVisible(visible)
	uiVisible = visible
	if visible then
		clearFlightKeys()
		UI.Dragging = false
		savedMouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		setUIInputBlocked(true)
	else
		setUIInputBlocked(false)
		if savedMouseBehavior then
			UserInputService.MouseBehavior = savedMouseBehavior
			savedMouseBehavior = nil
		end
	end
end

local function isMouseOverMenu(mouse)
	local height = getUIContentHeight()
	return pointInRect(mouse, Vector2.new(UI.X, UI.Y), Vector2.new(UI.Width, height))
end

local function drawUI()
	local visible = uiVisible
	local x, y = UI.X, UI.Y
	local height = getUIContentHeight()
	local colWidth = getColumnWidth()
	local leftX = x + UI.Padding
	local rightX = leftX + colWidth + UI.ColGap
	local viewport = Camera.ViewportSize

	if visible then
		UI.Objects.ModalOverlay.Position = Vector2.new(0, 0)
		UI.Objects.ModalOverlay.Size = viewport
		UI.Objects.ModalOverlay.Visible = true
	else
		UI.Objects.ModalOverlay.Visible = false
	end

	UI.Objects.Background.Position = Vector2.new(x, y)
	UI.Objects.Background.Size = Vector2.new(UI.Width, height)
	UI.Objects.Background.Visible = visible

	UI.Objects.Border.Position = Vector2.new(x, y)
	UI.Objects.Border.Size = Vector2.new(UI.Width, height)
	UI.Objects.Border.Visible = visible

	UI.Objects.Header.Position = Vector2.new(x, y)
	UI.Objects.Header.Size = Vector2.new(UI.Width, UI.HeaderHeight)
	UI.Objects.Header.Visible = visible

	UI.Objects.AccentLine.Position = Vector2.new(x, y + UI.HeaderHeight - 2)
	UI.Objects.AccentLine.Size = Vector2.new(UI.Width, 2)
	UI.Objects.AccentLine.Visible = visible

	UI.Objects.Title.Position = Vector2.new(x + UI.Padding, y + 9)
	UI.Objects.Title.Text = "WARFARE"
	UI.Objects.Title.Visible = visible

	UI.Objects.DragHint.Position = Vector2.new(x + UI.Width - 78, y + 11)
	UI.Objects.DragHint.Text = "RightShift"
	UI.Objects.DragHint.Visible = visible

	local cursorY = y + UI.HeaderHeight + UI.Padding
	for sectionIndex, section in ipairs(UI.Sections) do
		local sectionLabel = UI.Objects.SectionLabels[sectionIndex]
		local sectionDot = UI.Objects.SectionDots[sectionIndex]
		local sectionLine = UI.Objects.SectionLines[sectionIndex]

		sectionDot.Position = Vector2.new(x + UI.Padding, cursorY + 3)
		sectionDot.Size = Vector2.new(4, 4)
		sectionDot.Visible = visible

		sectionLabel.Position = Vector2.new(x + UI.Padding + 8, cursorY)
		sectionLabel.Text = section.title
		sectionLabel.Visible = visible

		sectionLine.Position = Vector2.new(x + UI.Padding + 68, cursorY + 7)
		sectionLine.Size = Vector2.new(UI.Width - UI.Padding * 2 - 68, 1)
		sectionLine.Visible = visible

		cursorY += 18

		for index = 1, #section.toggles, UI.Columns do
			local left = section.toggles[index]
			local right = section.toggles[index + 1]
			if left then
				drawToggleAt(visible, left, leftX, cursorY)
			end
			if right then
				drawToggleAt(visible, right, rightX, cursorY)
			elseif left then
				local label = UI.Objects.ToggleLabels[left.key]
				label.Visible = visible
			end
			cursorY += UI.RowHeight
		end

		cursorY += UI.SectionGap
	end

	local fovY = cursorY + 2
	UI.Objects.FOVLabel.Position = Vector2.new(x + UI.Padding, fovY)
	UI.Objects.FOVLabel.Text = "Silent FOV: " .. Config.FOV
	UI.Objects.FOVLabel.Visible = visible

	UI.Objects.FOVMinus.Position = Vector2.new(x + UI.Width - 58, fovY - 2)
	UI.Objects.FOVMinus.Size = Vector2.new(22, 18)
	UI.Objects.FOVMinus.Visible = visible

	UI.Objects.FOVMinusText.Position = Vector2.new(x + UI.Width - 47, fovY + 1)
	UI.Objects.FOVMinusText.Text = "-"
	UI.Objects.FOVMinusText.Visible = visible

	UI.Objects.FOVPlus.Position = Vector2.new(x + UI.Width - 32, fovY - 2)
	UI.Objects.FOVPlus.Size = Vector2.new(22, 18)
	UI.Objects.FOVPlus.Visible = visible

	UI.Objects.FOVPlusText.Position = Vector2.new(x + UI.Width - 21, fovY + 1)
	UI.Objects.FOVPlusText.Text = "+"
	UI.Objects.FOVPlusText.Visible = visible

	local killAllY = fovY + 22
	UI.Objects.KillAllButton.Position = Vector2.new(x + UI.Padding, killAllY)
	UI.Objects.KillAllButton.Size = Vector2.new(UI.Width - UI.Padding * 2, 22)
	UI.Objects.KillAllButton.Visible = visible

	UI.Objects.KillAllText.Position = Vector2.new(x + UI.Width * 0.5, killAllY + 4)
	UI.Objects.KillAllText.Text = killAllRunning and "Kill All (running...)" or "Kill All"
	UI.Objects.KillAllText.Visible = visible

	UI.Objects.Hint.Position = Vector2.new(x + UI.Padding, killAllY + 26)
	UI.Objects.Hint.Text = "Flight: WASD / Space / Ctrl / Shift"
	UI.Objects.Hint.Visible = visible
end

local function getFooterFovY()
	return UI.Y + getUIContentHeight() - 74
end

local function getKillAllButtonRect()
	local fovY = getFooterFovY()
	return Vector2.new(UI.X + UI.Padding, fovY + 22), Vector2.new(UI.Width - UI.Padding * 2, 22)
end

local function getEnabledHudModules()
	local modules = {}
	for _, toggle in ipairs(UI.Toggles) do
		if toggle.hud and Config[toggle.key] then
			table.insert(modules, toggle.hud)
		end
	end
	return modules
end

local function ensureHudLines(count)
	while #HUD.Objects.Lines < count do
		table.insert(HUD.Objects.Lines, createText({ Size = 13, Color = Color3.fromRGB(80, 255, 140) }))
	end
end

local function setHudVisible(show)
	HUD.Objects.Background.Visible = show
	HUD.Objects.Border.Visible = show
	HUD.Objects.Accent.Visible = show
	HUD.Objects.Title.Visible = show
	HUD.Objects.Empty.Visible = false
	for _, line in ipairs(HUD.Objects.Lines) do
		line.Visible = false
	end
end

local function drawHUD()
	if not Config.ShowHUD then
		setHudVisible(false)
		return
	end

	local modules = getEnabledHudModules()
	ensureHudLines(#modules)

	local viewport = Camera.ViewportSize
	local moduleCount = math.max(#modules, 1)
	local height = 24 + moduleCount * HUD.LineHeight + HUD.Padding
	local hudX = viewport.X - HUD.Width - 14
	local hudY = 14

	HUD.Objects.Background.Position = Vector2.new(hudX, hudY)
	HUD.Objects.Background.Size = Vector2.new(HUD.Width, height)
	HUD.Objects.Background.Visible = true

	HUD.Objects.Border.Position = Vector2.new(hudX, hudY)
	HUD.Objects.Border.Size = Vector2.new(HUD.Width, height)
	HUD.Objects.Border.Visible = true

	HUD.Objects.Accent.Position = Vector2.new(hudX, hudY)
	HUD.Objects.Accent.Size = Vector2.new(3, height)
	HUD.Objects.Accent.Visible = true

	HUD.Objects.Title.Position = Vector2.new(hudX + HUD.Padding + 4, hudY + 5)
	HUD.Objects.Title.Text = "ACTIVE"
	HUD.Objects.Title.Visible = true

	if #modules == 0 then
		HUD.Objects.Empty.Position = Vector2.new(hudX + HUD.Padding + 6, hudY + 22)
		HUD.Objects.Empty.Text = "none"
		HUD.Objects.Empty.Visible = true
		for _, line in ipairs(HUD.Objects.Lines) do
			line.Visible = false
		end
		return
	end

	HUD.Objects.Empty.Visible = false
	for index, name in ipairs(modules) do
		local line = HUD.Objects.Lines[index]
		line.Position = Vector2.new(hudX + HUD.Padding + 6, hudY + 20 + (index - 1) * HUD.LineHeight)
		line.Text = name
		line.Visible = true
	end
	for index = #modules + 1, #HUD.Objects.Lines do
		HUD.Objects.Lines[index].Visible = false
	end
end

local function handleUIClick(mouse)
	if not uiVisible or UI.Dragging then
		return
	end
	if not isMouseOverMenu(mouse) then
		return
	end

	local x = UI.X

	for _, row in ipairs(getToggleRowPositions()) do
		if pointInRect(mouse, Vector2.new(row.x, row.y - 2), Vector2.new(row.width, 16)) then
			Config[row.key] = not Config[row.key]
			return
		end
	end

	local fovY = getFooterFovY()
	if pointInRect(mouse, Vector2.new(x + UI.Width - 58, fovY - 2), Vector2.new(22, 18)) then
		setFOV(Config.FOV - 25)
	elseif pointInRect(mouse, Vector2.new(x + UI.Width - 32, fovY - 2), Vector2.new(22, 18)) then
		setFOV(Config.FOV + 25)
	end

	local killAllPos, killAllSize = getKillAllButtonRect()
	if pointInRect(mouse, killAllPos, killAllSize) and not killAllRunning then
		task.spawn(runKillAll)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.RightShift then
		setMenuVisible(not uiVisible)
		return
	end
	if not uiVisible then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mouse = UserInputService:GetMouseLocation()
		if pointInRect(mouse, Vector2.new(UI.X, UI.Y), Vector2.new(UI.Width, UI.HeaderHeight)) then
			UI.Dragging = true
			UI.DragOffset = mouse - Vector2.new(UI.X, UI.Y)
			return
		end
		handleUIClick(mouse)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		UI.Dragging = false
	end
end)

RunService.RenderStepped:Connect(function()
	if not UI.Dragging then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	UI.X = math.clamp(mouse.X - UI.DragOffset.X, 0, Camera.ViewportSize.X - UI.Width)
	UI.Y = math.clamp(mouse.Y - UI.DragOffset.Y, 0, Camera.ViewportSize.Y - getUIContentHeight())
end)

local flightSavedState = nil
local flightLinearVelocity = nil

local function setFlightKey(keyCode, pressed)
	if flightKeys[keyCode] ~= nil then
		flightKeys[keyCode] = pressed
	end
end

local function removeFlightConstraint(root)
	if flightLinearVelocity then
		flightLinearVelocity:Destroy()
		flightLinearVelocity = nil
	end
	if root then
		local att = root:FindFirstChild("WarfareFlightAtt")
		if att then
			att:Destroy()
		end
	end
end

local function ensureFlightConstraint(root)
	local att = root:FindFirstChild("WarfareFlightAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "WarfareFlightAtt"
		att.Parent = root
	end
	if not flightLinearVelocity or flightLinearVelocity.Parent ~= root then
		if flightLinearVelocity then
			flightLinearVelocity:Destroy()
		end
		flightLinearVelocity = Instance.new("LinearVelocity")
		flightLinearVelocity.Name = "WarfareFlightLV"
		flightLinearVelocity.Attachment0 = att
		flightLinearVelocity.MaxForce = math.huge
		flightLinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		flightLinearVelocity.Parent = root
	end
	return flightLinearVelocity
end

local function restoreFlightState(character)
	if not flightSavedState then
		removeFlightConstraint(character and character:FindFirstChild("HumanoidRootPart"))
		return
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid.PlatformStand = flightSavedState.PlatformStand
		humanoid.AutoRotate = flightSavedState.AutoRotate
		humanoid.WalkSpeed = flightSavedState.WalkSpeed
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end

	removeFlightConstraint(root)

	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end

	flightSavedState = nil
end

local function applyFlightWeaponPatch()
	if not Config.Flight then
		return
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end

	local t2 = weaponStateRef
	if not t2 then
		return
	end

	if t2.humanoid then
		t2.humanoid.PlatformStand = false
	end
	if t2.States then
		t2.States.Climbing = false
		t2.States.Sprinting = false
	end
end

local function getFlightDirection()
	local move = Vector3.zero
	local cam = Camera.CFrame
	local forward = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
	local right = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z)

	if forward.Magnitude > 0.01 then
		forward = forward.Unit
	else
		forward = Vector3.new(0, 0, -1)
	end
	if right.Magnitude > 0.01 then
		right = right.Unit
	end

	if flightKeys[Enum.KeyCode.W] then
		move += forward
	end
	if flightKeys[Enum.KeyCode.S] then
		move -= forward
	end
	if flightKeys[Enum.KeyCode.D] then
		move += right
	end
	if flightKeys[Enum.KeyCode.A] then
		move -= right
	end
	if flightKeys[Enum.KeyCode.Space] then
		move += Vector3.yAxis
	end
	if flightKeys[Enum.KeyCode.LeftControl] or flightKeys[Enum.KeyCode.RightControl] then
		move -= Vector3.yAxis
	end

	if move.Magnitude < 0.01 then
		return Vector3.zero
	end
	return move.Unit
end

local function updateFlight()
	if not Config.Flight or uiVisible then
		if uiVisible and Config.Flight then
			clearFlightKeys()
		end
		if not Config.Flight then
			restoreFlightState(LocalPlayer.Character)
		end
		return
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		restoreFlightState(character)
		return
	end

	if not flightSavedState then
		flightSavedState = {
			PlatformStand = humanoid.PlatformStand,
			AutoRotate = humanoid.AutoRotate,
			WalkSpeed = humanoid.WalkSpeed,
		}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	local direction = getFlightDirection()
	local speed = FLIGHT_SPEED
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		speed = FLIGHT_BOOST_SPEED
	end

	local linearVelocity = ensureFlightConstraint(root)
	linearVelocity.VectorVelocity = direction * speed
	root.AssemblyAngularVelocity = Vector3.zero

	applyFlightWeaponPatch()
end

UserInputService.InputBegan:Connect(function(input)
	if uiVisible then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		setFlightKey(input.KeyCode, true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if uiVisible then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		setFlightKey(input.KeyCode, false)
	end
end)

setMenuVisible(uiVisible)

LocalPlayer.CharacterAdded:Connect(function(character)
	flightSavedState = nil
	flightLinearVelocity = nil
	for keyCode in pairs(flightKeys) do
		flightKeys[keyCode] = false
	end
	if not Config.Flight then
		character:WaitForChild("Humanoid", 10)
		task.defer(restoreFlightState, character)
	end
end)

-- ESP
local espCache = {}
local droneEspCache = {}
local teamNameCache = {}
local espWasEnabled = false
local cameraPosCache = Vector3.zero
local jamGuardConn = nil
local jamGuardTarget = nil
local rapidFireTool = nil
local rapidFireBaseInterval = nil

local function hideEspEntry(entry)
	entry.Box.Visible = false
	entry.Name.Visible = false
	entry.Team.Visible = false
	entry.HealthText.Visible = false
	entry.HealthBarBg.Visible = false
	entry.HealthBarFill.Visible = false
	entry.Distance.Visible = false
	entry.Snapline.Visible = false
	entry.Head.Visible = false
end

local function removeEsp(player)
	local entry = espCache[player]
	if not entry then
		return
	end
	entry.Box:Remove()
	entry.Name:Remove()
	entry.Team:Remove()
	entry.HealthText:Remove()
	entry.HealthBarBg:Remove()
	entry.HealthBarFill:Remove()
	entry.Distance:Remove()
	entry.Snapline:Remove()
	entry.Head:Remove()
	espCache[player] = nil
end

local function removeDroneEsp(model)
	local entry = droneEspCache[model]
	if not entry then
		return
	end
	entry.Box:Remove()
	entry.Label:Remove()
	droneEspCache[model] = nil
end

local function ensureEsp(player)
	if espCache[player] then
		return espCache[player]
	end

	local box = Drawing.new("Square")
	box.Filled = false
	box.Thickness = 1.5
	box.Visible = false

	local name = Drawing.new("Text")
	name.Size = 14
	name.Outline = true
	name.Center = true
	name.Visible = false

	local team = Drawing.new("Text")
	team.Size = 12
	team.Outline = true
	team.Center = true
	team.Visible = false

	local healthText = Drawing.new("Text")
	healthText.Size = 12
	healthText.Outline = true
	healthText.Center = true
	healthText.Visible = false

	local healthBarBg = Drawing.new("Square")
	healthBarBg.Filled = true
	healthBarBg.Thickness = 1
	healthBarBg.Color = Color3.fromRGB(30, 30, 30)
	healthBarBg.Visible = false

	local healthBarFill = Drawing.new("Square")
	healthBarFill.Filled = true
	healthBarFill.Thickness = 1
	healthBarFill.Visible = false

	local distance = Drawing.new("Text")
	distance.Size = 12
	distance.Outline = true
	distance.Center = true
	distance.Visible = false

	local snapline = Drawing.new("Line")
	snapline.Thickness = 1
	snapline.Visible = false

	local head = Drawing.new("Circle")
	head.Filled = true
	head.NumSides = 12
	head.Radius = 3
	head.Visible = false

	espCache[player] = {
		Box = box,
		Name = name,
		Team = team,
		HealthText = healthText,
		HealthBarBg = healthBarBg,
		HealthBarFill = healthBarFill,
		Distance = distance,
		Snapline = snapline,
		Head = head,
	}
	return espCache[player]
end

local function ensureDroneEsp(model)
	if droneEspCache[model] then
		return droneEspCache[model]
	end

	local box = Drawing.new("Square")
	box.Filled = false
	box.Thickness = 1.5
	box.Visible = false

	local label = Drawing.new("Text")
	label.Size = 12
	label.Outline = true
	label.Center = true
	label.Visible = false

	droneEspCache[model] = { Box = box, Label = label }
	return droneEspCache[model]
end

Players.PlayerRemoving:Connect(removeEsp)

local function getCachedTeamName(player)
	local cached = teamNameCache[player]
	local now = tick()
	if cached and now - cached.t < 2 then
		return cached.name
	end
	local name = getPlayerTeamName(player)
	teamNameCache[player] = { name = name, t = now }
	return name
end

local function getBoundingBox2D(character)
	local cf, size = character:GetBoundingBox()
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyVisible = false

	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local world = (cf * CFrame.new(hx * sx, hy * sy, hz * sz)).Position
				local screenPos, onScreen = Camera:WorldToViewportPoint(world)
				if onScreen and screenPos.Z > 0 then
					anyVisible = true
					minX = math.min(minX, screenPos.X)
					minY = math.min(minY, screenPos.Y)
					maxX = math.max(maxX, screenPos.X)
					maxY = math.max(maxY, screenPos.Y)
				end
			end
		end
	end

	if not anyVisible then
		return nil
	end

	return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

local function drawPlayerEsp(player, character, humanoid)
	local relation = getTeamRelation(player)
	if relation == "Ally" and not Config.ESPAllies then
		local entry = espCache[player]
		if entry then
			hideEspEntry(entry)
		end
		return
	end

	local color = TeamColors[relation]
	local topLeft, boxSize = getBoundingBox2D(character)
	if not topLeft then
		local entry = espCache[player]
		if entry then
			hideEspEntry(entry)
		end
		return
	end

	local entry = ensureEsp(player)
	local centerX = topLeft.X + boxSize.X * 0.5
	local bottomY = topLeft.Y + boxSize.Y

	entry.Box.Position = topLeft
	entry.Box.Size = boxSize
	entry.Box.Color = color
	entry.Box.Visible = true

	entry.Name.Position = Vector2.new(centerX, topLeft.Y - 16)
	entry.Name.Text = player.DisplayName
	entry.Name.Color = color
	entry.Name.Visible = true

	local teamName = getCachedTeamName(player)
	entry.Team.Position = Vector2.new(centerX, topLeft.Y - 30)
	entry.Team.Text = (teamName or relation) .. " (" .. relation .. ")"
	entry.Team.Color = color
	entry.Team.Visible = true

	local health = humanoid.Health
	local maxHealth = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
	local healthRatio = math.clamp(health / maxHealth, 0, 1)
	local barWidth = math.max(36, boxSize.X)
	local barHeight = 4
	local barX = centerX - barWidth * 0.5
	local barY = bottomY + 4

	entry.HealthBarBg.Position = Vector2.new(barX, barY)
	entry.HealthBarBg.Size = Vector2.new(barWidth, barHeight)
	entry.HealthBarBg.Visible = true

	entry.HealthBarFill.Position = Vector2.new(barX, barY)
	entry.HealthBarFill.Size = Vector2.new(barWidth * healthRatio, barHeight)
	entry.HealthBarFill.Color = Color3.fromRGB(255 * (1 - healthRatio), 255 * healthRatio, 60)
	entry.HealthBarFill.Visible = true

	entry.HealthText.Position = Vector2.new(centerX, barY + 6)
	entry.HealthText.Text = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
	entry.HealthText.Color = color
	entry.HealthText.Visible = true

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local dist = (root.Position - cameraPosCache).Magnitude
		entry.Distance.Position = Vector2.new(centerX, barY + 20)
		entry.Distance.Text = string.format("%dm", math.floor(dist))
		entry.Distance.Color = color
		entry.Distance.Visible = true
	end

	local viewport = Camera.ViewportSize
	entry.Snapline.From = Vector2.new(viewport.X * 0.5, viewport.Y)
	entry.Snapline.To = Vector2.new(centerX, bottomY)
	entry.Snapline.Color = color
	entry.Snapline.Visible = true

	local head = character:FindFirstChild("Head")
	if head then
		local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
		if headOnScreen and headPos.Z > 0 then
			entry.Head.Position = Vector2.new(headPos.X, headPos.Y)
			entry.Head.Color = color
			entry.Head.Visible = true
		else
			entry.Head.Visible = false
		end
	else
		entry.Head.Visible = false
	end
end

local function updateDroneESP()
	if not Config.ESP then
		for _, entry in pairs(droneEspCache) do
			entry.Box.Visible = false
			entry.Label.Visible = false
		end
		return
	end

	local droneFolder = workspace:FindFirstChild("DroneWorkspace")
	if not droneFolder then
		for model, entry in pairs(droneEspCache) do
			removeDroneEsp(model)
		end
		return
	end

	local seen = {}
	for _, model in ipairs(droneFolder:GetChildren()) do
		if not model:IsA("Model") then
			continue
		end

		seen[model] = true
		local teamName = model:GetAttribute("Team")
		local relation = getInstanceTeamRelation(model, teamName and tostring(teamName) or nil)
		if relation == "Ally" and not Config.ESPAllies then
			local entry = droneEspCache[model]
			if entry then
				entry.Box.Visible = false
				entry.Label.Visible = false
			end
			continue
		end

		local color = TeamColors[relation]
		local topLeft, boxSize = getBoundingBox2D(model)
		if not topLeft then
			local entry = droneEspCache[model]
			if entry then
				entry.Box.Visible = false
				entry.Label.Visible = false
			end
			continue
		end

		local entry = ensureDroneEsp(model)
		entry.Box.Position = topLeft
		entry.Box.Size = boxSize
		entry.Box.Color = color
		entry.Box.Visible = true

		entry.Label.Position = Vector2.new(topLeft.X + boxSize.X * 0.5, topLeft.Y - 14)
		entry.Label.Text = "Drone [" .. (teamName or relation) .. "]"
		entry.Label.Color = color
		entry.Label.Visible = true
	end

	for model in pairs(droneEspCache) do
		if not seen[model] or not model.Parent then
			removeDroneEsp(model)
		end
	end
end

local function updateESP()
	if not Config.ESP then
		for _, entry in pairs(espCache) do
			hideEspEntry(entry)
		end
		updateDroneESP()
		return
	end

	local activePlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not isPlayerInCombat(player) then
			local entry = espCache[player]
			if entry then
				hideEspEntry(entry)
			end
			continue
		end

		activePlayers[player] = true
		drawPlayerEsp(player, character, humanoid)
	end

	for player in pairs(espCache) do
		if not activePlayers[player] then
			removeEsp(player)
		end
	end

	updateDroneESP()
end

local function considerAimCandidate(closest, closestDistSq, worldPos, centerX, centerY, candidate)
	local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
	if not onScreen or screenPos.Z <= 0 then
		return closest, closestDistSq
	end

	local dx = screenPos.X - centerX
	local dy = screenPos.Y - centerY
	local distSq = dx * dx + dy * dy
	if distSq >= closestDistSq then
		return closest, closestDistSq
	end

	candidate.position = worldPos
	candidate.screenPos = Vector2.new(screenPos.X, screenPos.Y)
	return candidate, distSq
end

local function buildTargetFromPlayer(player)
	local character = player.Character
	if not character then
		return nil
	end

	local part = character:FindFirstChild(AimPart) or character:FindFirstChild("HumanoidRootPart")
	if not part then
		return nil
	end

	local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
	return {
		player = player,
		drone = nil,
		part = part,
		character = character,
		position = part.Position,
		screenPos = Vector2.new(screenPos.X, screenPos.Y),
		onScreen = onScreen,
	}
end

local function getActiveAimTarget()
	if killAllForcedTarget then
		local part = killAllForcedTarget.part
		if part and part.Parent then
			killAllForcedTarget.position = part.Position
			return killAllForcedTarget
		end
		killAllForcedTarget = nil
	end
	return currentTarget
end

local function getKillablePlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end
		if not isPlayerInCombat(player) then
			continue
		end
		if Config.Teamcheck and isSameTeam(player) then
			continue
		end
		table.insert(list, player)
	end
	return list
end

local function setKillAllNoclip(enabled)
	killAllNoclip = enabled
	local character = LocalPlayer.Character
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = not enabled
		end
	end
end

local function teleportBehindTarget(targetRoot)
	local character = LocalPlayer.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not myRoot or not targetRoot then
		return
	end

	local flatLook = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = (myRoot.Position - targetRoot.Position).Unit
		flatLook = Vector3.new(flatLook.X, 0, flatLook.Z)
	end
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, 1)
	else
		flatLook = flatLook.Unit
	end

	local behindPos = targetRoot.Position - flatLook * 4.5 + Vector3.new(0, 1.5, 0)
	myRoot.CFrame = CFrame.new(behindPos, targetRoot.Position)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero
end

local function tryAutoFireWeapon()
	local t2 = weaponStateRef or discoverWeaponState()
	if not t2 then
		return false
	end

	if typeof(t2.TryFireOnce) == "function" then
		local ok = pcall(t2.TryFireOnce, t2)
		if ok then
			return true
		end
	end
	if typeof(t2.FireShot) == "function" then
		local ok = pcall(t2.FireShot, t2)
		if ok then
			return true
		end
	end

	for key, value in pairs(t2) do
		if typeof(key) == "string" and typeof(value) == "function" then
			if key == "TryFireOnce" or key == "FireShot" or key == "Fire" then
				local ok = pcall(value, t2)
				if ok then
					return true
				end
			end
		end
	end

	local mouse = UserInputService:GetMouseLocation()
	local ok = pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0)
		vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0)
	end)
	return ok
end

local function orbitAndKillPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not targetRoot or humanoid.Health <= 0 then
		return
	end

	local spinDuration = 2.8
	local spinSpeed = 11
	local startTime = tick()
	local lastShot = 0

	while tick() - startTime < spinDuration do
		if not player.Parent or not isPlayerInCombat(player) then
			break
		end

		character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not targetRoot or humanoid.Health <= 0 then
			break
		end

		killAllForcedTarget = buildTargetFromPlayer(player)
		currentTarget = killAllForcedTarget
		if not killAllForcedTarget then
			break
		end

		local elapsed = tick() - startTime
		local angle = elapsed * spinSpeed
		local radius = 5.5
		local offset = Vector3.new(math.sin(angle) * radius, 2.25, math.cos(angle) * radius)

		local myCharacter = LocalPlayer.Character
		local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
		if myRoot then
			local orbitPos = targetRoot.Position + offset
			myRoot.CFrame = CFrame.new(orbitPos, targetRoot.Position)
			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero
		end

		Camera.CFrame = CFrame.new(Camera.CFrame.Position, killAllForcedTarget.position)

		if tick() - lastShot > 0.1 then
			tryAutoFireWeapon()
			lastShot = tick()
		end

		task.wait()
	end
end

runKillAll = function()
	if killAllRunning then
		return
	end

	local targets = getKillablePlayers()
	if #targets == 0 then
		return
	end

	killAllRunning = true
	setMenuVisible(false)
	setKillAllNoclip(true)

	local savedBulletTP = Config.BulletTP
	local savedSilentAim = Config.SilentAim
	Config.BulletTP = true
	Config.SilentAim = true

	for _, player in ipairs(targets) do
		if not isPlayerInCombat(player) then
			continue
		end

		local targetRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			teleportBehindTarget(targetRoot)
			task.wait(0.06)
		end

		orbitAndKillPlayer(player)
		task.wait(0.08)
	end

	killAllForcedTarget = nil
	Config.BulletTP = savedBulletTP
	Config.SilentAim = savedSilentAim
	setKillAllNoclip(false)
	killAllRunning = false
end

local function getClosestTarget()
	if killAllForcedTarget then
		local part = killAllForcedTarget.part
		if part and part.Parent then
			killAllForcedTarget.position = part.Position
			return killAllForcedTarget
		end
		killAllForcedTarget = nil
	end

	if not Config.SilentAim and not Config.BulletTP then
		return nil
	end

	local closest = nil
	local closestDistSq = FOVSquared
	local viewport = Camera.ViewportSize
	local centerX = viewport.X * 0.5
	local centerY = viewport.Y * 0.5

	for _, player in ipairs(Players:GetPlayers()) do
		if not isPlayerInCombat(player) then
			continue
		end
		if Config.Teamcheck and isSameTeam(player) then
			continue
		end

		local character = player.Character
		local part = character:FindFirstChild(AimPart) or character:FindFirstChild("HumanoidRootPart")
		if not part then
			continue
		end

		local candidate = { player = player, drone = nil }
		closest, closestDistSq = considerAimCandidate(
			closest,
			closestDistSq,
			part.Position,
			centerX,
			centerY,
			candidate
		)
	end

	local droneFolder = workspace:FindFirstChild("DroneWorkspace")
	if droneFolder then
		for _, model in ipairs(droneFolder:GetChildren()) do
			if not model:IsA("Model") then
				continue
			end

			local teamName = model:GetAttribute("Team")
			local relation = getInstanceTeamRelation(model, teamName and tostring(teamName) or nil)
			if Config.Teamcheck and relation == "Ally" then
				continue
			end

			local part = getDroneAimPart(model)
			if not part then
				continue
			end

			local candidate = { player = nil, drone = model }
			closest, closestDistSq = considerAimCandidate(
				closest,
				closestDistSq,
				part.Position,
				centerX,
				centerY,
				candidate
			)
		end
	end

	return closest
end

local ViewmodelController = require(Modules:WaitForChild("ViewmodelController"))
local BobbleClass = require(Modules:WaitForChild("Bobble"))
local CameraFeedbackClass = require(Modules:WaitForChild("CameraFeedback"))
local SpringClass = require(Modules:WaitForChild("Spring"))

local STABLE_AIM_MULTIPLIERS = {
	AimSway = 0,
	SwayMult = 0,
	AimingTime = 1,
	StaminaDrainRateMult = 1000,
	StaminaMaxMult = 1000,
	StaminaDrainRate = 1000,
	MaxStamina = 1000,
}

local stableAimMouse = setmetatable({
	GetMouseDelta = function()
		return Vector2.zero
	end,
}, {
	__index = UserInputService,
})

local function applyStableAimMultipliers()
	if not Config.StableAim then
		return
	end
	for key, value in pairs(STABLE_AIM_MULTIPLIERS) do
		ViewmodelController.ChangeMultiplier(key, value)
	end
end

local nvgRefs = { ready = false, pvs = nil, grain = nil }
local lightingSaved = nil

local function resolveNVGGui()
	if nvgRefs.ready then
		return nvgRefs.pvs ~= nil
	end
	nvgRefs.ready = true

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local main = playerGui and playerGui:FindFirstChild("Main")
	local canvas = main and main:FindFirstChild("CanvasInGame")
	local nvg = canvas and canvas:FindFirstChild("NVG")
	if not nvg then
		return false
	end

	nvgRefs.pvs = nvg:FindFirstChild("PVS-14")
	nvgRefs.grain = nvg:FindFirstChild("Grain")
	return nvgRefs.pvs ~= nil
end

local function applyClientVisuals()
	if Config.NVG or Config.FishEye then
		if resolveNVGGui() and nvgRefs.pvs then
			nvgRefs.pvs.Visible = Config.NVG or Config.FishEye
			if nvgRefs.grain then
				nvgRefs.grain.Visible = Config.NVG or Config.FishEye
			end
		end
	elseif resolveNVGGui() and nvgRefs.pvs then
		nvgRefs.pvs.Visible = false
		if nvgRefs.grain then
			nvgRefs.grain.Visible = false
		end
	end

	LocalPlayer:SetAttribute("FishEye", Config.FishEye == true)

	local basic = SoundService:FindFirstChild("Basic")
	local comtacs = basic and basic:FindFirstChild("Comtacs")
	if comtacs then
		comtacs.Enabled = Config.Comtacs
	end

	if Config.NoSuppression then
		for _, effectName in ipairs({ "ADBlurEffect", "ADCCEffect", "BlurEffect" }) do
			local effect = Lighting:FindFirstChild(effectName)
			if effect then
				if effect:IsA("BlurEffect") then
					effect.Size = 0
				end
				if effect:IsA("PostEffect") then
					effect.Enabled = false
				end
			end
		end
		local suppressionBlur = Camera:FindFirstChild("SuppressionBlur")
		if suppressionBlur and suppressionBlur:IsA("BlurEffect") then
			suppressionBlur.Size = 0
			suppressionBlur.Enabled = false
		end
	end

	if Config.StripShield then
		local character = LocalPlayer.Character
		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("ForceField") then
					child:Destroy()
				end
			end
		end
	end

	if Config.FullBright then
		if not lightingSaved then
			lightingSaved = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				ExposureCompensation = Lighting.ExposureCompensation,
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
		end
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.ExposureCompensation = 0.6
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
	elseif lightingSaved then
		Lighting.Brightness = lightingSaved.Brightness
		Lighting.ClockTime = lightingSaved.ClockTime
		Lighting.ExposureCompensation = lightingSaved.ExposureCompensation
		Lighting.Ambient = lightingSaved.Ambient
		Lighting.OutdoorAmbient = lightingSaved.OutdoorAmbient
	end
end

RunService.RenderStepped:Connect(function(dt)
	currentTarget = getClosestTarget()
	drawUI()
	drawHUD()
	applyClientVisuals()
	applyStableAimMultipliers()
	applyCombatMods()

	if espWasEnabled and not Config.ESP then
		updateESP()
	end
	espWasEnabled = Config.ESP

	if Config.ESP then
		cameraPosCache = Camera.CFrame.Position
		updateESP()
	end

	if Config.ThermalESP then
		updateThermalHighlights()
	end
	updateHitMarkers()

	local viewport = Camera.ViewportSize
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)

	FOVCircle.Position = center
	FOVCircle.Radius = Config.FOV
	FOVCircle.Visible = Config.FOVCircle and Config.SilentAim

	if Config.Tracer and currentTarget then
		Tracer.From = Vector2.new(center.X, viewport.Y)
		Tracer.To = currentTarget.screenPos
		Tracer.Color = getTargetColor(currentTarget)
		Tracer.Visible = true
	else
		Tracer.Visible = false
	end
end)

local RECOIL_CONTROLLER_NAMES = {
	"RecoilModule",
	"RecoilController",
	"GunRecoil",
	"WeaponRecoil",
	"ViewmodelRecoil",
}

local RECOIL_CAMERA_NAMES = {
	"RecoilCamera",
	"CameraRecoil",
	"RecoilShake",
	"CameraShakeRecoil",
}

local hookedRecoilFunctions = {}

local function isRecoilControllerModule(moduleTable)
	return typeof(moduleTable) == "table"
		and typeof(moduleTable.Kick) == "function"
		and typeof(moduleTable.Update) == "function"
		and typeof(moduleTable.GetSpreadDegrees) == "function"
		and typeof(moduleTable.new) == "function"
end

local function isRecoilCameraModule(moduleTable)
	return typeof(moduleTable) == "table"
		and typeof(moduleTable.Recoil) == "function"
		and typeof(moduleTable.Kick) ~= "function"
end

local function collectModuleRoots()
	local roots = {}
	local seen = {}

	local function addRoot(root)
		if root and not seen[root] then
			seen[root] = true
			table.insert(roots, root)
		end
	end

	addRoot(Modules)

	local framework = ReplicatedStorage:FindFirstChild("Framework")
	if framework then
		addRoot(framework:FindFirstChild("Modules"))
	end

	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("Folder") and descendant.Name == "Modules" then
			addRoot(descendant)
		end
	end

	return roots
end

local function tryRequireModuleScript(moduleScript)
	if not moduleScript:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if ok then
		return result
	end
	return nil
end

local function findRecoilModules()
	local controllers = {}
	local cameras = {}
	local controllerSeen = {}
	local cameraSeen = {}

	local function addController(moduleTable, sourceName)
		if moduleTable and not controllerSeen[moduleTable] then
			controllerSeen[moduleTable] = true
			table.insert(controllers, { module = moduleTable, name = sourceName })
		end
	end

	local function addCamera(moduleTable, sourceName)
		if moduleTable and not cameraSeen[moduleTable] then
			cameraSeen[moduleTable] = true
			table.insert(cameras, { module = moduleTable, name = sourceName })
		end
	end

	local function inspectModuleScript(moduleScript)
		local lowerName = moduleScript.Name:lower()
		if lowerName:find("profile") then
			return
		end

		local moduleTable = tryRequireModuleScript(moduleScript)
		if not moduleTable then
			return
		end

		if isRecoilControllerModule(moduleTable) then
			addController(moduleTable, moduleScript:GetFullName())
		elseif isRecoilCameraModule(moduleTable) then
			addCamera(moduleTable, moduleScript:GetFullName())
		end
	end

	for _, root in ipairs(collectModuleRoots()) do
		for _, name in ipairs(RECOIL_CONTROLLER_NAMES) do
			local child = root:FindFirstChild(name)
			if child then
				inspectModuleScript(child)
			end
		end

		for _, name in ipairs(RECOIL_CAMERA_NAMES) do
			local child = root:FindFirstChild(name)
			if child then
				inspectModuleScript(child)
			end
		end

		for _, child in ipairs(root:GetDescendants()) do
			if child:IsA("ModuleScript") and child.Name:lower():find("recoil") then
				inspectModuleScript(child)
			end
		end
	end

	return controllers, cameras
end

local function hookModuleMethod(moduleTable, methodName, handler)
	local target = moduleTable[methodName]
	if typeof(target) ~= "function" or hookedRecoilFunctions[target] then
		return
	end
	if isfunctionhooked(target) then
		restorefunction(target)
	end
	local old
	old = hookfunction(
		target,
		newcclosure(function(...)
			return handler(old, ...)
		end, methodName)
	)
	hookedRecoilFunctions[target] = true
end

local function installStableAimHooks()
	hookModuleMethod(ViewmodelController, "ChangeMultiplier", function(old, key, value)
		if Config.StableAim then
			local override = STABLE_AIM_MULTIPLIERS[key]
			if override ~= nil then
				return old(key, override)
			end
			if key == "AimSway" or key == "SwayMult" then
				return old(key, 0)
			end
		end
		return old(key, value)
	end)

	hookModuleMethod(ViewmodelController, "FireKick", function(old, state, ...)
		if Config.StableAim then
			return
		end
		return old(state, ...)
	end)

	hookModuleMethod(ViewmodelController, "Render", function(old, dt, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18)
		if Config.StableAim then
			p14 = stableAimMouse
		end
		return old(dt, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18)
	end)

	hookModuleMethod(BobbleClass, "Update", function(old, self, dt)
		if Config.StableAim then
			return CFrame.new()
		end
		return old(self, dt)
	end)

	hookModuleMethod(BobbleClass, "Trigger", function(old, self, ...)
		if Config.StableAim then
			return
		end
		return old(self, ...)
	end)

	hookModuleMethod(CameraFeedbackClass, "Update", function(old, self, dt, ...)
		if Config.StableAim then
			return CFrame.new(), 0
		end
		return old(self, dt, ...)
	end)

	hookModuleMethod(CameraFeedbackClass, "TriggerHitFlinch", function(old, self, ...)
		if Config.StableAim then
			return
		end
		return old(self, ...)
	end)

	local function zeroLike(value)
		if typeof(value) == "Vector3" then
			return Vector3.zero
		end
		return 0
	end

	hookModuleMethod(SpringClass, "SetTarget", function(old, self, target)
		if Config.StableAim then
			return old(self, zeroLike(target))
		end
		return old(self, target)
	end)

	hookModuleMethod(SpringClass, "Update", function(old, self, dt)
		if Config.StableAim then
			local zero = zeroLike(self.Position)
			self.Position = zero
			self.Velocity = zero
			self.Target = zero
			return zero
		end
		return old(self, dt)
	end)

	hookModuleMethod(SpringClass, "Shove", function(old, self, impulse)
		if Config.StableAim then
			return
		end
		return old(self, impulse)
	end)
end

local function installNoRecoilHooks()
	local controllers, cameras = findRecoilModules()

	for _, entry in ipairs(controllers) do
		local recoilModule = entry.module
		hookModuleMethod(recoilModule, "Kick", function(old, self, ...)
			if Config.NoRecoil then
				return
			end
			return old(self, ...)
		end)

		hookModuleMethod(recoilModule, "Update", function(old, self, dt)
			if Config.NoRecoil then
				return CFrame.new()
			end
			return old(self, dt)
		end)

		hookModuleMethod(recoilModule, "GetSpreadDegrees", function(old, self, ...)
			if Config.NoRecoil then
				return 0
			end
			return old(self, ...)
		end)

		hookModuleMethod(recoilModule, "GetAccumulatedPitch", function(old, self, ...)
			if Config.NoRecoil then
				return 0
			end
			return old(self, ...)
		end)

		hookModuleMethod(recoilModule, "GetCameraRecoil", function(old, self, ...)
			if Config.NoRecoil then
				return Vector2.zero
			end
			return old(self, ...)
		end)

		hookModuleMethod(recoilModule, "GetMisalignmentCF", function(old, self, ...)
			if Config.NoRecoil then
				return CFrame.new()
			end
			return old(self, ...)
		end)
	end

	for _, entry in ipairs(cameras) do
		hookModuleMethod(entry.module, "Recoil", function(old, ...)
			if Config.NoRecoil then
				return
			end
			return old(...)
		end)
	end

end

installNoRecoilHooks()
installStableAimHooks()

local function isLikelyRecoilModuleScript(moduleScript)
	if not moduleScript:IsA("ModuleScript") then
		return false
	end
	local name = moduleScript.Name
	local lowerName = name:lower()
	if lowerName:find("profile") then
		return false
	end
	if lowerName:find("recoil") then
		return true
	end
	for _, candidate in ipairs(RECOIL_CONTROLLER_NAMES) do
		if name == candidate then
			return true
		end
	end
	for _, candidate in ipairs(RECOIL_CAMERA_NAMES) do
		if name == candidate then
			return true
		end
	end
	return false
end

ReplicatedStorage.DescendantAdded:Connect(function(descendant)
	if isLikelyRecoilModuleScript(descendant) then
		installNoRecoilHooks()
	end
end)

task.defer(installNoRecoilHooks)
task.delay(2, installNoRecoilHooks)
task.delay(5, installNoRecoilHooks)

local MagazineController = nil
pcall(function()
	MagazineController = require(Modules:WaitForChild("MagazineController"))
end)

local nextWeaponDiscoveryAt = 0
local thermalHighlights = {}
local hitMarkerList = {}
local defaultExposure = nil
local savedAimFov = nil
local combatHooksInstalled = false
local movementHooksInstalled = false
local movementModuleRef = nil

local function readUpvalue(fn, index)
	if typeof(fn) ~= "function" or not debug or typeof(debug.getupvalue) ~= "function" then
		return nil, nil
	end
	local ok, first, second = pcall(debug.getupvalue, fn, index)
	if not ok or first == nil then
		return nil, nil
	end
	if typeof(first) == "string" then
		return first, second
	end
	if typeof(second) == "string" then
		return second, first
	end
	return "upvalue" .. tostring(index), first
end

local function isWeaponClientState(value)
	return typeof(value) == "table"
		and typeof(value.PerToolState) == "table"
		and typeof(value.Modules) == "table"
		and typeof(value.Modules.MagazineController) == "table"
		and typeof(value.States) == "table"
end

local function scanForWeaponState(value, visited, depth)
	if depth > 10 or typeof(value) ~= "table" then
		return nil
	end
	if visited[value] then
		return nil
	end
	visited[value] = true
	if isWeaponClientState(value) then
		return value
	end
	for _, child in pairs(value) do
		if typeof(child) == "table" then
			local found = scanForWeaponState(child, visited, depth + 1)
			if found then
				return found
			end
		elseif typeof(child) == "function" then
			for index = 1, 64 do
				local _, upvalue = readUpvalue(child, index)
				if upvalue == nil then
					break
				end
				if typeof(upvalue) == "table" then
					local found = scanForWeaponState(upvalue, visited, depth + 1)
					if found then
						return found
					end
				end
			end
		end
	end
	return nil
end

local function scanFunctionForWeaponState(fn, visited)
	if typeof(fn) ~= "function" or visited[fn] then
		return nil
	end
	visited[fn] = true
	for index = 1, 128 do
		local _, value = readUpvalue(fn, index)
		if value == nil then
			break
		end
		if isWeaponClientState(value) then
			return value
		end
		if typeof(value) == "table" then
			local found = scanForWeaponState(value, {}, 0)
			if found then
				return found
			end
		elseif typeof(value) == "function" then
			local found = scanFunctionForWeaponState(value, visited)
			if found then
				return found
			end
		end
	end
	return nil
end

local function discoverWeaponState()
	if weaponStateRef and isWeaponClientState(weaponStateRef) then
		return weaponStateRef
	end

	local now = tick()
	if now < nextWeaponDiscoveryAt then
		return nil
	end
	nextWeaponDiscoveryAt = now + 1.5

	local visited = {}
	local roots = { BulletSimulator.Simulate, BulletSimulator.CosmeticSimulate }
	if MagazineController then
		for _, methodName in ipairs({ "Fire", "Reload", "InitTool", "GetState" }) do
			if typeof(MagazineController[methodName]) == "function" then
				table.insert(roots, MagazineController[methodName])
			end
		end
	end

	for _, root in ipairs(roots) do
		if typeof(root) == "function" then
			local found = scanFunctionForWeaponState(root, visited)
			if found then
				weaponStateRef = found
				return found
			end
		end
	end

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if playerScripts then
		for _, descendant in ipairs(playerScripts:GetDescendants()) do
			if descendant:IsA("ModuleScript") and descendant:GetFullName():find("WeaponClient") then
				local ok, moduleTable = pcall(require, descendant)
				if ok and typeof(moduleTable) == "table" then
					local found = scanForWeaponState(moduleTable, {}, 0)
					if found then
						weaponStateRef = found
						return found
					end
				end
			end
		end
	end

	return nil
end

local function clearOverheatState(t2)
	if not t2 or typeof(t2.PerToolState) ~= "table" then
		return
	end
	for _, state in pairs(t2.PerToolState) do
		if typeof(state) == "table" then
			state.Heat = 0
			state.Overheated = false
		end
	end
end

local function clearEquippedJam(tool)
	if not tool then
		return
	end
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == "Jammed" and descendant:IsA("BoolValue") then
			descendant.Value = false
		end
	end
end

local function uninstallJamGuard()
	if jamGuardConn then
		jamGuardConn:Disconnect()
		jamGuardConn = nil
	end
	jamGuardTarget = nil
end

local function installJamGuard(t2)
	if not Config.NoJam or not t2 or not t2.JammedValue then
		uninstallJamGuard()
		return
	end
	if jamGuardTarget == t2.JammedValue then
		return
	end
	uninstallJamGuard()
	jamGuardTarget = t2.JammedValue
	jamGuardConn = t2.JammedValue:GetPropertyChangedSignal("Value"):Connect(function()
		if Config.NoJam and t2.JammedValue and t2.JammedValue.Value then
			t2.JammedValue.Value = false
		end
	end)
end

local function applyNoJam(t2)
	if not Config.NoJam or not t2 then
		uninstallJamGuard()
		return
	end

	installJamGuard(t2)

	if t2.JammedValue and t2.JammedValue.Value then
		t2.JammedValue.Value = false
	end
	if t2.currentTool then
		clearEquippedJam(t2.currentTool)
	end
	if t2.Assets and t2.Assets.SettingsGun then
		pcall(function()
			t2.Assets.SettingsGun.JamChance = 0
		end)
	end
	clearOverheatState(t2)
end

local function getWeaponFireInterval(t2)
	if not t2 then
		return 0.1
	end

	local settings = t2.Assets and t2.Assets.SettingsGun
	if settings and tonumber(settings.FireRate) and settings.FireRate > 0 then
		return 60 / settings.FireRate
	end

	if typeof(t2.FireRate) == "number" and t2.FireRate > 0 then
		return t2.FireRate
	end

	local tool = t2.currentTool
	if tool then
		local rpm = tool:GetAttribute("FireRate") or tool:GetAttribute("RPM")
		if tonumber(rpm) and rpm > 0 then
			return 60 / rpm
		end
	end

	return 0.1
end

local function clearWeaponFireBlockers(t2)
	if not t2 or not Config.RapidFire then
		return
	end

	if typeof(t2.PerToolState) == "table" then
		for _, toolState in pairs(t2.PerToolState) do
			if typeof(toolState) == "table" then
				toolState.Overheated = false
				toolState.Heat = 0
			end
		end
	end

	if t2.ChamberedValue and t2.ChamberedValue.Value == false then
		if t2.AmmoValue and t2.AmmoValue.Value > 0 then
			t2.ChamberedValue.Value = true
			if t2.currentTool then
				t2.currentTool:SetAttribute("ChamberedAttr", true)
			end
		end
	end

	if typeof(t2.Manual) == "table" then
		t2.Manual.NeedCycle = false
	end

	if t2.States then
		t2.States.boltBusy = false
	end
end

local function applyRapidFire(t2)
	if not t2 then
		return
	end

	if not Config.RapidFire then
		if rapidFireBaseInterval and t2.currentTool == rapidFireTool then
			t2.FireRate = rapidFireBaseInterval
		end
		rapidFireTool = nil
		rapidFireBaseInterval = nil
		return
	end

	local tool = t2.currentTool
	if tool ~= rapidFireTool then
		rapidFireTool = tool
		rapidFireBaseInterval = getWeaponFireInterval(t2)
	end

	t2.FireRate = RAPID_FIRE_UNIFIED_INTERVAL
	clearWeaponFireBlockers(t2)
end

local function forceRocketReady(tool)
	if not tool then
		return
	end
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == "RocketInserted" and descendant:IsA("BoolValue") then
			descendant.Value = true
		end
	end
	tool:SetAttribute("RocketInserted", true)
end

local function isGrenadeWeapon(t2)
	return t2
		and t2.Assets
		and t2.Assets.SettingsGun
		and t2.Assets.SettingsGun.Grenade == true
end

local function grenadeThrowAnimPlaying(t2)
	local anims = t2 and t2.AnimationsTable
	if not anims then
		return false
	end
	if anims.NormThrow and anims.NormThrow.IsPlaying then
		return true
	end
	if anims.NormThrowStart and anims.NormThrowStart.IsPlaying then
		return true
	end
	return false
end

local function getGrenadeAmmoCap(t2)
	local settings = t2.Assets.SettingsGun
	return math.max(1, tonumber(settings.Ammo) or tonumber(settings.Mags) or 4)
end

local function findMovementModule()
	if movementModuleRef then
		return movementModuleRef
	end

	local t2 = weaponStateRef or discoverWeaponState()
	if t2 and t2.Modules and typeof(t2.Modules.MovementModule) == "table" then
		movementModuleRef = t2.Modules.MovementModule
		return movementModuleRef
	end

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	for _, descendant in ipairs(playerScripts:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant.Name == "MovementModule" then
			local ok, moduleTable = pcall(require, descendant)
			if ok and typeof(moduleTable) == "table" then
				movementModuleRef = moduleTable
				return movementModuleRef
			end
		end
	end

	return nil
end

local function applyWalkSpeedBoost()
	if not Config.SpeedBoost or Config.Flight then
		return
	end

	local t2 = weaponStateRef
	if t2 and t2.States and (t2.States.BipodRequest or t2.States.Climbing) then
		return
	end

	local humanoid = (t2 and t2.humanoid)
		or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
	if not humanoid then
		return
	end

	local speed = BOOST_WALK_SPEED
	if t2 and t2.States and t2.States.Sprinting and not t2.Aiming then
		speed = BOOST_SPRINT_SPEED
	end
	humanoid.WalkSpeed = speed
end

local function applyGrenadeMods(t2)
	if not Config.GrenadeSpam or not isGrenadeWeapon(t2) then
		return
	end

	local ammoCap = getGrenadeAmmoCap(t2)
	if t2.AmmoValue and t2.AmmoValue.Value < 1 then
		t2.AmmoValue.Value = ammoCap
	end

	if t2.Modules and t2.Modules.MagazineController and t2.currentTool then
		local ok, magState = pcall(t2.Modules.MagazineController.GetState, t2.Modules.MagazineController, t2.currentTool)
		if ok and typeof(magState) == "table" then
			if (magState.currentMag or 0) < 1 then
				magState.currentMag = ammoCap
			end
			if t2.AmmoValue then
				t2.AmmoValue.Value = magState.currentMag
			end
		end
	end

	if typeof(t2._actionCooldowns) == "table" then
		for key in pairs(t2._actionCooldowns) do
			t2._actionCooldowns[key] = 0
		end
	end

	if t2.equipping and not grenadeThrowAnimPlaying(t2) then
		local equipAnim = t2.AnimationsTable and t2.AnimationsTable.Equip
		if not (equipAnim and equipAnim.IsPlaying) then
			t2.equipping = false
		end
	end

	if not grenadeThrowAnimPlaying(t2) then
		t2.States.GrenadeBusy = false
		t2.States.GrenadeReady = true
	end
end

local function installMovementHooks()
	if movementHooksInstalled then
		return
	end

	local movementModule = findMovementModule()
	if not movementModule then
		return
	end

	hookModuleMethod(movementModule, "UpdateSpeed", function(old, self, ...)
		local results = { old(self, ...) }
		applyWalkSpeedBoost()
		return unpack(results)
	end)

	hookModuleMethod(movementModule, "SprintState", function(old, self, ...)
		local results = { old(self, ...) }
		applyWalkSpeedBoost()
		return unpack(results)
	end)

	hookModuleMethod(movementModule, "ChangeMult", function(old, self, mult, ...)
		if Config.SpeedBoost then
			mult = (tonumber(mult) or 1) * (BOOST_WALK_SPEED / 17.9)
		end
		return old(self, mult, ...)
	end)

	movementHooksInstalled = true
end

local function spawnHitMarker(worldPos, isHeadshot, damage)
	local circle = Drawing.new("Circle")
	circle.Filled = false
	circle.Thickness = 2
	circle.NumSides = 24
	circle.Radius = isHeadshot and 14 or 10
	circle.Color = isHeadshot and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 230, 80)
	circle.Visible = true

	local text = Drawing.new("Text")
	text.Size = 14
	text.Outline = true
	text.Center = true
	text.Color = circle.Color
	text.Text = tostring(math.floor(tonumber(damage) or 0))
	text.Visible = true

	table.insert(hitMarkerList, {
		pos = worldPos,
		spawnedAt = tick(),
		headshot = isHeadshot,
		circle = circle,
		text = text,
	})
end

local function setThermalLighting(enabled)
	local fpv = Lighting:FindFirstChild("FPV_Thermal")
	local blur = Lighting:FindFirstChild("BlurEffect")
	if fpv and fpv:IsA("PostEffect") then
		fpv.Enabled = enabled
	end
	if blur and blur:IsA("PostEffect") then
		blur.Enabled = enabled
	end
	if enabled then
		if defaultExposure == nil then
			defaultExposure = Lighting.ExposureCompensation
		end
		Lighting.ExposureCompensation = 5
	else
		if defaultExposure ~= nil then
			Lighting.ExposureCompensation = defaultExposure
			defaultExposure = nil
		else
			Lighting.ExposureCompensation = 0.33
		end
	end
end

updateThermalHighlights = function()
	if not Config.ThermalESP then
		setThermalLighting(false)
		for player, highlight in pairs(thermalHighlights) do
			highlight:Destroy()
			thermalHighlights[player] = nil
		end
		return
	end

	setThermalLighting(true)
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end
		if Config.Teamcheck and isSameTeam(player) then
			continue
		end
		if not isPlayerInCombat(player) then
			continue
		end

		local character = player.Character
		seen[player] = true
		if not thermalHighlights[player] then
			local highlight = Instance.new("Highlight")
			highlight.Name = "WarfareThermal"
			highlight.FillColor = Color3.fromRGB(255, 95, 35)
			highlight.FillTransparency = 0.35
			highlight.OutlineColor = Color3.fromRGB(255, 220, 100)
			highlight.OutlineTransparency = 0.15
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = character
			highlight.Parent = character
			thermalHighlights[player] = highlight
		end
	end

	for player, highlight in pairs(thermalHighlights) do
		if not seen[player] then
			highlight:Destroy()
			thermalHighlights[player] = nil
		end
	end
end

updateHitMarkers = function()
	local now = tick()
	for index = #hitMarkerList, 1, -1 do
		local marker = hitMarkerList[index]
		local age = now - marker.spawnedAt
		if age > 1.5 or not Config.HitMarkers then
			marker.circle:Remove()
			marker.text:Remove()
			table.remove(hitMarkerList, index)
		else
			local screenPos, onScreen = Camera:WorldToViewportPoint(marker.pos)
			local visible = onScreen and screenPos.Z > 0 and Config.HitMarkers
			marker.circle.Visible = visible
			marker.text.Visible = visible
			if visible then
				local alpha = 1 - (age / 1.5)
				marker.circle.Position = Vector2.new(screenPos.X, screenPos.Y)
				marker.circle.Transparency = 1 - alpha
				marker.text.Position = Vector2.new(screenPos.X, screenPos.Y - 18)
				marker.text.Transparency = 1 - alpha
			end
		end
	end
end

applyCombatMods = function()
	local t2 = discoverWeaponState()

	if Config.Flight then
		applyFlightWeaponPatch()
	end

	if Config.SpeedBoost then
		installMovementHooks()
		applyWalkSpeedBoost()
	end

	if Config.InfiniteStamina and t2 and t2.States then
		t2.States.StaminaValue = 500
	end

	if t2 then
		applyGrenadeMods(t2)

		applyRapidFire(t2)
		applyNoJam(t2)

		if Config.NoOverheat then
			clearOverheatState(t2)
		end

		if Config.RocketSpam and t2.currentTool then
			forceRocketReady(t2.currentTool)
		end

		if Config.ZoomBoost then
			local cam = t2.Camera or Camera
			if t2.Aiming then
				if savedAimFov == nil then
					savedAimFov = cam.FieldOfView
				end
				cam.FieldOfView = ZOOM_FOV
			elseif savedAimFov ~= nil then
				cam.FieldOfView = savedAimFov
				savedAimFov = nil
			end
		elseif savedAimFov ~= nil then
			Camera.FieldOfView = savedAimFov
			savedAimFov = nil
		end
	end
end

local function installCombatHooks()
	if combatHooksInstalled then
		return
	end

	if MagazineController then
		hookModuleMethod(MagazineController, "Fire", function(old, tool)
			if Config.InfiniteAmmo then
				return true
			end
			if Config.GrenadeSpam then
				local t2 = weaponStateRef or discoverWeaponState()
				if isGrenadeWeapon(t2) then
					return true
				end
			end
			return old(tool)
		end)
	end

	local ok, bridgeNet = pcall(require, Modules:WaitForChild("BridgeNet2"))
	if ok and bridgeNet and bridgeNet.ReferenceBridge then
		local confirmBridge = bridgeNet.ReferenceBridge("HitConfirm")
		if confirmBridge and confirmBridge.Connect then
			confirmBridge:Connect(function(payload)
				if typeof(payload) ~= "table" or not Config.HitMarkers then
					return
				end
				local hitPosition = payload.hitPosition
				if typeof(hitPosition) ~= "Vector3" then
					return
				end
				spawnHitMarker(hitPosition, payload.isHeadshot == true, payload.damage)
			end)
		end
	end

	combatHooksInstalled = true
end

installCombatHooks()
task.defer(installCombatHooks)
task.defer(installMovementHooks)
task.delay(2, installMovementHooks)

RunService.PreSimulation:Connect(function()
	if Config.BulletTP then
		applyBulletTP()
	end
end)

RunService.Heartbeat:Connect(function()
	if Config.Flight then
		updateFlight()
	end
	if Config.SpeedBoost and not Config.Flight then
		installMovementHooks()
		applyWalkSpeedBoost()
	end
	if Config.InfiniteStamina then
		local t2 = weaponStateRef or discoverWeaponState()
		if t2 and t2.States then
			t2.States.StaminaValue = 500
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local highlight = thermalHighlights[player]
	if highlight then
		highlight:Destroy()
		thermalHighlights[player] = nil
	end
	teamNameCache[player] = nil
end)

local function isBulletState(value)
	return typeof(value) == "table"
		and value.filterList
		and value.rayParams
		and typeof(value.velocity) == "Vector3"
		and typeof(value.position) == "Vector3"
end

local function isBulletRegistryTable(value)
	if typeof(value) ~= "table" then
		return false
	end
	for _, sample in ipairs(value) do
		if isBulletState(sample) then
			return true
		end
	end
	return false
end

local function scanBulletUpvalues(fn, visited, depth)
	if typeof(fn) ~= "function" or visited[fn] or depth > 10 then
		return
	end
	visited[fn] = true
	for index = 1, 128 do
		local _, value = readUpvalue(fn, index)
		if value == nil then
			break
		end
		if isBulletRegistryTable(value) then
			bulletRegistryRef = value
			return
		end
		if typeof(value) == "function" then
			scanBulletUpvalues(value, visited, depth + 1)
			if bulletRegistryRef then
				return
			end
		end
	end
end

local function discoverBulletRegistry()
	local now = tick()
	if bulletRegistryRef and now < nextBulletRegistryScan then
		return bulletRegistryRef
	end
	nextBulletRegistryScan = now + 1

	local visited = {}
	scanBulletUpvalues(BulletSimulator.Simulate, visited, 0)
	if not bulletRegistryRef and typeof(BulletSimulator.CosmeticSimulate) == "function" then
		scanBulletUpvalues(BulletSimulator.CosmeticSimulate, visited, 0)
	end
	return bulletRegistryRef
end

local function findHumanoidFromPart(part)
	local current = part
	for _ = 1, 6 do
		if not current then
			break
		end
		local humanoid = current:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, humanoid.Parent
		end
		current = current.Parent
	end
	return nil, nil
end

local function getBulletRaycastExclude()
	local exclude = {}
	local seen = {}

	local function add(instance)
		if instance and instance.Parent and not seen[instance] then
			seen[instance] = true
			table.insert(exclude, instance)
		end
	end

	add(LocalPlayer.Character)
	add(Camera)

	local t2 = weaponStateRef or discoverWeaponState()
	if t2 then
		add(t2.viewmodel)
		add(t2.Viewmodel)
		if t2.Assets then
			add(t2.Assets.Viewmodel)
			add(t2.Assets.GunModel)
		end
		add(t2.muzzle)
		local pool = t2.BulletPool or t2.bulletPool
		if typeof(pool) == "table" and typeof(pool._container) == "Instance" then
			add(pool._container)
		end
	end

	return exclude
end

local function expandWallPartsForPatch(wallParts)
	local expanded, seen = {}, {}
	for _, part in ipairs(wallParts) do
		if part and part.Parent and part:IsA("BasePart") and not seen[part] then
			seen[part] = true
			table.insert(expanded, part)
			local model = part:FindFirstAncestorOfClass("Model")
			if model and not Players:GetPlayerFromCharacter(model) then
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") and not seen[descendant] then
						seen[descendant] = true
						table.insert(expanded, descendant)
					end
				end
			end
		end
	end
	return expanded
end

local function getWallPartsBetween(origin, targetPos)
	local delta = targetPos - origin
	local distance = delta.Magnitude
	if distance < 0.25 then
		return {}
	end

	local direction = delta.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.CollisionGroup = "Bullet"

	local exclude = getBulletRaycastExclude()
	local walls = {}
	local start = origin
	local remaining = distance

	for _ = 1, 48 do
		if remaining <= 0.05 then
			break
		end
		params.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(start, direction * remaining, params)
		if not result then
			break
		end

		local part = result.Instance
		if not part or not part:IsA("BasePart") then
			break
		end

		local _, character = findHumanoidFromPart(part)
		if character then
			break
		end

		if not walls[part] then
			walls[part] = true
			table.insert(exclude, part)
		end

		local traveled = (result.Position - start).Magnitude
		if traveled <= 0.001 then
			table.insert(exclude, part)
			break
		end

		start = result.Position + direction * 0.05
		remaining = distance - (start - origin).Magnitude
	end

	local wallList = {}
	for part in pairs(walls) do
		table.insert(wallList, part)
	end
	return wallList
end

local function patchBulletFilters(bulletState, wallParts)
	if not bulletState or not bulletState.filterList or not bulletState.rayParams or #wallParts == 0 then
		return 0
	end

	local added = 0
	local seen = {}
	for _, instance in ipairs(bulletState.filterList) do
		seen[instance] = true
	end

	for _, part in ipairs(wallParts) do
		if part and part.Parent and not seen[part] then
			seen[part] = true
			table.insert(bulletState.filterList, part)
			added += 1
		end
	end

	bulletState.rayParams.FilterDescendantsInstances = bulletState.filterList
	return added
end

local function resolveBulletTPTarget(state, fallbackTarget)
	if state._tpTarget then
		local pinned = state._tpTarget
		if pinned.part and pinned.part.Parent then
			pinned.position = pinned.part.Position
			return pinned.part.Position, pinned
		end
		if pinned.position then
			return pinned.position, pinned
		end
		state._tpTarget = nil
	end

	if fallbackTarget then
		if fallbackTarget.part and fallbackTarget.part.Parent then
			return fallbackTarget.part.Position, fallbackTarget
		end
		if fallbackTarget.position then
			return fallbackTarget.position, fallbackTarget
		end
	end

	return nil, nil
end

local function getBulletTPDirection(state, targetPos)
	if typeof(state.velocity) == "Vector3" and state.velocity.Magnitude > 1 then
		return state.velocity.Unit
	end
	if typeof(state.position) == "Vector3" then
		local delta = targetPos - state.position
		if delta.Magnitude > 0.01 then
			return delta.Unit
		end
	end
	return Camera.CFrame.LookVector
end

local function isActiveBulletState(state)
	if not isBulletState(state) then
		return false
	end
	if state.isCosmetic then
		return false
	end
	if state.alive == false or state.done == true or state.dead == true then
		state._tpTarget = nil
		return false
	end
	return state.velocity.Magnitude > 1 or state.fireTime ~= nil
end

local function ensureBulletWallPatch(state, muzzlePos, targetPos)
	if state._tpWallsPatched or typeof(muzzlePos) ~= "Vector3" then
		return
	end

	local walls = getWallPartsBetween(muzzlePos, targetPos)
	if #walls > 0 then
		patchBulletFilters(state, expandWallPartsForPatch(walls))
	end
	state._tpWallsPatched = true
end

local function getBulletTPProfile(state)
	if state and state.rocket then
		return BULLET_TP_ROCKET_SNAP_DIST, BULLET_TP_ROCKET_MIN_SPEED
	end
	return BULLET_TP_SNAP_DIST, BULLET_TP_MIN_SPEED
end

local function applyBulletTPToState(state, targetPos, targetRef, muzzlePos)
	if state.isCosmetic then
		return
	end
	if typeof(state.position) ~= "Vector3" or typeof(state.velocity) ~= "Vector3" then
		return
	end

	if targetRef then
		state._tpTarget = targetRef
	end
	if typeof(muzzlePos) == "Vector3" then
		state._tpMuzzle = muzzlePos
	end

	ensureBulletWallPatch(state, state._tpMuzzle, targetPos)

	local snapDist, minSpeed = getBulletTPProfile(state)
	local direction = getBulletTPDirection(state, targetPos)
	local teleportPos = targetPos - direction * snapDist
	state.position = teleportPos
	state.velocity = direction * math.max(state.velocity.Magnitude, minSpeed)
end

local function pinBulletByRef(bulletPart, target, muzzleCF)
	if not bulletPart or not target or not bulletRegistryRef then
		return false
	end

	local targetPos = target.part and target.part.Position or target.position
	local muzzlePos = muzzleCF.Position
	for _, state in ipairs(bulletRegistryRef) do
		if state.bullet == bulletPart and isBulletState(state) and not state.isCosmetic then
			applyBulletTPToState(state, targetPos, target, muzzlePos)
			return true
		end
	end
	return false
end

local function pinBulletsAfterShot(bulletsBefore, target, muzzleCF, bulletPart)
	if not target or not bulletRegistryRef then
		return
	end

	if bulletPart and pinBulletByRef(bulletPart, target, muzzleCF) then
		return
	end

	local muzzlePos = muzzleCF.Position
	local targetPos = target.part and target.part.Position or target.position
	for index = math.max(1, bulletsBefore + 1), #bulletRegistryRef do
		local state = bulletRegistryRef[index]
		if isBulletState(state) and not state.isCosmetic then
			applyBulletTPToState(state, targetPos, target, muzzlePos)
		end
	end
end

applyBulletTP = function()
	if not Config.BulletTP then
		return
	end

	local fallbackTarget = getActiveAimTarget()
	local registry = discoverBulletRegistry()
	if not registry then
		return
	end

	for _, state in ipairs(registry) do
		if not isActiveBulletState(state) then
			continue
		end

		local targetPos, targetRef = resolveBulletTPTarget(state, fallbackTarget)
		if not targetPos then
			continue
		end

		applyBulletTPToState(state, targetPos, targetRef, nil)
	end
end

local function applySilentAim(muzzleCF, initialSpeed)
	local target = getActiveAimTarget()
	if not target or (not Config.SilentAim and not Config.BulletTP and not killAllForcedTarget) then
		return muzzleCF, initialSpeed
	end

	local targetPos = target.position
	if target.part then
		targetPos = target.part.Position
	end

	local direction = (targetPos - muzzleCF.Position).Unit
	if direction.Magnitude < 0.01 then
		direction = Camera.CFrame.LookVector
	end

	if Config.BulletTP then
		local t2 = weaponStateRef or discoverWeaponState()
		local settings = t2 and t2.Assets and t2.Assets.SettingsGun
		local isRocket = settings and settings.Rocket and settings.BulletType == settings.Rocket
		local snapDist = isRocket and BULLET_TP_ROCKET_SNAP_DIST or BULLET_TP_SNAP_DIST
		local minSpeed = isRocket and BULLET_TP_ROCKET_MIN_SPEED or BULLET_TP_MIN_SPEED
		initialSpeed = math.max(initialSpeed, minSpeed)
		local tpOrigin = targetPos - direction * snapDist
		muzzleCF = CFrame.lookAt(tpOrigin, targetPos)
	else
		muzzleCF = CFrame.lookAt(muzzleCF.Position, muzzleCF.Position + direction)
	end

	return muzzleCF, initialSpeed
end

local function installSimulateHook(simulateMethod, label, applyAim)
	if typeof(simulateMethod) ~= "function" or not hookfunction or not newcclosure then
		return
	end

	local chainedSimulate = simulateMethod
	local previousSimulate
	previousSimulate = hookfunction(
		chainedSimulate,
		newcclosure(function(self, muzzleCF, bullet, bulletPool, initialSpeed, bulletType, ...)
			local shotTarget = nil
			local bulletsBefore = 0

			if applyAim and not checkcaller() then
				if Config.BulletTP or Config.SilentAim or killAllForcedTarget then
					shotTarget = getActiveAimTarget()
				end
				muzzleCF, initialSpeed = applySilentAim(muzzleCF, initialSpeed)
				if Config.BulletTP then
					discoverBulletRegistry()
					bulletsBefore = bulletRegistryRef and #bulletRegistryRef or 0
				end
			end

			local results = { previousSimulate(self, muzzleCF, bullet, bulletPool, initialSpeed, bulletType, ...) }

			if applyAim and Config.BulletTP and not checkcaller() and shotTarget then
				discoverBulletRegistry()
				pinBulletsAfterShot(bulletsBefore, shotTarget, muzzleCF, bullet)
				applyBulletTP()
			end

			return unpack(results)
		end, label)
	)
end

installSimulateHook(BulletSimulator.Simulate, "BulletSimulator.Simulate", true)
installSimulateHook(BulletSimulator.CosmeticSimulate, "BulletSimulator.CosmeticSimulate", false)
