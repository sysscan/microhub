--[[
	Prison Life — placeIds 155615604, 4669040
	https://www.roblox.com/games/155615604/Prison-Life
	Reference: VapeV4 games/155615604.lua + Decompiled/Prison Life
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "7-vape-port-fix3"
warn("[PrisonLife] build", GAME_BUILD)

local MAX_SAFE_WALKSPEED = 24
local MAX_SAFE_JUMP = 55

local TeamGuards = Teams:FindFirstChild("Guards")
local TeamInmates = Teams:FindFirstChild("Inmates")
local TeamCriminals = Teams:FindFirstChild("Criminals")
local TeamNeutral = Teams:FindFirstChild("Neutral")

local HEAL_ITEMS = { Breakfast = true, Lunch = true, Dinner = true }
local GUN_PRIORITY = { M4A1 = 1, ["AK-47"] = 1, MP5 = 1, FAL = 1, ["Remington 870"] = 2, M9 = 3, Revolver = 4 }

local TEAM_COLOR = {
	Inmate = "Bright orange",
	Guard = "Bright blue",
	Neutral = "Medium stone grey",
}

local Config = {
	WalkSpeed = 24,
	JumpPower = 55,
	SpeedBoost = false,
	NoJumpCooldown = false,
	AutoReset = false,
	Killaura = false,
	KillauraRange = 12,
	AutoArrest = false,
	AutoArrestRange = 8,
	ArrestHandCheck = true,
	ArrestInmates = true,
	ArrestCriminals = true,
	GunMods = false,
	GunNoSpread = true,
	GunFireRate = 100,
	GunAutomatic = false,
	SilentAim = false,
	SilentAimFOV = 150,
	SilentAimHead = true,
	SilentAimTeamCheck = true,
	SilentAimWallCheck = true,
	SilentAimMode = "Mouse",
	SilentAimRange = 150,
	SilentAimHitChance = 85,
	SilentAimHeadshotChance = 65,
	SilentAimWallbang = false,
	SilentAimRangeCircle = false,
	AutoReload = false,
	AutoReloadSwap = false,
	AutoFire = false,
	AutoFireRate = 60,
	InfiniteAmmo = false,
	AntiTaze = false,
	AutoDetonate = false,
	AutoDetonateSafe = true,
	AutoArmor = false,
	AutoHeal = false,
	AutoPickup = false,
	AntiRiotShield = false,
	AntiKillPlane = false,
	VehicleSpeed = false,
	VehicleSpeedValue = 140,
	VehicleWallbang = false,
	AlwaysSprint = false,
	SprintSpeed = 24,
	Disabler = false,
	Noclip = false,
	FullBright = false,
	KillNotify = false,
	C4ESP = true,
	ESP = true,
	ESPAllies = true,
	ESPSnaplines = false,
	ESPStatusTags = true,
	ShowHUD = true,
	ESPEnemyColor = Color3.fromRGB(255, 96, 72),
	ESPAllyColor = Color3.fromRGB(72, 168, 255),
	ESPNeutralColor = Color3.fromRGB(180, 180, 180),
	ESPHostileColor = Color3.fromRGB(255, 56, 56),
	AntiInvisible = false,
	VehicleFly = false,
	VehicleFlyMode = "CFrame",
	VehicleFlySpeed = 60,
	CheatDetector = false,
	CameraPhase = false,
	BulletTracers = false,
	BulletTracerDrawing = false,
	BulletTracerLifetime = 0.2,
	BulletTracerFade = true,
	BulletTracerColor = Color3.fromRGB(255, 200, 80),
	DamageIndicator = false,
	HitSound = false,
	KillSound = false,
	Viewmodel = false,
	ViewmodelDepth = 3,
	ViewmodelHorizontal = 2,
	ViewmodelVertical = -1.5,
	ViewmodelSway = true,
	Crosshair = false,
}

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local canHook = typeof(hookfunction) == "function"
	and typeof(getconnections) == "function"
	and typeof(debug) == "table"
	and typeof(debug.getupvalue) == "function"
local canDebug = canHook and typeof(debug.setstack) == "function" and typeof(debug.setconstant) == "function"

local WHITE = Color3.fromRGB(248, 250, 252)
local DIM = Color3.fromRGB(148, 156, 168)
local BAR_BG = Color3.fromRGB(10, 12, 16)
local BACKDROP = Color3.fromRGB(8, 10, 14)

local esp: { [Model]: any } = {}
local c4Highlights: { [Instance]: Highlight } = {}
local c4Folder = Instance.new("Folder")
c4Folder.Name = "MicroHubPL_C4"
c4Folder.Parent = workspace

local connections: { RBXScriptConnection } = {}
local loops: { thread } = {}
local arrestCooldown = 0
local jumpConn: RBXScriptConnection? = nil
local localC4: Instance? = nil
local armorPickups: { Instance } = {}
local vehicleQueryBackup: { [BasePart]: boolean } = {}
local killPlaneParts: { BasePart } = {}
local killPlaneFolder: Folder? = nil
local headCollideConn: RBXScriptConnection? = nil
local oldTazeFn: any = nil
local tazeRemoteConn: any = nil
local lightingBackup: { [string]: any }? = nil

local gun = {
	Shoot = nil,
	Reload = nil,
	Bullet = nil,
	Equip = nil,
}
local gunDataBackup: { [string]: any }? = nil
local gunDataRef: any = nil
local hookedShoot: any = nil
local hookedBullet: any = nil
local hookedEquip: any = nil
local oldShootFn: any = nil
local oldBulletFn: any = nil
local oldEquipFn: any = nil
local toolAttrBackup: { [Instance]: { [string]: any } } = {}
local pickupSeen: { [Instance]: boolean } = {}
local spawnTimes: { [Model]: number } = {}

local bulletRayParams = RaycastParams.new()
bulletRayParams.CollisionGroup = "ClientBullet"
bulletRayParams.FilterType = Enum.RaycastFilterType.Exclude

local aimRand = Random.new()
local aimTimer, shootTimer, aimVec = os.clock(), os.clock(), Vector3.zero
local detonateTicks = 0
local gamepasses: { [string]: boolean } = {}
local sortedPickups = {
	Guard = { [1] = "MP5", [2] = "Remington 870" },
	Prisoner = { [1] = "MP5", [2] = "Remington 870" },
	Criminal = { [1] = "AK-47", [2] = "Remington 870" },
}
local GunTracers: any = nil
pcall(function()
	GunTracers = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GunTracers"))
end)

local TracerHook = { Hooks = {} }
local oldTracerBullet: any = nil
local oldTracerSniper: any = nil
local tracerDrawingObjs = {}
local antiInvisibleThreads: { [any]: thread } = {}
local animWhitelist: { [string]: boolean } = {}
local cheatFlags: { [number]: { [string]: number } } = {}
local cheatFlagged: { [number]: boolean } = {}
local vehicleFlyWelds: { Instance } = {}
local vehicleFlyUp, vehicleFlyDown = 0, 0
local vehicleFlyPart: BasePart? = nil
local cameraPhaseFn: any = nil
local viewmodelTool: Tool? = nil
local viewmodelClone: Tool? = nil
local viewmodelHandle: BasePart? = nil
local viewmodelRealTool: Tool? = nil
local damageTargetChar: Model? = nil
local damageTargetHealth = 0
local damageTargetTimer = 0
local damageIndicatorPart: BasePart? = nil
local damageIndicatorThread: thread? = nil
local silentAimCircle: any = nil
local overlapBulletParams = OverlapParams.new()
overlapBulletParams.CollisionGroup = "ClientBullet"
overlapBulletParams.FilterType = Enum.RaycastFilterType.Exclude

local OriginScanner = { Cache = {} }
local originRayParams = RaycastParams.new()
originRayParams.CollisionGroup = "ClientBullet"
originRayParams.FilterType = Enum.RaycastFilterType.Exclude
OriginScanner.Ray = originRayParams

do
local function stopLoop(threadRef: thread?)
	if threadRef then
		pcall(task.cancel, threadRef)
	end
end

local function startLoop(fn: () -> ())
	local threadRef = task.spawn(function()
		while true do
			fn()
			task.wait(0.05)
		end
	end)
	table.insert(loops, threadRef)
	return threadRef
end

local function getRemotes()
	return ReplicatedStorage:FindFirstChild("Remotes")
end

local function getMeleeRemote()
	return ReplicatedStorage:FindFirstChild("meleeEvent")
end

local function switchTeamLegacy(colorName: string)
	local remote = workspace:FindFirstChild("Remote")
	if not remote then
		return
	end
	local teamEvent = remote:FindFirstChild("TeamEvent")
	if teamEvent then
		pcall(function()
			teamEvent:FireServer(colorName)
		end)
	end
	task.wait(0.2)
	local loadchar = remote:FindFirstChild("loadchar")
	if loadchar then
		pcall(function()
			loadchar:InvokeServer(LocalPlayer.Name)
		end)
	end
end

local function requestTeamChange(teamName: string)
	local team = Teams:FindFirstChild(teamName)
	if not team then
		return
	end

	local remotes = getRemotes()
	if remotes then
		local req = remotes:FindFirstChild("RequestTeamChange")
		if req then
			pcall(function()
				if req:IsA("RemoteFunction") then
					req:InvokeServer(team)
				else
					req:FireServer(team)
				end
			end)
			task.wait(0.3)
			if LocalPlayer.Team == team then
				return
			end
		end

		local teamSelect = remotes:FindFirstChild("TeamSelect")
		if teamSelect then
			pcall(function()
				if teamSelect:IsA("RemoteFunction") then
					teamSelect:InvokeServer(teamName)
				else
					teamSelect:FireServer(teamName)
				end
			end)
			task.wait(0.3)
			if LocalPlayer.Team == team then
				return
			end
		end
	end

	local colorName = if teamName == "Guards" then TEAM_COLOR.Guard
		elseif teamName == "Inmates" then TEAM_COLOR.Inmate
		else TEAM_COLOR.Neutral
	switchTeamLegacy(colorName)
end

local function getCharacter(player: Player?): Model?
	return player and player.Character
end

local function isAlive(char: Model?): (boolean, Humanoid?, BasePart?)
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if hum and root and hum.Health > 0 then
		return true, hum, root
	end
	return false, hum, root
end

local function isVulnerable(player: Player, char: Model, attackCheck: boolean): boolean
	local alive = isAlive(char)
	if not alive then
		return false
	end
	local spawnedAt = spawnTimes[char]
	if spawnedAt and spawnedAt > os.clock() then
		return false
	end
	if char:FindFirstChildWhichIsA("ForceField") then
		return false
	end
	if char:GetAttribute("Arrested") then
		return false
	end

	if attackCheck and LocalPlayer.Team == TeamGuards and player.Team == TeamInmates then
		if not char:GetAttribute("Hostile") then
			return false
		end
	end

	if player.Team == TeamInmates then
		return char:GetAttribute("Trespassing") == true or char:GetAttribute("Hostile") == true
	end
	return true
end

local function sameTeam(a: Player, b: Player): boolean
	return a.Team ~= nil and b.Team ~= nil and a.Team == b.Team
end

local function getMousePosition(): Vector2
	if UserInputService.TouchEnabled then
		return Camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

local function checkPoint(pos: Vector3, params: OverlapParams): boolean
	for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
		if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0 then
			return false
		end
	end
	return true
end

local function updateOriginIgnore()
	local ignore = { LocalPlayer.Character }
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Character then
			table.insert(ignore, player.Character)
		end
	end
	originRayParams.FilterDescendantsInstances = ignore
	overlapBulletParams.FilterDescendantsInstances = ignore
end

local ORIGIN_POSITIONS = {
	Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(0.7, -0.5, -0.5),
	Vector3.new(-0.1, -0.8, -0.8), Vector3.new(-0.8, -0.5, -0.5), Vector3.new(-1, 0, 0),
	Vector3.new(-0.8, 0.4, 0.4), Vector3.new(0, 0.7, 0.7), Vector3.new(0.7, 0.5, 0.5),
	Vector3.new(0.7, 0, -0.8), Vector3.new(-0.1, 0, -1), Vector3.new(0, 0, 1),
	Vector3.new(0, -1, 0),
}

function OriginScanner:Scan(origin: Vector3, target: Vector3, extra: Vector3?, part: Instance)
	if self.Cache[part] then
		return table.unpack(self.Cache[part])
	end
	local scanPositions = {}
	local hitboxPositions = {}
	local diff = CFrame.lookAt(origin * Vector3.new(1, 0, 1), target * Vector3.new(1, 0, 1)).LookVector
	if extra then
		if (origin - extra).Magnitude < 7.5 then
			table.insert(scanPositions, extra)
		else
			table.insert(hitboxPositions, target)
			for _, normal in Enum.NormalId:GetEnumItems() do
				local vec = Vector3.fromNormalId(normal)
				if (vec * Vector3.new(1, 0, 1)):Dot(-diff) > -0.5 then
					local pos = target + vec * 6
					if checkPoint(pos, overlapBulletParams) then
						table.insert(hitboxPositions, pos)
					end
				end
			end
		end
	end
	if #scanPositions <= 0 then
		for _, offset in ORIGIN_POSITIONS do
			if (offset * Vector3.new(1, 0, 1)):Dot(diff) > -0.5 then
				table.insert(scanPositions, origin + offset * 6)
			end
		end
	end
	if #hitboxPositions > 0 then
		for _, hitbox in hitboxPositions do
			for _, pos in scanPositions do
				if workspace:Raycast(hitbox, pos - hitbox, originRayParams) == nil and checkPoint(pos, overlapBulletParams) then
					self.Cache[part] = { pos, hitbox }
					return pos, hitbox
				end
			end
		end
	else
		for _, pos in scanPositions do
			if workspace:Raycast(target, pos - target, originRayParams) == nil and checkPoint(pos, overlapBulletParams) then
				self.Cache[part] = { pos }
				return pos
			end
		end
	end
end

local function wallcheck(origin: Vector3, position: Vector3, wallbang: Vector3?, part: Instance?): boolean
	local ray = workspace:Raycast(position, origin - position, originRayParams)
	if ray then
		return not wallbang or not OriginScanner:Scan(wallbang, position, ray.Position + ray.Normal * 0.01, part or workspace)
	end
	return false
end

local function getPlayerPart(player: Player, partName: string): BasePart?
	local char = getCharacter(player)
	if not char then
		return nil
	end
	local part = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function selectCombatTarget(settings: {
	origin: Vector3,
	range: number,
	rangePosition: number?,
	attackCheck: boolean,
	wallcheck: boolean?,
	wallbang: Vector3?,
	part: string,
	mode: string,
}): (Player?, BasePart?)
	local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not localRoot or not localRoot:IsA("BasePart") then
		return nil, nil
	end
	local mousePos = getMousePosition()
	local origin = settings.origin
	local bestPlayer: Player? = nil
	local bestPart: BasePart? = nil
	local bestMag = math.huge

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		if Config.SilentAimTeamCheck and sameTeam(player, LocalPlayer) then
			continue
		end
		local char = getCharacter(player)
		if not char or not isVulnerable(player, char, settings.attackCheck) then
			continue
		end
		local part = getPlayerPart(player, settings.part)
		if not part then
			continue
		end
		local worldMag = (part.Position - origin).Magnitude
		if settings.rangePosition and worldMag > settings.rangePosition then
			continue
		end
		local screenMag = math.huge
		if settings.mode == "Mouse" then
			local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
			if not onScreen or screenPos.Z <= 0 then
				continue
			end
			screenMag = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
			if screenMag > settings.range then
				continue
			end
		else
			local dist = (part.Position - localRoot.Position).Magnitude
			if dist > settings.range then
				continue
			end
			screenMag = dist
		end
		if settings.wallcheck and wallcheck(origin, part.Position, settings.wallbang, part) then
			continue
		end
		if screenMag < bestMag then
			bestMag = screenMag
			bestPlayer = player
			bestPart = part
		end
	end
	return bestPlayer, bestPart
end

local function getCombatTarget(origin: Vector3, gunData: any?): (Player?, BasePart?)
	if not Config.AutoFire and aimRand:NextNumber(0, 100) > Config.SilentAimHitChance then
		return nil, nil
	end
	local headChance = if Config.AutoFire then 100 else Config.SilentAimHeadshotChance
	local partName = if Config.SilentAimHead and aimRand:NextNumber(0, 100) < headChance then "Head" else "HumanoidRootPart"
	local limit = if gunData and gunData.Range then gunData.Range else 1000
	local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	return selectCombatTarget({
		origin = origin,
		range = if Config.SilentAimMode == "Position" then math.min(Config.SilentAimRange, limit) else Config.SilentAimRange,
		rangePosition = limit,
		attackCheck = not gunData or gunData.Behavior ~= "Taser",
		wallcheck = Config.SilentAimWallCheck,
		wallbang = if Config.SilentAimWallbang and localRoot and localRoot:IsA("BasePart") then localRoot.Position else nil,
		part = partName,
		mode = Config.SilentAimMode,
	})
end

local Spring = {}
Spring.__index = Spring
function Spring.new(props: { [string]: any }?)
	props = props or {}
	return setmetatable({
		Target = Vector3.zero,
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Mass = props.Mass or 5,
		Force = props.Force or 50,
		Damping = props.Damping or 4,
		Speed = props.Speed or 4,
	}, Spring)
end
function Spring:Update(dt: number): Vector3
	local iterations = math.max(1, math.round(dt / ((1 / 60) / 8)))
	local scaledDt = dt * self.Speed / iterations
	for _ = 1, iterations do
		local force = self.Target - self.Position
		local acceleration = (force * self.Force) / self.Mass - self.Velocity * self.Damping
		self.Velocity += acceleration * scaledDt
		self.Position += self.Velocity * scaledDt
	end
	return self.Position
end

local moveSpring = Spring.new()
local aimSpring = Spring.new({ Speed = 15 })

local function tracerHookDispatch(...)
	if debug.info(3, "s") ~= "ReplicatedStorage.Scripts.Replication.ClientReplicator" then
		for _, hook in TracerHook.Hooks do
			if hook[2](...) then
				return true
			end
		end
	end
	return false
end

function TracerHook:Add(key: string, fn: any, priority: number?)
	if not canHook or not GunTracers then
		return
	end
	table.insert(self.Hooks, { key, fn, priority or 0 })
	table.sort(self.Hooks, function(a, b)
		return a[3] < b[3]
	end)
	if GunTracers and not oldTracerBullet then
		oldTracerBullet = hookfunction(GunTracers.createBullet, function(...)
			if tracerHookDispatch(...) then
				return
			end
			return oldTracerBullet(...)
		end)
		oldTracerSniper = hookfunction(GunTracers.createSniper, function(...)
			if tracerHookDispatch(...) then
				return
			end
			return oldTracerSniper(...)
		end)
	end
end

function TracerHook:Remove(key: string)
	for i, hook in self.Hooks do
		if hook[1] == key then
			table.remove(self.Hooks, i)
			break
		end
	end
	if #self.Hooks == 0 and GunTracers and oldTracerBullet then
		if typeof(restorefunction) == "function" then
			restorefunction(GunTracers.createBullet)
			restorefunction(GunTracers.createSniper)
		else
			hookfunction(GunTracers.createBullet, oldTracerBullet)
			hookfunction(GunTracers.createSniper, oldTracerSniper)
		end
		oldTracerBullet = nil
		oldTracerSniper = nil
	end
end

local function flagCheater(player: Player, flagType: string, limit: number)
	if cheatFlagged[player.UserId] then
		return
	end
	if not cheatFlags[player.UserId] then
		cheatFlags[player.UserId] = {}
	end
	local flags = cheatFlags[player.UserId]
	flags[flagType] = (flags[flagType] or 0) + 1
	if flags[flagType] > limit then
		cheatFlagged[player.UserId] = true
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Cheat Detector",
				Text = player.Name .. " may be cheating (" .. flagType .. ")",
				Duration = 8,
			})
		end)
	end
end

local function playSoundId(soundId: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlayOnRemove = true
	sound.Parent = workspace
	sound:Destroy()
end

local function getRelation(player: Player, char: Model): string
	if player == LocalPlayer then
		return "Ally"
	end
	if sameTeam(player, LocalPlayer) then
		return "Ally"
	end
	if player.Team == TeamNeutral then
		return "Neutral"
	end
	if player.Team == TeamInmates and (char:GetAttribute("Hostile") or char:GetAttribute("Trespassing")) then
		return "Hostile"
	end
	return "Enemy"
end

local function relationColor(relation: string): Color3
	if relation == "Ally" then
		return Config.ESPAllyColor
	end
	if relation == "Neutral" then
		return Config.ESPNeutralColor
	end
	if relation == "Hostile" then
		return Config.ESPHostileColor
	end
	return Config.ESPEnemyColor
end

local function statusSuffix(char: Model): string
	if not Config.ESPStatusTags then
		return ""
	end
	if char:GetAttribute("Arrested") then
		return " [Arrested]"
	end
	if char:GetAttribute("Tased") then
		return " [Tased]"
	end
	if char:GetAttribute("Hostile") then
		return " [Hostile]"
	end
	if char:GetAttribute("Trespassing") then
		return " [Trespassing]"
	end
	return ""
end

local function getEntitiesInRange(range: number, mode: string)
	local localChar = LocalPlayer.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if not localRoot then
		return {}
	end

	local list = {}
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		if not char then
			continue
		end
		local alive, _, root = isAlive(char)
		if not alive or not root then
			continue
		end
		if (root.Position - localRoot.Position).Magnitude > range then
			continue
		end

		if mode == "arrest" then
			if sameTeam(player, LocalPlayer) then
				continue
			end
			if char:GetAttribute("Arrested") then
				continue
			end
		elseif mode == "combat" then
			if not isVulnerable(player, char, true) then
				continue
			end
		elseif not isVulnerable(player, char, false) then
			continue
		end

		table.insert(list, { player = player, char = char, root = root })
	end

	table.sort(list, function(a, b)
		return (a.root.Position - localRoot.Position).Magnitude < (b.root.Position - localRoot.Position).Magnitude
	end)
	return list
end

local function getGiverPosition(giver: Instance): Vector3?
	if giver:IsA("BasePart") then
		return giver.Position
	end
	if giver:IsA("Model") then
		return giver:GetPivot().Position
	end
	local part = giver:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position
end

local function revealGiver(giver: Instance)
	for _, part in giver:GetDescendants() do
		if part:IsA("BasePart") then
			local original = part:GetAttribute("OriginalTransparency")
			if original ~= nil then
				part.Transparency = original
			elseif part.Transparency >= 1 then
				part.Transparency = 0
			end
		end
	end
end

local function findWeaponGiver(weaponName: string): Instance?
	local items = workspace:FindFirstChild("Prison_ITEMS")
	local giverFolder = items and items:FindFirstChild("giver")
	local named = giverFolder and giverFolder:FindFirstChild(weaponName)
	if named then
		return named
	end
	for _, tag in { "Giver", "TouchGiver" } do
		for _, giver in CollectionService:GetTagged(tag) do
			if giver.Name == weaponName or giver:GetAttribute("ToolName") == weaponName then
				return giver
			end
		end
	end
	return nil
end

local function teleportNearGiver(giver: Instance)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = getGiverPosition(giver)
	if root and pos then
		root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	end
end

local function requestGiverWeapon(giver: Instance): boolean
	local remotes = getRemotes()
	local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
	if giverPressed then
		local ok = pcall(function()
			giverPressed:FireServer(giver)
		end)
		return ok
	end
	local pickup = giver:FindFirstChild("ITEMPICKUP", true)
	local remote = workspace:FindFirstChild("Remote")
	local handler = remote and remote:FindFirstChild("ItemHandler")
	if pickup and handler then
		return pcall(function()
			handler:InvokeServer(pickup)
		end)
	end
	return false
end

local function giveGiverWeapon(weaponName: string)
	task.spawn(function()
		local giver = findWeaponGiver(weaponName)
		if not giver then
			warn("[PrisonLife] giver not found:", weaponName)
			return
		end
		revealGiver(giver)
		teleportNearGiver(giver)
		task.wait(0.05)
		if not requestGiverWeapon(giver) then
			warn("[PrisonLife] failed to request weapon:", weaponName)
		end
	end)
end

local function isSprinting(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL3)
end

local function applyMovement()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if Config.SpeedBoost or Config.AlwaysSprint then
		hum.UseJumpPower = true
	end
	if Config.SpeedBoost then
		hum.WalkSpeed = math.min(Config.WalkSpeed, MAX_SAFE_WALKSPEED)
		hum.JumpPower = math.min(Config.JumpPower, MAX_SAFE_JUMP)
	elseif Config.AlwaysSprint and isSprinting() then
		hum.WalkSpeed = math.min(Config.SprintSpeed, MAX_SAFE_WALKSPEED)
	end
end

local function applyNoclip()
	if not Config.Noclip then
		return
	end
	local char = LocalPlayer.Character
	if not char then
		return
	end
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end

local function applyInfiniteAmmo()
	if not Config.InfiniteAmmo then
		return
	end
	local function patchTool(tool: Instance)
		if not tool:IsA("Tool") or not tool:GetAttribute("FireRate") then
			return
		end
		local maxAmmo = tool:GetAttribute("MaxAmmo") or 30
		local currentAmmo = tool:GetAttribute("Local_CurrentAmmo") or 0
		if currentAmmo < maxAmmo then
			tool:SetAttribute("Local_CurrentAmmo", maxAmmo)
		end
		local storedAmmo = tool:GetAttribute("StoredAmmo")
		if storedAmmo ~= nil and storedAmmo < maxAmmo then
			tool:SetAttribute("StoredAmmo", maxAmmo * 10)
		end
	end
	local char = LocalPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			patchTool(child)
		end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			patchTool(child)
		end
	end
end

local function applyFullBright()
	if Config.FullBright then
		if not lightingBackup then
			lightingBackup = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				FogEnd = Lighting.FogEnd,
				GlobalShadows = Lighting.GlobalShadows,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
		end
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
	elseif lightingBackup then
		for key, value in lightingBackup do
			Lighting[key] = value
		end
		lightingBackup = nil
	end
end

local function syncKillPlane()
	if Config.AntiKillPlane then
		if not killPlaneFolder then
			killPlaneFolder = Instance.new("Folder")
			killPlaneFolder.Name = "MicroHubPL_KillPlane"
			killPlaneFolder.Parent = workspace
			for x = -2048, 2048, 2048 do
				for z = -2048, 2048, 2048 do
					local part = Instance.new("Part")
					part.CanQuery = false
					part.CanCollide = true
					part.Anchored = true
					part.Transparency = 1
					part.Size = Vector3.new(2048, 10, 2048)
					part.Position = Vector3.new(x, 170, z)
					part.Parent = killPlaneFolder
					table.insert(killPlaneParts, part)
				end
			end
		end
	elseif killPlaneFolder then
		killPlaneFolder:Destroy()
		killPlaneFolder = nil
		table.clear(killPlaneParts)
	end
end

local function setDisabler(enabled: boolean)
	if not canHook then
		return
	end
	local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
	if not head then
		return
	end
	if enabled then
		local conn = getconnections(head:GetPropertyChangedSignal("CanCollide"))[1]
		if conn then
			conn:Disable()
			headCollideConn = conn
		end
	elseif headCollideConn then
		headCollideConn:Enable()
		headCollideConn = nil
	end
end

local function movementDisablerNeeded(): boolean
	return Config.Disabler
		or Config.SpeedBoost
		or Config.NoJumpCooldown
		or Config.Noclip
		or Config.AlwaysSprint
		or Config.VehicleSpeed
end

local function syncMovementDisabler()
	setDisabler(movementDisablerNeeded())
end

local function setAntiTaze(enabled: boolean)
	if not canHook then
		return
	end
	local gunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
	local playerTased = gunRemotes and gunRemotes:FindFirstChild("PlayerTased")
	if not playerTased then
		return
	end
	if enabled and not oldTazeFn then
		tazeRemoteConn = getconnections(playerTased.OnClientEvent)[1]
		if tazeRemoteConn and tazeRemoteConn.Function then
			oldTazeFn = tazeRemoteConn.Function
			hookfunction(oldTazeFn, function()
				local char = LocalPlayer.Character
				LocalPlayer:SetAttribute("BackpackEnabled", false)
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:UnequipTools()
					end
				end
				task.wait(3.5)
				if LocalPlayer.Character == char then
					LocalPlayer:SetAttribute("BackpackEnabled", true)
				end
			end)
		end
	elseif not enabled and oldTazeFn and tazeRemoteConn and tazeRemoteConn.Function then
		if typeof(restorefunction) == "function" then
			restorefunction(tazeRemoteConn.Function)
		else
			hookfunction(tazeRemoteConn.Function, oldTazeFn)
		end
		oldTazeFn = nil
		tazeRemoteConn = nil
	end
end

local function getBestBackupGun(): Tool?
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end
	local items: { Tool } = {}
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("FireRate") and child.Name ~= "Taser" and child.Name ~= "M700" then
			if (child:GetAttribute("Local_ReloadSession") or 0) <= 0 then
				table.insert(items, child)
			end
		end
	end
	table.sort(items, function(a, b)
		return (GUN_PRIORITY[a.Name] or 100) < (GUN_PRIORITY[b.Name] or 100)
	end)
	return items[1]
end

local function notifyKillfeed(killer: string, victim: string)
	if not Config.KillNotify then
		return
	end
	if victim == LocalPlayer.Name and killer ~= LocalPlayer.Name then
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Killed",
				Text = killer .. " killed you",
				Duration = 5,
			})
		end)
	end
end

local function setNoJumpCooldown(enabled: boolean)
	if not canHook then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if enabled then
		local conn = getconnections(hum:GetPropertyChangedSignal("Jump"))[1]
		if conn then
			conn:Disable()
			jumpConn = conn
		end
	else
		if jumpConn then
			jumpConn:Enable()
			jumpConn = nil
		end
	end
end

local function resolveGunController(): boolean
	if gun.Bullet then
		return true
	end
	if not canHook then
		return false
	end

	local gui = LocalPlayer.PlayerGui:FindFirstChild("Home")
	gui = gui and gui:FindFirstChild("hud")
	gui = gui and gui:FindFirstChild("ActionArea")
	if not gui then
		return false
	end

	pcall(function()
		for _, conn in getconnections(gui.InputBegan) do
			if not conn.Function then
				continue
			end
			local ok1, shoot = pcall(debug.getupvalue, conn.Function, 2)
			if not ok1 or typeof(shoot) ~= "function" then
				continue
			end
			gun.Shoot = shoot

			local ok2, reload = pcall(debug.getupvalue, shoot, 2)
			if ok2 and typeof(reload) == "function" then
				gun.Reload = reload
			end

			local ok3, bullet = pcall(debug.getupvalue, shoot, 16)
			if ok3 and typeof(bullet) == "function" then
				gun.Bullet = bullet
			end

			if not gun.Bullet then
				for i = 3, 25 do
					local okN, val = pcall(debug.getupvalue, shoot, i)
					if not okN then break end
					if typeof(val) == "function" and val ~= shoot and val ~= gun.Reload then
						gun.Bullet = val
						break
					end
				end
			end

			break
		end
	end)

	pcall(function()
		for _, conn in getconnections(LocalPlayer.CharacterAdded) do
			if not conn.Function then
				continue
			end
			local src = debug.info(conn.Function, "s")
			if not src or not src:find("GunController", 1, true) then
				continue
			end
			local ok, equip = pcall(debug.getupvalue, conn.Function, 3)
			if ok and typeof(equip) == "function" then
				gun.Equip = equip
			end
			break
		end
	end)

	return gun.Bullet ~= nil
end

local function getGunData()
	if not gun.Shoot then
		resolveGunController()
	end
	if not gun.Shoot then
		return nil
	end
	local fn = oldShootFn or gun.Shoot
	local ok10, val10 = pcall(debug.getupvalue, fn, 10)
	if ok10 and typeof(val10) == "table" then
		return val10
	end
	for i = 1, 25 do
		if i == 10 then continue end
		local ok, val = pcall(debug.getupvalue, fn, i)
		if not ok then
			break
		end
		if typeof(val) == "table" and (val.Range or val.FireRate or val.SpreadRadius or val.AutoFire ~= nil) then
			return val
		end
	end
	return nil
end

local function modifyGunData()
	local data = getGunData()
	if not data or not Config.GunMods then
		return
	end
	if gunDataRef ~= data then
		gunDataRef = data
		gunDataBackup = table.clone(data)
	end
	if not gunDataBackup then
		return
	end

	if gunDataBackup.SpreadRadius ~= nil then
		data.SpreadRadius = Config.GunNoSpread and 0 or gunDataBackup.SpreadRadius
	end
	if gunDataBackup.FireRate ~= nil then
		data.FireRate = gunDataBackup.FireRate * (Config.GunFireRate / 100)
	end
	if gunDataBackup.AutoFire ~= nil then
		data.AutoFire = Config.GunAutomatic or gunDataBackup.AutoFire
	end
end

local function patchToolGunAttributes(tool: Instance)
	if not Config.GunMods or not tool:IsA("Tool") or not tool:GetAttribute("FireRate") then
		return
	end
	if not toolAttrBackup[tool] then
		toolAttrBackup[tool] = {
			SpreadRadius = tool:GetAttribute("SpreadRadius"),
			FireRate = tool:GetAttribute("FireRate"),
			AutoFire = tool:GetAttribute("AutoFire"),
		}
	end
	local backup = toolAttrBackup[tool]
	if Config.GunNoSpread and backup.SpreadRadius ~= nil then
		tool:SetAttribute("SpreadRadius", 0)
	end
	if backup.FireRate then
		tool:SetAttribute("FireRate", backup.FireRate * (Config.GunFireRate / 100))
	end
	if Config.GunAutomatic then
		tool:SetAttribute("AutoFire", true)
	end
end

local function patchAllGunTools()
	if not Config.GunMods then
		return
	end
	local char = LocalPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			patchToolGunAttributes(child)
		end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			patchToolGunAttributes(child)
		end
	end
end

local function restoreGunData()
	if gunDataRef and gunDataBackup then
		for key, value in gunDataBackup do
			gunDataRef[key] = value
		end
	end
	gunDataRef = nil
	gunDataBackup = nil
end

local function hookSilentBullet(...)
	local args = table.pack(...)
	local origin = args[1]
	if typeof(origin) ~= "Vector3" then
		return oldBulletFn(table.unpack(args, 1, args.n))
	end
	local gunData = getGunData()
	local _, targetPart = getCombatTarget(origin, gunData)
	if not targetPart then
		return oldBulletFn(table.unpack(args, 1, args.n))
	end
	args[2] = targetPart.Position
	aimTimer = os.clock() + 0.3
	aimVec = args[2]
	if Config.SilentAimWallbang then
		local ignore = { LocalPlayer.Character }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		bulletRayParams.FilterDescendantsInstances = ignore
		local ray = workspace:Raycast(args[2], origin - args[2], bulletRayParams)
		if ray then
			local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if localRoot and localRoot:IsA("BasePart") then
				local newOrigin, hitbox = OriginScanner:Scan(localRoot.Position, args[2], ray.Position + ray.Normal * 0.01, targetPart)
				if newOrigin and canDebug then
					pcall(function()
						for i = 1, 40 do
							if debug.getstack(3, i) == origin then
								debug.setstack(3, i, newOrigin)
							end
						end
					end)
					args[1] = newOrigin
					if hitbox then
						return targetPart, hitbox
					end
				end
			end
		end
	end
	return oldBulletFn(table.unpack(args, 1, args.n))
end

local function installGunHooks()
	if not canHook then
		return
	end
	resolveGunController()
	if not gun.Shoot and not gun.Equip and not gun.Bullet then
		return
	end

	if Config.GunMods and gun.Equip and not hookedEquip then
		oldEquipFn = hookfunction(gun.Equip, function(...)
			local res = table.pack(oldEquipFn(...))
			modifyGunData()
			return table.unpack(res, 1, res.n)
		end)
		hookedEquip = true
	end

	if Config.AutoReload and gun.Shoot and not hookedShoot then
		oldShootFn = hookfunction(gun.Shoot, function(...)
			local res = table.pack(oldShootFn(...))
			local ok, tool = pcall(debug.getupvalue, oldShootFn, 1)
			if ok and typeof(tool) == "Instance" and tool:IsA("Tool") then
				if (tool:GetAttribute("Local_CurrentAmmo") or 0) <= 0 then
					task.spawn(gun.Reload)
					if Config.AutoReloadSwap then
						local swap = getBestBackupGun()
						if swap then
							tool.Parent = LocalPlayer.Backpack
							swap.Parent = LocalPlayer.Character
						end
					end
				end
			end
			return table.unpack(res, 1, res.n)
		end)
		hookedShoot = true
	end

	if Config.SilentAim and gun.Bullet and not hookedBullet then
		oldBulletFn = hookfunction(gun.Bullet, hookSilentBullet)
		hookedBullet = true
	end
end

local function removeGunHooks()
	if hookedBullet and oldBulletFn and gun.Bullet then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Bullet)
		else
			hookfunction(gun.Bullet, oldBulletFn)
		end
		hookedBullet = nil
		oldBulletFn = nil
	end
	if hookedShoot and oldShootFn and gun.Shoot then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Shoot)
		else
			hookfunction(gun.Shoot, oldShootFn)
		end
		hookedShoot = nil
		oldShootFn = nil
	end
	if hookedEquip and oldEquipFn and gun.Equip then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Equip)
		else
			hookfunction(gun.Equip, oldEquipFn)
		end
		hookedEquip = nil
		oldEquipFn = nil
	end
	restoreGunData()
end

local function tryAutoFire()
	if not Config.AutoFire or not gun.Shoot then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local tool = char:FindFirstChildWhichIsA("Tool")
	if not tool or (tool:GetAttribute("Local_CurrentAmmo") or 0) <= 0 then
		return
	end
	if tool:GetAttribute("Local_IsShooting") then
		return
	end
	local data = getGunData()
	local head = char:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else char:GetPivot().Position
	local _, target = getCombatTarget(origin, data)
	if not target then
		return
	end
	if data and data.Behavior == "Taser" and target.Parent and target.Parent:GetAttribute("Tased") then
		return
	end
	local input = {
		UserInputState = Enum.UserInputState.Begin,
		UserInputType = Enum.UserInputType.MouseButton1,
		Position = Vector3.zero,
	}
	task.spawn(gun.Shoot, input)
	input.UserInputState = Enum.UserInputState.End
end

local autoFireCooldown = 0

local function refreshGunFeatures()
	removeGunHooks()
	if Config.GunMods or Config.SilentAim or Config.AutoReload then
		installGunHooks()
	end
	if Config.GunMods then
		modifyGunData()
	end
end

local function runKillaura()
	if not Config.Killaura then
		return
	end
	local melee = getMeleeRemote()
	if not melee then
		return
	end
	for _, ent in getEntitiesInRange(Config.KillauraRange, "combat") do
		pcall(function()
			melee:FireServer(ent.player, 1, 1)
		end)
	end
end

local function runAutoArrest()
	if not Config.AutoArrest or os.clock() < arrestCooldown then
		return
	end
	local remotes = getRemotes()
	local arrest = remotes and remotes:FindFirstChild("ArrestPlayer")
	if not arrest then
		return
	end

	if Config.ArrestHandCheck then
		local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
		if not tool or tool.Name ~= "Handcuffs" then
			return
		end
	end

	for _, ent in getEntitiesInRange(Config.AutoArrestRange, "arrest") do
		local player = ent.player
		local char = ent.char
		if char:GetAttribute("Arrested") then
			continue
		end
		if player.Team == TeamInmates and not Config.ArrestInmates then
			continue
		end
		if player.Team == TeamCriminals and not Config.ArrestCriminals then
			continue
		end
		if player.Team == TeamInmates and char:GetAttribute("Hostile") and not char:GetAttribute("Tased") then
			continue
		end

		local ok, arrested = pcall(function()
			return arrest:InvokeServer(player, 1)
		end)
		if ok and arrested then
			arrestCooldown = os.clock() + 7
			break
		end
	end
end

local function runAutoHeal()
	if not Config.AutoHeal then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health > 85 then
		return
	end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local remotes = getRemotes()
	local eat = remotes and remotes:FindFirstChild("EatFood")
	if not backpack or not eat then
		return
	end

	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and HEAL_ITEMS[tool.Name] then
			if (os.clock() - (tool:GetAttribute("Client_LastConsumedAt") or 0)) < 3 then
				continue
			end
			local equipped = char:FindFirstChildWhichIsA("Tool")
			if equipped then
				equipped.Parent = backpack
			end
			tool.Parent = char
			tool:SetAttribute("Quantity", (tool:GetAttribute("Quantity") or 1) - 1)
			tool:SetAttribute("Client_LastConsumedAt", os.clock())
			pcall(function()
				eat:FireServer()
			end)
			tool.Parent = backpack
			if equipped then
				equipped.Parent = char
			end
			break
		end
	end
end

local pickupItems: { { any } } = {}

local function registerPickup(obj: Instance, touchGiver: boolean)
	if pickupSeen[obj] then
		return
	end
	if not obj:IsA("Model") or obj.Name == "Model" or not obj:GetAttribute("ToolName") then
		return
	end
	pickupSeen[obj] = true
	table.insert(pickupItems, { obj, touchGiver or obj.Name == "TouchGiver" })
end

local function unregisterPickup(obj: Instance)
	if not pickupSeen[obj] then
		return
	end
	pickupSeen[obj] = nil
	for i, entry in pickupItems do
		if entry[1] == obj then
			table.remove(pickupItems, i)
			break
		end
	end
end

local function refreshPickupIndex()
	for _, tag in { "Giver", "TouchGiver" } do
		for _, giver in CollectionService:GetTagged(tag) do
			registerPickup(giver, tag == "TouchGiver")
		end
	end
	for _, obj in workspace:GetChildren() do
		if obj:IsA("Model") and obj:GetAttribute("ToolName") then
			registerPickup(obj, obj.Name == "TouchGiver")
		end
	end
end

local function runAutoArmor()
	if not Config.AutoArmor then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.MaxHealth > 100 then
		return
	end
	local remotes = getRemotes()
	local interact = remotes and remotes:FindFirstChild("InteractWithItem")
	if not interact then
		return
	end
	for _, vest in armorPickups do
		if not vest.Parent or (vest:GetPivot().Position - root.Position).Magnitude >= 10 then
			continue
		end
		if vest.Name == "Light Vest" and gamepasses[if LocalPlayer.Team == TeamCriminals then "Mafia" else "Riot Police"] then
			continue
		end
		local required = vest:GetAttribute("RequiredGamepass")
		if required and not gamepasses[required] then
			continue
		end
		local part = vest:FindFirstChildWhichIsA("BasePart", true)
		if part then
			pcall(function()
				interact:InvokeServer(part)
			end)
		end
	end
end

local function runAutoDetonate()
	if not Config.AutoDetonate or not localC4 or not localC4.Parent then
		return
	end
	local remotes = getRemotes()
	local activate = remotes and remotes:FindFirstChild("C4") and remotes.C4:FindFirstChild("ActivateC4")
	if not activate then
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not root or not backpack then
		return
	end
	local c4Tool = backpack:FindFirstChild("C4 Explosive")
	if not c4Tool then
		return
	end

	local c4Pos = if localC4:IsA("BasePart") then localC4.Position else localC4:GetPivot().Position
	local _, targetPart = selectCombatTarget({
		origin = c4Pos,
		range = 25,
		rangePosition = 25,
		attackCheck = false,
		wallcheck = false,
		wallbang = nil,
		part = "HumanoidRootPart",
		mode = "Position",
	})
	if not targetPart then
		detonateTicks = 0
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.CollisionGroup = "ClientBullet"
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { targetPart.Parent, char, localC4 }
	local blocked = workspace:Raycast(c4Pos, targetPart.Position - c4Pos, rayParams)
	if Config.AutoDetonateSafe and not blocked then
		local rootDiff = root.Position - c4Pos
		blocked = not (workspace:Raycast(c4Pos, rootDiff, rayParams) or rootDiff.Magnitude > 40)
	end
	if blocked then
		detonateTicks = 0
		return
	end

	detonateTicks += 1
	if detonateTicks <= 3 then
		return
	end
	detonateTicks = 0

	local equipped = char:FindFirstChildWhichIsA("Tool")
	if equipped then
		equipped.Parent = backpack
	end
	c4Tool.Parent = char
	pcall(function()
		activate:InvokeServer()
	end)
	c4Tool.Parent = backpack
	if equipped then
		equipped.Parent = char
	end
end

local function runVehicleWallbang()
	if not Config.VehicleWallbang then
		for part, value in vehicleQueryBackup do
			if part.Parent then
				part.CanQuery = value
			end
		end
		table.clear(vehicleQueryBackup)
		return
	end
	local cars = workspace:FindFirstChild("CarContainer")
	if not cars then
		return
	end
	for _, part in cars:GetDescendants() do
		if part:IsA("BasePart") then
			if vehicleQueryBackup[part] == nil then
				vehicleQueryBackup[part] = part.CanQuery
			end
			part.CanQuery = false
		end
	end
end

local function runAutoPickup()
	if not Config.AutoPickup then
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local remotes = getRemotes()
	local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
	if not root or not backpack or not giverPressed then
		return
	end

	for _, entry in pickupItems do
		local model = entry[1]
		if not model.Parent then
			continue
		end
		local pos = getGiverPosition(model)
		if not pos or (pos - root.Position).Magnitude > 12 then
			continue
		end
		local toolName = model:GetAttribute("ToolName") or model.Name
		if typeof(toolName) ~= "string" or backpack:FindFirstChild(toolName) then
			continue
		end
		if entry[2] then
			local teamKey = if LocalPlayer.Team == TeamGuards
				then "Guard"
				elseif LocalPlayer.Team == TeamCriminals then "Criminal"
				else "Prisoner"
			local wanted = sortedPickups[teamKey]
			local skip = false
			local indices = {}
			for idx in wanted do
				table.insert(indices, idx)
			end
			table.sort(indices)
			for _, idx in indices do
				local itemName = wanted[idx]
				if not backpack:FindFirstChild(itemName) then
					if toolName ~= itemName then
						skip = true
					end
					break
				end
			end
			if skip then
				continue
			end
		end
		revealGiver(model)
		pcall(function()
			giverPressed:FireServer(model)
		end)
	end
end

local function runAntiRiotShield()
	if not Config.AntiRiotShield then
		return
	end
	for _, player in Players:GetPlayers() do
		local char = getCharacter(player)
		local shield = char and char:FindFirstChild("RiotShieldPart")
		if shield and shield:IsA("BasePart") then
			shield.CanQuery = false
		end
	end
end

local function runVehicleSpeed()
	if not Config.VehicleSpeed then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat or not seat:IsDescendantOf(workspace:FindFirstChild("CarContainer") or workspace) then
		return
	end
	local car = seat:FindFirstAncestorWhichIsA("Model")
	if not car then
		return
	end
	for _, child in car:GetDescendants() do
		if child:IsA("VehicleSeat") then
			child.MaxSpeed = Config.VehicleSpeedValue
			child.Torque = 4
		end
	end
end

local function syncSilentAimCircle()
	if not canDraw then
		return
	end
	if Config.SilentAim and Config.SilentAimRangeCircle and Config.SilentAimMode == "Mouse" then
		if not silentAimCircle then
			silentAimCircle = Drawing.new("Circle")
			silentAimCircle.NumSides = 64
			silentAimCircle.Thickness = 1
			silentAimCircle.Filled = false
			silentAimCircle.Color = Color3.fromRGB(255, 255, 255)
			silentAimCircle.Transparency = 0.5
		end
		silentAimCircle.Position = getMousePosition()
		silentAimCircle.Radius = Config.SilentAimRange
		silentAimCircle.Visible = true
	elseif silentAimCircle then
		silentAimCircle.Visible = false
	end
end

local function syncBulletTracers(enabled: boolean)
	if enabled and GunTracers then
		TracerHook:Add("BulletTracers", function(origin, dir)
			local startPos = origin
			if viewmodelClone then
				local muzzle = viewmodelClone:FindFirstChild("Muzzle", true)
				if muzzle and muzzle:IsA("BasePart") then
					startPos = muzzle.Position
				end
			end
			local velocity = CFrame.lookAt(startPos, dir).LookVector * 1000
			if Config.BulletTracerDrawing and canDraw then
				local line = Drawing.new("Line")
				line.Thickness = 2
				line.Color = Config.BulletTracerColor
				tracerDrawingObjs[line] = { startPos, startPos + velocity, os.clock() }
				task.delay(Config.BulletTracerLifetime, function()
					tracerDrawingObjs[line] = nil
					pcall(function()
						line.Visible = false
						line:Remove()
					end)
				end)
			else
				local part = Instance.new("Part")
				part.Size = Vector3.new(0.1, 0.1, velocity.Magnitude)
				part.CFrame = CFrame.lookAt(startPos + velocity / 2, startPos + velocity)
				part.CanCollide = false
				part.CanQuery = false
				part.Anchored = true
				part.Color = Config.BulletTracerColor
				part.Transparency = 0.35
				part.Parent = workspace
				if Config.BulletTracerFade then
					TweenService:Create(part, TweenInfo.new(Config.BulletTracerLifetime), { Transparency = 1 }):Play()
				end
				task.delay(Config.BulletTracerLifetime, part.Destroy, part)
			end
			return true
		end, 1)
	else
		TracerHook:Remove("BulletTracers")
	end
end

local function updateBulletTracerDrawings()
	if not Config.BulletTracers or not Config.BulletTracerDrawing then
		return
	end
	for line, data in tracerDrawingObjs do
		local from, vis1 = Camera:WorldToViewportPoint(data[1])
		local to, vis2 = Camera:WorldToViewportPoint(data[2])
		if vis1 and vis2 then
			line.Visible = true
			line.From = Vector2.new(from.X, from.Y)
			line.To = Vector2.new(to.X, to.Y)
			if Config.BulletTracerFade then
				line.Transparency = 1 - math.clamp((os.clock() - data[3]) / Config.BulletTracerLifetime, 0, 1)
			end
		else
			line.Visible = false
		end
	end
end

local function syncDamageIndicator(enabled: boolean)
	if enabled then
		TracerHook:Add("DamageIndicator", function()
			if not canDebug then
				return false
			end
			local part = debug.getstack(4, 17)
			if typeof(part) ~= "Instance" then
				return false
			end
			for _, player in Players:GetPlayers() do
				local char = getCharacter(player)
				if char and part:IsDescendantOf(char) and isVulnerable(player, char, true) then
					if damageTargetTimer <= os.clock() or damageTargetChar ~= char then
						local hum = char:FindFirstChildOfClass("Humanoid")
						damageTargetHealth = hum and hum.Health or 0
					end
					damageTargetChar = char
					damageTargetTimer = os.clock() + 0.5
					break
				end
			end
			return false
		end, 2)
	else
		TracerHook:Remove("DamageIndicator")
	end
end

local function runDamageIndicator()
	if not Config.DamageIndicator or not damageTargetChar or damageTargetTimer <= os.clock() then
		return
	end
	local hum = damageTargetChar:FindFirstChildOfClass("Humanoid")
	local head = damageTargetChar:FindFirstChild("Head")
	if not hum or not head or not head:IsA("BasePart") then
		return
	end
	if damageTargetHealth > hum.Health then
		local damage = damageTargetHealth - hum.Health
		damageTargetHealth = hum.Health
		if damageIndicatorThread then
			pcall(task.cancel, damageIndicatorThread)
		end
		if not damageIndicatorPart then
			damageIndicatorPart = Instance.new("Part")
			damageIndicatorPart.Size = Vector3.zero
			damageIndicatorPart.Anchored = true
			damageIndicatorPart.CanCollide = false
			damageIndicatorPart.CanQuery = false
			damageIndicatorPart.Transparency = 1
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(30, 30)
			billboard.AlwaysOnTop = true
			billboard.Parent = damageIndicatorPart
			local label = Instance.new("TextLabel")
			label.Name = "Damage"
			label.BackgroundTransparency = 1
			label.TextStrokeTransparency = 0
			label.Size = UDim2.fromScale(1, 1)
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.TextColor3 = Color3.fromRGB(255, 72, 72)
			label.Parent = billboard
		end
		damageIndicatorPart.Position = head.Position + Vector3.new(0, 2, 0)
		damageIndicatorPart.Parent = workspace
		local label = damageIndicatorPart:FindFirstChildWhichIsA("BillboardGui", true)
		label = label and label:FindFirstChild("Damage")
		if label and label:IsA("TextLabel") then
			label.Text = tostring(math.ceil(damage))
		end
		damageIndicatorThread = task.delay(1, function()
			if damageIndicatorPart then
				damageIndicatorPart.Parent = nil
			end
			damageIndicatorThread = nil
		end)
	end
end

local function syncHitSound(enabled: boolean)
	if enabled then
		TracerHook:Add("HitSound", function()
			if not canDebug then
				return false
			end
			local part = debug.getstack(4, 17)
			if typeof(part) == "Instance" then
				for _, player in Players:GetPlayers() do
					local char = getCharacter(player)
					if char and part:IsDescendantOf(char) and isVulnerable(player, char, true) then
						playSoundId("rbxassetid://12222216", 1)
						break
					end
				end
			end
			return false
		end, 3)
	else
		TracerHook:Remove("HitSound")
	end
end

local function restoreViewmodel()
	if viewmodelRealTool then
		for _, part in viewmodelRealTool:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
				part.LocalTransparencyModifier = 0
			end
		end
		viewmodelRealTool = nil
	end
	if viewmodelClone then
		viewmodelClone:Destroy()
		viewmodelClone = nil
		viewmodelHandle = nil
	end
end

local function onViewmodelToolAdded(tool: Tool)
	if not Config.Viewmodel then
		return
	end
	restoreViewmodel()
	viewmodelRealTool = tool
	viewmodelClone = tool:Clone()
	local handle = viewmodelClone:FindFirstChild("Handle")
	viewmodelHandle = if handle and handle:IsA("BasePart") then handle else nil
	viewmodelClone.Parent = Camera
	for _, part in viewmodelClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
			part.LocalTransparencyModifier = 1
		end
	end
end

local function syncViewmodel(enabled: boolean)
	if enabled then
		TracerHook:Add("Viewmodel", function()
			shootTimer = os.clock() + 0.3
			return false
		end, 0)
		local char = LocalPlayer.Character
		if char then
			local tool = char:FindFirstChildWhichIsA("Tool")
			if tool then
				onViewmodelToolAdded(tool)
			end
		end
	else
		TracerHook:Remove("Viewmodel")
		restoreViewmodel()
	end
end

local function updateViewmodel(dt: number)
	if not Config.Viewmodel or not viewmodelHandle then
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	moveSpring.Target = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity * 0.005 else Vector3.zero
	if Config.ViewmodelSway and moveSpring.Target.Magnitude > 0.1 then
		moveSpring.Target += (Camera.CFrame * CFrame.new(math.sin(os.clock() * 10) * 0.06, 0, 0)).Position - Camera.CFrame.Position
	end
	local cf = (Camera.CFrame * CFrame.new(Config.ViewmodelHorizontal, Config.ViewmodelVertical, -Config.ViewmodelDepth)) + moveSpring:Update(dt)
	aimSpring.Target = if aimTimer > os.clock() then CFrame.lookAt(cf.Position, aimVec).LookVector else Camera.CFrame.LookVector
	local recoil = math.max(shootTimer - os.clock(), 0)
	viewmodelHandle.CFrame = CFrame.lookAlong(cf.Position, aimSpring:Update(dt))
		* CFrame.Angles(math.rad(recoil * 10), 0, 0)
		* CFrame.new(0, 0, recoil)
	viewmodelHandle.AssemblyLinearVelocity = Vector3.zero
end

local function syncCrosshair(enabled: boolean)
	if not canDebug or (not gun.Equip and not oldEquipFn) then
		return
	end
	local fn = oldEquipFn or gun.Equip
	if not fn then
		return
	end
	pcall(function()
		debug.setconstant(fn, 30, if enabled then "" else "rbxassetid://98794608762931")
	end)
end

local function syncCameraPhase(enabled: boolean)
	if not canDebug then
		return
	end
	if enabled then
		pcall(function()
			local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
			local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
			local cameraModule = playerModule and playerModule:FindFirstChild("CameraModule")
			local zoomController = cameraModule and cameraModule:FindFirstChild("ZoomController")
			local popper = zoomController and zoomController:FindFirstChild("Popper")
			if popper then
				local req = require(popper)
				cameraPhaseFn = debug.getupvalue(debug.getupvalue(req, 3), 7)
				debug.setconstant(cameraPhaseFn, 16, 0)
			end
		end)
	elseif cameraPhaseFn then
		pcall(function()
			debug.setconstant(cameraPhaseFn, 16, 0.25)
		end)
		cameraPhaseFn = nil
	end
end

local animWhitelistDefaults = {
	["http://www.roblox.com/asset/?id=125750702"] = true,
	["rbxassetid://279227693"] = true,
	["rbxassetid://279229192"] = true,
}

local function isAnimWhitelisted(id: string): boolean
	return animWhitelist[id] == true or animWhitelistDefaults[id] == true
end

local function onAntiInvisibleAnimation(track: AnimationTrack, player: Player?)
	if not Config.AntiInvisible or not player or isAnimWhitelisted(track.Animation.AnimationId) then
		return
	end
	flagCheater(player, "invalid animation", 1)
	if antiInvisibleThreads[track] then
		pcall(task.cancel, antiInvisibleThreads[track])
	end
	antiInvisibleThreads[track] = task.spawn(function()
		while track.IsPlaying and Config.AntiInvisible do
			track:AdjustWeight(0, 0)
			task.wait()
		end
		antiInvisibleThreads[track] = nil
	end)
end

local function bindAntiInvisiblePlayer(player: Player)
	if player == LocalPlayer or not Config.AntiInvisible then
		return
	end
	local function onChar(char: Model)
		local hum = char:WaitForChild("Humanoid", 5)
		local animator = hum and hum:WaitForChild("Animator", 5)
		if not animator then
			return
		end
		table.insert(connections, animator.AnimationPlayed:Connect(function(track)
			onAntiInvisibleAnimation(track, player)
		end))
		for _, track in animator:GetPlayingAnimationTracks() do
			task.spawn(onAntiInvisibleAnimation, track, player)
		end
	end
	if player.Character then
		task.spawn(onChar, player.Character)
	end
	table.insert(connections, player.CharacterAdded:Connect(onChar))
end

local function syncAntiInvisible(enabled: boolean)
	if not enabled then
		for _, threadRef in antiInvisibleThreads do
			pcall(task.cancel, threadRef)
		end
		table.clear(antiInvisibleThreads)
	end
end

local vehicleFlyConn: RBXScriptConnection? = nil
local vehicleFlySeat: Instance? = nil
local vehicleFlyInputBound = false

local function stopVehicleFly()
	if vehicleFlyPart then
		vehicleFlyPart:Destroy()
		vehicleFlyPart = nil
	end
	for _, weld in vehicleFlyWelds do
		pcall(function()
			if typeof(weld) == "Instance" and weld:IsA("Constraint") then
				weld.Enabled = true
			end
		end)
	end
	table.clear(vehicleFlyWelds)
	vehicleFlySeat = nil
	if vehicleFlyConn then
		vehicleFlyConn:Disconnect()
		vehicleFlyConn = nil
	end
end

local function syncVehicleFly(enabled: boolean)
	stopVehicleFly()
	if not enabled then
		return
	end
	if not vehicleFlyInputBound then
		vehicleFlyInputBound = true
		for _, eventName in { "InputBegan", "InputEnded" } do
			table.insert(connections, UserInputService[eventName]:Connect(function(input)
				if UserInputService:GetFocusedTextBox() then
					return
				end
				if input.KeyCode == Enum.KeyCode.E then
					vehicleFlyUp = if eventName == "InputBegan" then 1 else 0
				elseif input.KeyCode == Enum.KeyCode.Q then
					vehicleFlyDown = if eventName == "InputBegan" then -1 else 0
				end
			end))
		end
	end
	if Config.VehicleFlyMode == "Part" then
		vehicleFlyPart = Instance.new("Part")
		vehicleFlyPart.Size = Vector3.new(50, 1, 50)
		vehicleFlyPart.Anchored = true
		vehicleFlyPart.CanQuery = false
		vehicleFlyPart.Transparency = 1
		vehicleFlyPart.Parent = nil
		startLoop(function()
			if not Config.VehicleFly then
				return
			end
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			if seat and vehicleFlyPart then
				vehicleFlyPart.CFrame = CFrame.new(seat.Position - Vector3.new(0, 2.2 - (vehicleFlyUp + vehicleFlyDown), 0))
				vehicleFlyPart.Parent = workspace
			elseif vehicleFlyPart then
				vehicleFlyPart.Parent = nil
			end
		end)
	else
		local inCar = false
		vehicleFlyConn = RunService.PreSimulation:Connect(function(dt)
			if not Config.VehicleFly then
				return
			end
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			local root = seat and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and seat then
				if seat ~= vehicleFlySeat then
					inCar = seat:IsDescendantOf(workspace:FindFirstChild("CarContainer") or workspace) and seat:IsA("VehicleSeat")
					table.clear(vehicleFlyWelds)
					if inCar then
						local wheels = seat.Parent and seat.Parent.Parent and seat.Parent.Parent:FindFirstChild("Wheels")
						if wheels then
							for _, weld in wheels:GetDescendants() do
								if weld:IsA("HingeConstraint") or weld:IsA("CylindricalConstraint") or weld.Name == "Rotate" then
									pcall(function()
										weld.Enabled = false
									end)
									table.insert(vehicleFlyWelds, weld)
								end
							end
						end
					end
					vehicleFlySeat = seat
				end
				if inCar then
					root.AssemblyLinearVelocity = Vector3.new(0, 2.25, 0)
					root.CFrame = CFrame.lookAlong(
						root.Position,
						Camera.CFrame.LookVector
					) + (hum.MoveDirection + Vector3.new(0, vehicleFlyUp + vehicleFlyDown, 0)) * Config.VehicleFlySpeed * dt
					Camera.CameraSubject = hum
				end
			elseif vehicleFlySeat then
				vehicleFlySeat = nil
				for _, weld in vehicleFlyWelds do
					pcall(function()
						if typeof(weld) == "Instance" and weld:IsA("Constraint") then
							weld.Enabled = true
						end
					end)
				end
				table.clear(vehicleFlyWelds)
			end
		end)
		table.insert(connections, vehicleFlyConn)
	end
end

local cheatOverlap = OverlapParams.new()
cheatOverlap.CollisionGroup = "Players"
cheatOverlap.FilterDescendantsInstances = { workspace:FindFirstChild("CarContainer"), workspace:FindFirstChild("Doors") }
cheatOverlap.FilterType = Enum.RaycastFilterType.Exclude
local carOverlap = OverlapParams.new()
carOverlap.FilterDescendantsInstances = { workspace:FindFirstChild("CarContainer") }
carOverlap.FilterType = Enum.RaycastFilterType.Include
carOverlap.MaxParts = 1
local whitelistStates = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.None] = true,
}

local function runCheatDetector()
	if not Config.CheatDetector then
		return
	end
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local head = char and char:FindFirstChild("Head")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not head or not root or hum.Health <= 0 then
			continue
		end
		if head:IsA("BasePart") and not checkPoint(head.Position, cheatOverlap) then
			flagCheater(player, "phase/noclip", 20)
		end
		if not whitelistStates[hum:GetState()] then
			flagCheater(player, "invalid state " .. hum:GetState().Name, 1)
		end
		if not hum.SeatPart then
			local velo = root.AssemblyLinearVelocity
			if (velo * Vector3.new(1, 0, 1)).Magnitude > 26 and #workspace:GetPartBoundsInRadius(root.Position, 10, carOverlap) <= 0 then
				flagCheater(player, "speed", 20)
			end
			if velo.Y > 50 then
				flagCheater(player, "highjump", 20)
			end
		end
	end
end

local function addC4Highlight(obj: Instance)
	if c4Highlights[obj] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = obj
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 72, 72)
	highlight.OutlineColor = Color3.fromRGB(255, 200, 80)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.2
	highlight.Parent = c4Folder
	c4Highlights[obj] = highlight
end

local function removeC4Highlight(obj: Instance)
	local highlight = c4Highlights[obj]
	if highlight then
		highlight:Destroy()
		c4Highlights[obj] = nil
	end
end

local function syncC4ESP()
	if not Config.C4ESP then
		for obj in pairs(c4Highlights) do
			removeC4Highlight(obj)
		end
		return
	end
	for _, obj in CollectionService:GetTagged("C4") do
		addC4Highlight(obj)
	end
end

-- ESP v2 — optimized, visually improved

local espNeedsHide = false
local ESP_MAX_DIST = 2000

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function hpColor(ratio: number): Color3
	if ratio > 0.5 then
		return lerpColor(Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 230, 120), (ratio - 0.5) * 2)
	end
	return lerpColor(Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 220, 60), ratio * 2)
end

local function formatDist(studs: number): string
	if studs >= 1000 then
		return string.format("%.1fk", studs / 1000)
	end
	return string.format("%d", math.floor(studs))
end

local function getWeaponName(char: Model): string?
	local tool = char:FindFirstChildWhichIsA("Tool")
	return tool and tool.Name or nil
end

local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
	if not char.Parent or not root.Parent then
		return nil
	end
	local head = char:FindFirstChild("Head")
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

local function mkDraw(kind: string, props: { [string]: any })
	local d = Drawing.new(kind)
	for k, v in props do
		d[k] = v
	end
	d.Visible = false
	return d
end

local function hideEntry(entry: any)
	for _, obj in entry do
		pcall(function()
			obj.Visible = false
		end)
	end
end

local function hideAllESP()
	for _, entry in esp do
		hideEntry(entry)
	end
end

local function destroyEntry(entry: any)
	for _, obj in entry do
		pcall(function()
			obj:Remove()
		end)
	end
end

local function ensureESP(char: Model)
	if esp[char] then
		return esp[char]
	end

	local entry = {
		boxOutline = mkDraw("Square", { Filled = false, Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0.6 }),
		box = mkDraw("Square", { Filled = false, Thickness = 1.4 }),
		hpBarBg = mkDraw("Square", { Filled = true, Thickness = 0, Color = Color3.fromRGB(20, 20, 20), Transparency = 0.3 }),
		hpBar = mkDraw("Square", { Filled = true, Thickness = 0 }),
		name = mkDraw("Text", { Size = 14, Center = true, Outline = true, Font = 2 }),
		weapon = mkDraw("Text", { Size = 11, Center = true, Outline = true, Font = 2, Color = Color3.fromRGB(200, 200, 200) }),
		dist = mkDraw("Text", { Size = 11, Center = true, Outline = true, Font = 2 }),
		snapline = mkDraw("Line", { Thickness = 1, Transparency = 0.4 }),
	}
	esp[char] = entry
	return entry
end

local function drawTarget(player: Player, char: Model, hum: Humanoid, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
	local rel = getRelation(player, char)
	if rel == "Ally" and not Config.ESPAllies then
		if esp[char] then
			hideEntry(esp[char])
		end
		return
	end

	local dist = (root.Position - camPos).Magnitude
	if dist > ESP_MAX_DIST then
		if esp[char] then
			hideEntry(esp[char])
		end
		return
	end

	local x, y, w, h = box2d(char, root)
	if not x then
		if esp[char] then
			hideEntry(esp[char])
		end
		return
	end

	local entry = ensureESP(char)
	local accent = relationColor(rel)
	local cx = x + w * 0.5
	local bottom = y + h
	local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)

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
	entry.hpBar.Color = hpColor(ratio)
	entry.hpBar.Visible = true

	local suffix = statusSuffix(char)
	local nameStr = player.DisplayName
	if suffix ~= "" then
		nameStr = nameStr .. " " .. suffix
	end
	entry.name.Position = Vector2.new(cx, y - 16)
	entry.name.Text = nameStr
	entry.name.Color = accent
	entry.name.Visible = true

	local wepName = getWeaponName(char)
	entry.weapon.Position = Vector2.new(cx, bottom + 2)
	entry.weapon.Text = wepName or ""
	entry.weapon.Visible = wepName ~= nil

	local distStr = formatDist(dist) .. "m"
	if ratio < 1 then
		distStr = distStr .. " | " .. math.floor(hum.Health) .. "hp"
	end
	entry.dist.Position = Vector2.new(cx, bottom + (if wepName then 14 else 2))
	entry.dist.Text = distStr
	entry.dist.Color = DIM
	entry.dist.Visible = true

	if snapFrom then
		entry.snapline.From = snapFrom
		entry.snapline.To = Vector2.new(cx, bottom + 1)
		entry.snapline.Color = accent
		entry.snapline.Transparency = 0.5 * fadeAlpha
	end
	entry.snapline.Visible = Config.ESPSnaplines and snapFrom ~= nil
end

local function updateESP()
	if not canDraw then
		return
	end
	if not Config.ESP then
		if espNeedsHide then
			for char, entry in esp do
				destroyEntry(entry)
				esp[char] = nil
			end
			espNeedsHide = false
		end
		return
	end
	espNeedsHide = true

	local camPos = Camera.CFrame.Position
	local vpSize = Camera.ViewportSize
	local snapFrom = if Config.ESPSnaplines
		then Vector2.new(vpSize.X * 0.5, vpSize.Y)
		else nil
	local seen: { [Model]: boolean } = {}

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		if not char then
			continue
		end
		local alive, hum, root = isAlive(char)
		if alive and hum and root then
			seen[char] = true
			drawTarget(player, char, hum, root, camPos, snapFrom)
		end
	end

	for char, entry in esp do
		if not seen[char] or not char.Parent then
			destroyEntry(entry)
			esp[char] = nil
		end
	end
end

local genv = if typeof(getgenv) == "function" then getgenv() else _G

genv.__PrisonLifeUnload = function()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	for _, threadRef in loops do
		stopLoop(threadRef)
	end
	table.clear(loops)
	removeGunHooks()
	setNoJumpCooldown(false)
	setDisabler(false)
	setAntiTaze(false)
	applyFullBright()
	runVehicleWallbang()
	syncKillPlane()
	syncBulletTracers(false)
	syncDamageIndicator(false)
	syncHitSound(false)
	syncViewmodel(false)
	syncCrosshair(false)
	syncCameraPhase(false)
	syncAntiInvisible(false)
	stopVehicleFly()
	TracerHook:Remove("BulletTracers")
	TracerHook:Remove("DamageIndicator")
	TracerHook:Remove("HitSound")
	TracerHook:Remove("Viewmodel")
	if silentAimCircle then
		pcall(function()
			silentAimCircle:Remove()
		end)
		silentAimCircle = nil
	end
	if damageIndicatorPart then
		damageIndicatorPart:Destroy()
		damageIndicatorPart = nil
	end
	table.clear(cheatFlags)
	table.clear(cheatFlagged)
	table.clear(tracerDrawingObjs)
	table.clear(antiInvisibleThreads)
	for char, entry in esp do
		destroyEntry(entry)
		esp[char] = nil
	end
	for obj in pairs(c4Highlights) do
		removeC4Highlight(obj)
	end
	if c4Folder then
		c4Folder:Destroy()
	end
	table.clear(armorPickups)
	table.clear(pickupSeen)
	table.clear(toolAttrBackup)
	table.clear(spawnTimes)
	localC4 = nil
end

UILib.create({
	title = "PRISON LIFE",
	config = Config,
	pages = {
		{
			label = "Combat",
			sections = {
				{
					title = "MELEE",
					items = {
						{ type = "toggle", key = "Killaura", label = "Killaura", hud = "Killaura" },
						{ type = "slider", key = "KillauraRange", label = "Killaura Range", min = 1, max = 12, step = 1 },
					},
				},
				{
					title = "GUARD",
					items = {
						{ type = "toggle", key = "AutoArrest", label = "Auto Arrest", hud = "Auto Arrest" },
						{ type = "slider", key = "AutoArrestRange", label = "Arrest Range", min = 1, max = 8, step = 1 },
						{ type = "toggle", key = "ArrestHandCheck", label = "Handcuffs Only", hud = "Handcuffs" },
						{ type = "toggle", key = "ArrestInmates", label = "Arrest Inmates", hud = "Arrest Inmates" },
						{ type = "toggle", key = "ArrestCriminals", label = "Arrest Criminals", hud = "Arrest Criminals" },
					},
				},
				{
					title = "GUNS",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "select", key = "SilentAimMode", label = "Aim Mode", options = { "Mouse", "Position" } },
						{ type = "slider", key = "SilentAimRange", label = "Aim Range", min = 1, max = 1000, step = 5 },
						{ type = "slider", key = "SilentAimHitChance", label = "Hit Chance %", min = 0, max = 100, step = 1 },
						{ type = "slider", key = "SilentAimHeadshotChance", label = "Headshot %", min = 0, max = 100, step = 1 },
						{ type = "toggle", key = "SilentAimHead", label = "Head Priority", hud = "Head Aim" },
						{ type = "toggle", key = "SilentAimTeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "toggle", key = "SilentAimWallCheck", label = "Wall Check", hud = "Wall Check" },
						{ type = "toggle", key = "SilentAimWallbang", label = "Wallbang", hud = "Wallbang" },
						{ type = "toggle", key = "SilentAimRangeCircle", label = "Range Circle", hud = "Aim Circle" },
						{ type = "toggle", key = "GunMods", label = "Gun Mods", hud = "Gun Mods" },
						{ type = "toggle", key = "GunNoSpread", label = "No Spread", hud = "No Spread" },
						{ type = "slider", key = "GunFireRate", label = "Fire Rate %", min = 1, max = 100, step = 1 },
						{ type = "toggle", key = "GunAutomatic", label = "Full Auto", hud = "Full Auto" },
						{ type = "toggle", key = "AutoReload", label = "Auto Reload", hud = "Auto Reload" },
						{ type = "toggle", key = "AutoReloadSwap", label = "Reload Weapon Swap", hud = "Reload Swap" },
						{ type = "toggle", key = "AutoFire", label = "Auto Fire", hud = "Auto Fire" },
						{ type = "slider", key = "AutoFireRate", label = "Auto Fire Hz", min = 1, max = 120, step = 1 },
						{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Inf Ammo" },
						{ type = "hint", text = "Gun hooks need hookfunction + getconnections. Wall Check prevents shots through walls (better hit reg)." },
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
						{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed Boost" },
						{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = 26, step = 1 },
						{ type = "slider", key = "JumpPower", label = "Jump Power", min = 50, max = 55, step = 1 },
						{ type = "toggle", key = "NoJumpCooldown", label = "No Jump Cooldown", hud = "No Jump CD" },
						{ type = "toggle", key = "Noclip", label = "Noclip", hud = "Noclip" },
						{ type = "toggle", key = "AlwaysSprint", label = "Hold Sprint Speed", hud = "Sprint" },
						{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 16, max = 26, step = 1 },
						{ type = "toggle", key = "AutoReset", label = "Auto Reset (Criminal)", hud = "Auto Reset" },
						{ type = "toggle", key = "AntiTaze", label = "Anti Taze", hud = "Anti Taze" },
						{ type = "toggle", key = "Disabler", label = "Phase Fix", hud = "Phase Fix" },
						{ type = "toggle", key = "AntiKillPlane", label = "Anti Kill Plane", hud = "Kill Plane" },
						{ type = "hint", text = "Speed/jump capped near game anti-cheat limits. Noclip can still trigger kicks." },
					},
				},
				{
					title = "VEHICLE",
					items = {
						{ type = "toggle", key = "VehicleSpeed", label = "Vehicle Speed", hud = "Vehicle Speed" },
						{ type = "slider", key = "VehicleSpeedValue", label = "Max Speed", min = 80, max = 200, step = 5 },
						{ type = "toggle", key = "VehicleWallbang", label = "Shoot Through Cars", hud = "Car Wallbang" },
						{ type = "toggle", key = "VehicleFly", label = "Vehicle Fly", hud = "Vehicle Fly" },
						{ type = "select", key = "VehicleFlyMode", label = "Fly Mode", options = { "CFrame", "Part" } },
						{ type = "slider", key = "VehicleFlySpeed", label = "Fly Speed", min = 1, max = 100, step = 1 },
					},
				},
				{
					title = "UTILITY",
					items = {
						{ type = "toggle", key = "AntiInvisible", label = "Anti Invisible", hud = "Anti Invis" },
						{ type = "toggle", key = "CheatDetector", label = "Cheat Detector", hud = "Cheat Detect" },
						{ type = "toggle", key = "CameraPhase", label = "Camera Phase", hud = "Cam Phase" },
					},
				},
			},
		},
		{
			label = "Team",
			sections = {
				{
					title = "SWITCH",
					items = {
						{ type = "button", label = "Inmate", onClick = function()
							requestTeamChange("Inmates")
						end },
						{ type = "button", label = "Guard", onClick = function()
							requestTeamChange("Guards")
						end },
						{ type = "button", label = "Neutral", onClick = function()
							requestTeamChange("Neutral")
						end },
						{ type = "hint", text = "Uses Remotes.RequestTeamChange (Guards cap at 9)." },
					},
				},
			},
		},
		{
			label = "Items",
			sections = {
				{
					title = "WEAPONS",
					items = {
						{ type = "button", label = "M9", onClick = function()
							giveGiverWeapon("M9")
						end },
						{ type = "button", label = "Remington 870", onClick = function()
							giveGiverWeapon("Remington 870")
						end },
						{ type = "button", label = "AK-47", onClick = function()
							giveGiverWeapon("AK-47")
						end },
						{ type = "button", label = "Taser", onClick = function()
							giveGiverWeapon("Taser")
						end },
						{ type = "button", label = "MP5", onClick = function()
							giveGiverWeapon("MP5")
						end },
						{ type = "button", label = "FAL", onClick = function()
							giveGiverWeapon("FAL")
						end },
						{ type = "button", label = "M4A1", onClick = function()
							giveGiverWeapon("M4A1")
						end },
						{ type = "button", label = "M700", onClick = function()
							giveGiverWeapon("M700")
						end },
						{ type = "button", label = "Revolver", onClick = function()
							giveGiverWeapon("Revolver")
						end },
					},
				},
				{
					title = "AUTOMATION",
					items = {
						{ type = "toggle", key = "AutoHeal", label = "Auto Heal", hud = "Auto Heal" },
						{ type = "toggle", key = "AutoArmor", label = "Auto Armor", hud = "Auto Armor" },
						{ type = "toggle", key = "AutoPickup", label = "Auto Pickup", hud = "Auto Pickup" },
						{ type = "toggle", key = "AutoDetonate", label = "Auto Detonate C4", hud = "Auto C4" },
						{ type = "toggle", key = "AutoDetonateSafe", label = "C4 Safety Check", hud = "C4 Safe" },
						{ type = "toggle", key = "AntiRiotShield", label = "Anti Riot Shield", hud = "Anti Shield" },
						{ type = "toggle", key = "C4ESP", label = "C4 ESP", hud = "C4 ESP" },
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
						{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
						{ type = "color", key = "ESPAllyColor", label = "Ally" },
						{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
						{ type = "color", key = "ESPHostileColor", label = "Hostile Inmate" },
						{ type = "toggle", key = "FullBright", label = "Full Bright", hud = "Full Bright" },
						{ type = "toggle", key = "KillNotify", label = "Death Notify", hud = "Death Notify" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
				{
					title = "LEGIT",
					items = {
						{ type = "toggle", key = "BulletTracers", label = "Bullet Tracers", hud = "Tracers" },
						{ type = "toggle", key = "BulletTracerDrawing", label = "Drawing Tracers", hud = "Draw Tracers" },
						{ type = "slider", key = "BulletTracerLifetime", label = "Tracer Life", min = 0.05, max = 0.5, step = 0.05 },
						{ type = "toggle", key = "BulletTracerFade", label = "Tracer Fade", hud = "Tracer Fade" },
						{ type = "color", key = "BulletTracerColor", label = "Tracer Color" },
						{ type = "toggle", key = "DamageIndicator", label = "Damage Indicator", hud = "Dmg Ind" },
						{ type = "toggle", key = "HitSound", label = "Hit Sound", hud = "Hit Sound" },
						{ type = "toggle", key = "KillSound", label = "Kill Sound", hud = "Kill Sound" },
						{ type = "toggle", key = "Viewmodel", label = "Viewmodel", hud = "Viewmodel" },
						{ type = "slider", key = "ViewmodelDepth", label = "VM Depth", min = 0, max = 3, step = 0.1 },
						{ type = "slider", key = "ViewmodelHorizontal", label = "VM Horizontal", min = 0, max = 2, step = 0.1 },
						{ type = "slider", key = "ViewmodelVertical", label = "VM Vertical", min = -1.5, max = 2, step = 0.1 },
						{ type = "toggle", key = "ViewmodelSway", label = "VM Sway", hud = "VM Sway" },
						{ type = "toggle", key = "Crosshair", label = "Custom Crosshair", hud = "Crosshair" },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "SpeedBoost" or key == "NoJumpCooldown" or key == "AlwaysSprint" then
			applyMovement()
			setNoJumpCooldown(Config.NoJumpCooldown)
		end
		if
			key == "SpeedBoost"
			or key == "NoJumpCooldown"
			or key == "Noclip"
			or key == "AlwaysSprint"
			or key == "VehicleSpeed"
			or key == "Disabler"
		then
			syncMovementDisabler()
		end
		if
			key == "SilentAim"
			or key == "GunMods"
			or key == "AutoReload"
			or key == "AutoReloadSwap"
			or key == "GunNoSpread"
			or key == "GunAutomatic"
		then
			refreshGunFeatures()
		end
		if key == "C4ESP" then
			syncC4ESP()
		end
		if key == "FullBright" then
			applyFullBright()
		end
		if key == "AntiKillPlane" then
			syncKillPlane()
		end
		if key == "AntiTaze" then
			setAntiTaze(value)
		end
		if key == "VehicleWallbang" and not value then
			runVehicleWallbang()
		end
		if key == "VehicleFly" or (key == "VehicleFlyMode" and Config.VehicleFly) then
			syncVehicleFly(Config.VehicleFly)
		end
		if key == "AntiInvisible" then
			syncAntiInvisible(value)
		end
		if key == "CameraPhase" then
			syncCameraPhase(value)
		end
		if key == "BulletTracers" then
			syncBulletTracers(value)
		end
		if key == "DamageIndicator" then
			syncDamageIndicator(value)
		end
		if key == "HitSound" then
			syncHitSound(value)
		end
		if key == "Viewmodel" then
			syncViewmodel(value)
		end
		if key == "Crosshair" then
			syncCrosshair(value)
		end
		if key == "SilentAimRangeCircle" then
			syncSilentAimCircle()
		end
	end,
	onChange = function(key)
		if key == "WalkSpeed" or key == "JumpPower" then
			applyMovement()
		end
		if key == "GunFireRate" or key == "GunNoSpread" or key == "GunAutomatic" then
			modifyGunData()
		end
	end,
})

local function trackSpawn(char: Model)
	spawnTimes[char] = os.clock() + 0.5
end

local function bindSpawnTracking(player: Player)
	table.insert(connections, player.CharacterAdded:Connect(trackSpawn))
	if player.Character then
		trackSpawn(player.Character)
	end
end

for _, player in Players:GetPlayers() do
	bindSpawnTracking(player)
end
table.insert(connections, Players.PlayerAdded:Connect(bindSpawnTracking))

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(char)
	trackSpawn(char)
	table.insert(connections, char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and Config.Viewmodel then
			onViewmodelToolAdded(child)
		end
	end))
	table.insert(connections, char.ChildRemoved:Connect(function(child)
		if child == viewmodelRealTool then
			restoreViewmodel()
		end
	end))
	task.defer(function()
		headCollideConn = nil
		applyMovement()
		setNoJumpCooldown(Config.NoJumpCooldown)
		syncMovementDisabler()
		resolveGunController()
		refreshGunFeatures()
		local tool = char:FindFirstChildWhichIsA("Tool")
		if tool and Config.Viewmodel then
			onViewmodelToolAdded(tool)
		end
	end)
end))

table.insert(connections, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	if Config.AutoReset and LocalPlayer.Team == TeamCriminals then
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end
end))

for _, tag in { "Giver", "TouchGiver" } do
	table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
		registerPickup(obj, tag == "TouchGiver")
	end))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(unregisterPickup))
end
table.insert(connections, workspace.ChildAdded:Connect(function(obj)
	if obj:IsA("Model") and obj:GetAttribute("ToolName") then
		registerPickup(obj, obj.Name == "TouchGiver")
	end
end))
table.insert(connections, workspace.ChildRemoved:Connect(unregisterPickup))
refreshPickupIndex()

table.insert(connections, CollectionService:GetInstanceAddedSignal("C4"):Connect(function(obj)
	if Config.C4ESP then
		addC4Highlight(obj)
	end
	if obj:GetAttribute("UserId") == LocalPlayer.UserId then
		localC4 = obj
	end
end))
table.insert(connections, CollectionService:GetInstanceRemovedSignal("C4"):Connect(function(obj)
	removeC4Highlight(obj)
	if obj == localC4 then
		localC4 = nil
	end
end))

local killfeed = ReplicatedStorage:FindFirstChild("Killfeed")
if killfeed then
	table.insert(connections, killfeed.ChildAdded:Connect(function(obj)
		local text = obj.Name
		local killerStart = text:find("@")
		local killerEnd = text:find(")")
		local victimStart = text:find("killed ")
		local victimEnd = victimStart and text:find(" ", victimStart + 7)
		if killerStart and killerEnd and victimStart and victimEnd then
			local killer = text:sub(killerStart + 1, killerEnd - 1)
			local victim = text:sub(victimStart + 7, victimEnd - 1)
			notifyKillfeed(killer, victim)
			if Config.KillSound and killer == LocalPlayer.Name then
				playSoundId("rbxassetid://12222235", 1)
			end
		end
	end))
end

local prisonItems = workspace:FindFirstChild("Prison_ITEMS")
local clothesFolder = prisonItems and prisonItems:FindFirstChild("clothes")
if clothesFolder then
	for _, vest in clothesFolder:GetChildren() do
		table.insert(armorPickups, vest)
	end
	table.insert(connections, clothesFolder.ChildAdded:Connect(function(obj)
		table.insert(armorPickups, obj)
	end))
	table.insert(connections, clothesFolder.ChildRemoved:Connect(function(obj)
		local index = table.find(armorPickups, obj)
		if index then
			table.remove(armorPickups, index)
		end
	end))
end

local carContainer = workspace:FindFirstChild("CarContainer")
if carContainer then
	table.insert(connections, carContainer.DescendantAdded:Connect(function()
		if Config.VehicleWallbang then
			runVehicleWallbang()
		end
	end))
end

syncC4ESP()

startLoop(function()
	runKillaura()
	runAutoArrest()
	runAutoHeal()
	runAutoArmor()
	runAutoPickup()
	runAutoDetonate()
	runAntiRiotShield()
	runCheatDetector()
end)

table.insert(
	connections,
	RunService.RenderStepped:Connect(function(dt)
		table.clear(OriginScanner.Cache)
		updateOriginIgnore()
		applyMovement()
		applyNoclip()
		applyInfiniteAmmo()
		runVehicleSpeed()
		runVehicleWallbang()
		updateESP()
		syncSilentAimCircle()
		updateBulletTracerDrawings()
		runDamageIndicator()
		updateViewmodel(dt)
		if Config.AutoFire and os.clock() >= autoFireCooldown then
			autoFireCooldown = os.clock() + (1 / math.max(Config.AutoFireRate, 1))
			tryAutoFire()
		end
	end)
)

task.spawn(function()
	pcall(function()
		gamepasses = {
			["Riot Police"] = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 643697197),
			Mafia = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 1443271),
			Sniper = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 699360089),
		}
	end)
end)

pcall(function()
	for _, anim in ReplicatedStorage:GetDescendants() do
		if anim:IsA("Animation") then
			animWhitelist[anim.AnimationId] = true
		end
	end
end)

for _, player in Players:GetPlayers() do
	bindAntiInvisiblePlayer(player)
end
table.insert(connections, Players.PlayerAdded:Connect(bindAntiInvisiblePlayer))

task.defer(function()
	updateOriginIgnore()
	if not resolveGunController() then
		for _ = 1, 100 do
			task.wait(0.1)
			if resolveGunController() then
				break
			end
		end
	end
	warn("[PrisonLife] Gun resolved — Shoot:", gun.Shoot ~= nil, "Bullet:", gun.Bullet ~= nil, "Equip:", gun.Equip ~= nil, "Reload:", gun.Reload ~= nil)
	refreshGunFeatures()
	syncMovementDisabler()
	setAntiTaze(Config.AntiTaze)
	applyFullBright()
	syncKillPlane()
	syncBulletTracers(Config.BulletTracers)
	syncDamageIndicator(Config.DamageIndicator)
	syncHitSound(Config.HitSound)
	syncViewmodel(Config.Viewmodel)
	syncCrosshair(Config.Crosshair)
	syncCameraPhase(Config.CameraPhase)
	syncVehicleFly(Config.VehicleFly)
	syncSilentAimCircle()
	for _, obj in CollectionService:GetTagged("C4") do
		if obj:GetAttribute("UserId") == LocalPlayer.UserId then
			localC4 = obj
		end
	end
end)

print(
	"[MicroHub] Prison Life",
	GAME_BUILD,
	"— Drawing:",
	canDraw,
	"— Hooks:",
	canHook,
	"— Team:",
	LocalPlayer.Team and LocalPlayer.Team.Name or "?"
)

end
