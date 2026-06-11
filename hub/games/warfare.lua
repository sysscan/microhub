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
	ESPSnaplines = false,
	ESPStatusTags = true,
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
	AimPart = "Head",
	ESPEnemyColor = Color3.fromRGB(255, 75, 75),
	ESPAllyColor = Color3.fromRGB(75, 220, 120),
	ESPNeutralColor = Color3.fromRGB(255, 220, 80),
}

local BOOST_WALK_SPEED = 28
local BOOST_SPRINT_SPEED = 36
local FLIGHT_SPEED = 90
local FLIGHT_BOOST_SPEED = 140
local ZOOM_FOV = 12
-- One client interval for every gun; TryFireOnce enforces this via nextShotTime.
local RAPID_FIRE_UNIFIED_INTERVAL = 0.09

local FOVSquared = Config.FOV * Config.FOV

local function getTeamColor(relation)
	if relation == "Enemy" then
		return Config.ESPEnemyColor
	elseif relation == "Ally" then
		return Config.ESPAllyColor
	end
	return Config.ESPNeutralColor
end

local function getAimPartName()
	return Config.AimPart or "Head"
end

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
		return getTeamColor(getTeamRelation(target.player))
	end
	if target.drone then
		local teamName = target.drone:GetAttribute("Team")
		return getTeamColor(getInstanceTeamRelation(target.drone, teamName and tostring(teamName) or nil))
	end
	return Config.ESPEnemyColor
end

local function setFOV(value)
	Config.FOV = math.clamp(math.floor(value), 50, 600)
	FOVSquared = Config.FOV * Config.FOV
end

local function hasDrawing()
	return typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
end

local function createDrawing(kind)
	if not hasDrawing() then
		return nil
	end
	return Drawing.new(kind)
end

-- Drawing-backed visuals are optional because not every sUNC target exposes Drawing.
local Tracer = createDrawing("Line")
if Tracer then
	Tracer.Visible = false
	Tracer.Color = Color3.fromRGB(255, 255, 255)
	Tracer.Thickness = 1.5
	Tracer.Transparency = 0
end

local FOVCircle = createDrawing("Circle")
if FOVCircle then
	FOVCircle.Visible = false
	FOVCircle.Thickness = 1
	FOVCircle.NumSides = 48
	FOVCircle.Filled = false
	FOVCircle.Transparency = 0.5
	FOVCircle.Color = Color3.fromRGB(255, 255, 255)
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

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local HubUI = UILib.create({
	title = "WARFARE",
	config = Config,
	pages = {
		{
			label = "Combat",
			sections = {
				{
					title = "AIM",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "toggle", key = "Teamcheck", label = "Team Check", hud = "Team Check" },
						{ type = "toggle", key = "NoRecoil", label = "No Recoil", hud = "No Recoil" },
						{ type = "toggle", key = "StableAim", label = "Stable Aim", hud = "Stable Aim" },
						{ type = "toggle", key = "BulletTP", label = "Bullet TP", hud = "Bullet TP" },
						{
							type = "select",
							key = "AimPart",
							label = "Aim Bone",
							options = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
						},
						{ type = "slider", key = "FOV", label = "Silent FOV", min = 50, max = 600, step = 25, onChange = setFOV },
					},
				},
				{
					title = "WEAPON",
					items = {
						{ type = "toggle", key = "RapidFire", label = "Rapid Fire", hud = "Rapid Fire" },
						{ type = "toggle", key = "InfiniteAmmo", label = "Inf Ammo", hud = "Inf Ammo" },
						{ type = "toggle", key = "NoJam", label = "No Jam", hud = "No Jam" },
						{ type = "toggle", key = "NoOverheat", label = "No Heat", hud = "No Heat" },
						{ type = "toggle", key = "GrenadeSpam", label = "Grenade", hud = "Grenade" },
						{ type = "toggle", key = "RocketSpam", label = "Rocket", hud = "Rocket" },
					},
				},
			},
		},
		{
			label = "Move",
			sections = {
				{
					title = "MOVEMENT",
					items = {
						{ type = "toggle", key = "Flight", label = "Flight", hud = "Flight" },
						{ type = "toggle", key = "SpeedBoost", label = "Speed", hud = "Speed" },
						{ type = "toggle", key = "InfiniteStamina", label = "Stamina", hud = "Stamina" },
						{ type = "hint", text = "Flight: WASD / Space / Ctrl / Shift" },
					},
				},
			},
		},
		{
			label = "Visual",
			sections = {
				{
					title = "ESP",
					items = {
						{ type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
						{ type = "toggle", key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
						{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
						{ type = "toggle", key = "ESPStatusTags", label = "Status Tags", hud = "Status Tags" },
						{ type = "toggle", key = "Tracer", label = "Tracer", hud = "Tracer" },
						{ type = "toggle", key = "FOVCircle", label = "FOV Circle", hud = "FOV Circle" },
						{ type = "toggle", key = "ThermalESP", label = "Thermal", hud = "Thermal" },
						{ type = "toggle", key = "HitMarkers", label = "Hit Markers", hud = "Hit Markers" },
						{ type = "toggle", key = "ZoomBoost", label = "Zoom", hud = "Zoom" },
						{ type = "label", text = "ESP colors — tap swatch" },
						{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
						{ type = "color", key = "ESPAllyColor", label = "Ally" },
						{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
					},
				},
			},
		},
		{
			label = "Client",
			sections = {
				{
					title = "MISC",
					items = {
						{ type = "toggle", key = "NVG", label = "NVG", hud = "NVG" },
						{ type = "toggle", key = "FishEye", label = "FishEye", hud = "FishEye" },
						{ type = "toggle", key = "Comtacs", label = "Comtacs", hud = "Comtacs" },
						{ type = "toggle", key = "NoSuppression", label = "No Suppress", hud = "No Suppress" },
						{ type = "toggle", key = "StripShield", label = "Strip Shield", hud = "Strip Shield" },
						{ type = "toggle", key = "FullBright", label = "Full Bright", hud = "Full Bright" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
				{
					title = "ACTIONS",
					items = {
						{
							type = "button",
							id = "killAll",
							label = "Kill All",
							getLabel = function()
								return killAllRunning and "Kill All (running...)" or "Kill All"
							end,
							canClick = function()
								return not killAllRunning
							end,
							onClick = function()
								if runKillAll then
									task.spawn(runKillAll)
								end
							end,
						},
					},
				},
			},
		},
	},
	onMenuVisible = function(visible)
		if visible and Config.Flight then
			clearFlightKeys()
		end
	end,
	hud = { showKey = "ShowHUD" },
})

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
	if not Config.Flight or HubUI:isMenuVisible() then
		if HubUI:isMenuVisible() and Config.Flight then
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
	if HubUI:isMenuVisible() then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		setFlightKey(input.KeyCode, true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if HubUI:isMenuVisible() then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		setFlightKey(input.KeyCode, false)
	end
end)

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

-- ESP (Prison Life v2)
local espCache = {}
local droneEspCache = {}
local teamNameCache = {}
local espWasEnabled = false
local espNeedsHide = false
local ESP_MAX_DIST = 2000
local cameraPosCache = Vector3.zero
local jamGuardConn = nil
local jamGuardTarget = nil
local rapidFireTool = nil
local rapidFireBaseInterval = nil

local ESP_DIM = Color3.fromRGB(148, 156, 168)

local function mkEspDraw(kind, props)
	local draw = createDrawing(kind)
	if not draw then
		return nil
	end
	for key, value in props do
		draw[key] = value
	end
	draw.Visible = false
	return draw
end

local function lerpEspColor(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function espHpColor(ratio)
	if ratio > 0.5 then
		return lerpEspColor(Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 230, 120), (ratio - 0.5) * 2)
	end
	return lerpEspColor(Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 220, 60), ratio * 2)
end

local function formatEspDistance(studs)
	if studs >= 1000 then
		return string.format("%.1fk", studs / 1000)
	end
	return string.format("%d", math.floor(studs))
end

local function getWeaponName(character)
	local tool = character:FindFirstChildWhichIsA("Tool")
	return tool and tool.Name or nil
end

local function espBox2d(character, root)
	if not character.Parent or not root.Parent then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.4, 0)
		local botPos = root.Position - Vector3.new(0, 2.8, 0)
		local top, topOn = Camera:WorldToViewportPoint(topPos)
		local bot, botOn = Camera:WorldToViewportPoint(botPos)
		if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
			local h = math.max(14, bot.Y - top.Y)
			local w = h * 0.55
			return top.X - w * 0.5, top.Y, w, h
		end
	end
	local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
	if onScreen and pos.Z > 0 then
		return pos.X - 16, pos.Y - 30, 32, 60
	end
	return nil
end

local function hideEspEntry(entry)
	for _, obj in entry do
		pcall(function()
			obj.Visible = false
		end)
	end
end

local function destroyEspEntry(entry)
	for _, obj in entry do
		pcall(function()
			obj:Remove()
		end)
	end
end

local function removeEsp(player)
	local entry = espCache[player]
	if not entry then
		return
	end
	destroyEspEntry(entry)
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
	if not hasDrawing() then
		return nil
	end
	if espCache[player] then
		return espCache[player]
	end

	local entry = {
		boxOutline = mkEspDraw("Square", { Filled = false, Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0.6 }),
		box = mkEspDraw("Square", { Filled = false, Thickness = 1.4 }),
		hpBarBg = mkEspDraw("Square", { Filled = true, Thickness = 0, Color = Color3.fromRGB(20, 20, 20), Transparency = 0.3 }),
		hpBar = mkEspDraw("Square", { Filled = true, Thickness = 0 }),
		name = mkEspDraw("Text", { Size = 14, Center = true, Outline = true, Font = 2 }),
		weapon = mkEspDraw("Text", { Size = 11, Center = true, Outline = true, Font = 2, Color = Color3.fromRGB(200, 200, 200) }),
		dist = mkEspDraw("Text", { Size = 11, Center = true, Outline = true, Font = 2 }),
		snapline = mkEspDraw("Line", { Thickness = 1, Transparency = 0.4 }),
	}
	if not entry.box or not entry.name then
		destroyEspEntry(entry)
		return nil
	end

	espCache[player] = entry
	return entry
end

local function ensureDroneEsp(model)
	if not hasDrawing() then
		return nil
	end
	if droneEspCache[model] then
		return droneEspCache[model]
	end

	local box = createDrawing("Square")
	box.Filled = false
	box.Thickness = 1.5
	box.Visible = false

	local label = createDrawing("Text")
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

local function espStatusSuffix(player, character)
	if not Config.ESPStatusTags then
		return ""
	end
	local teamName = getCachedTeamName(player)
	if teamName then
		return "[" .. teamName .. "]"
	end
	if character:GetAttribute("Downed") then
		return "[Downed]"
	end
	return ""
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

local function drawPlayerEsp(player, character, humanoid, root, camPos, snapFrom)
	local relation = getTeamRelation(player)
	if relation == "Ally" and not Config.ESPAllies then
		local entry = espCache[player]
		if entry then
			hideEspEntry(entry)
		end
		return
	end

	local dist = (root.Position - camPos).Magnitude
	if dist > ESP_MAX_DIST then
		local entry = espCache[player]
		if entry then
			hideEspEntry(entry)
		end
		return
	end

	local x, y, w, h = espBox2d(character, root)
	if not x then
		local entry = espCache[player]
		if entry then
			hideEspEntry(entry)
		end
		return
	end

	local entry = ensureEsp(player)
	if not entry then
		return
	end

	local accent = getTeamColor(relation)
	local cx = x + w * 0.5
	local bottom = y + h
	local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	local fadeAlpha = 1 - math.clamp((dist - 800) / 1200, 0, 0.6)

	entry.boxOutline.Position = Vector2.new(x - 1, y - 1)
	entry.boxOutline.Size = Vector2.new(w + 2, h + 2)
	entry.boxOutline.Transparency = 0.55 * fadeAlpha
	entry.boxOutline.Visible = true

	entry.box.Position = Vector2.new(x, y)
	entry.box.Size = Vector2.new(w, h)
	entry.box.Color = accent
	entry.box.Transparency = (1 - fadeAlpha) * 0.3
	entry.box.Visible = true

	local barH = math.clamp(h, 8, 200)
	local barW = 3
	local barX = x - 6
	local barY = y

	entry.hpBarBg.Position = Vector2.new(barX - 1, barY - 1)
	entry.hpBarBg.Size = Vector2.new(barW + 2, barH + 2)
	entry.hpBarBg.Visible = true

	local fillH = math.max(1, barH * ratio)
	entry.hpBar.Position = Vector2.new(barX, barY + (barH - fillH))
	entry.hpBar.Size = Vector2.new(barW, fillH)
	entry.hpBar.Color = espHpColor(ratio)
	entry.hpBar.Visible = true

	local suffix = espStatusSuffix(player, character)
	local nameStr = player.DisplayName
	if suffix ~= "" then
		nameStr = nameStr .. " " .. suffix
	end
	entry.name.Position = Vector2.new(cx, y - 16)
	entry.name.Text = nameStr
	entry.name.Color = accent
	entry.name.Visible = true

	local wepName = getWeaponName(character)
	entry.weapon.Position = Vector2.new(cx, bottom + 2)
	entry.weapon.Text = wepName or ""
	entry.weapon.Visible = wepName ~= nil

	local distStr = formatEspDistance(dist) .. "m"
	if ratio < 1 then
		distStr = distStr .. " | " .. math.floor(humanoid.Health) .. "hp"
	end
	entry.dist.Position = Vector2.new(cx, bottom + (if wepName then 14 else 2))
	entry.dist.Text = distStr
	entry.dist.Color = ESP_DIM
	entry.dist.Visible = true

	if snapFrom then
		entry.snapline.From = snapFrom
		entry.snapline.To = Vector2.new(cx, bottom + 1)
		entry.snapline.Color = accent
		entry.snapline.Transparency = 0.5 * fadeAlpha
	end
	entry.snapline.Visible = Config.ESPSnaplines and snapFrom ~= nil
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

		local color = getTeamColor(relation)
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
		if not entry then
			continue
		end
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
	if not hasDrawing() then
		return
	end
	if not Config.ESP then
		if espNeedsHide then
			for player, entry in pairs(espCache) do
				destroyEspEntry(entry)
				espCache[player] = nil
			end
			espNeedsHide = false
		end
		updateDroneESP()
		return
	end
	espNeedsHide = true

	cameraPosCache = Camera.CFrame.Position
	local vpSize = Camera.ViewportSize
	local snapFrom = if Config.ESPSnaplines
		then Vector2.new(vpSize.X * 0.5, vpSize.Y)
		else nil
	local activePlayers = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not isPlayerInCombat(player) or not humanoid or not root then
			local entry = espCache[player]
			if entry then
				hideEspEntry(entry)
			end
			continue
		end

		activePlayers[player] = true
		drawPlayerEsp(player, character, humanoid, root, cameraPosCache, snapFrom)
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

	local part = character:FindFirstChild(getAimPartName()) or character:FindFirstChild("HumanoidRootPart")
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
	HubUI:setMenuVisible(false)
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
		local part = character:FindFirstChild(getAimPartName()) or character:FindFirstChild("HumanoidRootPart")
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

	if FOVCircle then
		FOVCircle.Position = center
		FOVCircle.Radius = Config.FOV
		FOVCircle.Visible = Config.FOVCircle and Config.SilentAim
	end

	if Tracer and Config.Tracer and currentTarget then
		Tracer.From = Vector2.new(center.X, viewport.Y)
		Tracer.To = currentTarget.screenPos
		Tracer.Color = getTargetColor(currentTarget)
		Tracer.Visible = true
	elseif Tracer then
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

local function hasFunctionHooks()
	return typeof(hookfunction) == "function" and typeof(newcclosure) == "function"
end

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
	if typeof(target) ~= "function" or hookedRecoilFunctions[target] or not hasFunctionHooks() then
		return
	end
	local old
	local ok, err = pcall(function()
		old = hookfunction(
			target,
			newcclosure(function(...)
				return handler(old, ...)
			end, methodName)
		)
	end)
	if ok then
		hookedRecoilFunctions[target] = true
	else
		warn("[MicroHub][Warfare] hook failed:", methodName, err)
	end
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
	if not hasDrawing() then
		return
	end
	local circle = createDrawing("Circle")
	circle.Filled = false
	circle.Thickness = 2
	circle.NumSides = 24
	circle.Radius = isHeadshot and 14 or 10
	circle.Color = isHeadshot and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 230, 80)
	circle.Visible = true

	local text = createDrawing("Text")
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
	if typeof(simulateMethod) ~= "function" or not hasFunctionHooks() or typeof(checkcaller) ~= "function" then
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
