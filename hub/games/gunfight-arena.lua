--[[
	Gunfight Arena — placeIds 15514727567, 14518422161
	Characters: workspace[Name]. Teams: Players child GetAttribute("Team").
	Modes: team TDM/KOTH, FFA (GUN etc.), BOSS (Skinwalker), VOTE/END lobby.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "27-sa-vortex"
warn("[GunfightArena] build", GAME_BUILD)

local Config = {
	Aimbot = false,
	AimTeamCheck = true,
	AimHold = true,
	AimSticky = false,
	AimFOV = 120,
	AimSmooth = 35,
	AimPart = "Head",
	AimFOVCircle = false,
	SilentAim = false,
	AimDebugger = false,
	ESP = true,
	ESPAllies = true,
	ESPSnaplines = true,
	ShowHUD = true,
	ESPEnemyColor = Color3.fromRGB(255, 72, 88),
	ESPAllyColor = Color3.fromRGB(72, 168, 255),
	ESPNeutralColor = Color3.fromRGB(255, 210, 96),
}

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local GREY_TEAM = BrickColor.new("Medium stone grey")

local WHITE = Color3.fromRGB(248, 250, 252)
local DIM = Color3.fromRGB(148, 156, 168)
local BAR_BG = Color3.fromRGB(10, 12, 16)
local BACKDROP = Color3.fromRGB(8, 10, 14)

local CORNER_OFFSETS = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

local esp: { [Model]: any } = {}
local wallsFolder = workspace:FindFirstChild("Walls")
local espNeedsHide = false
local aimFovSq = Config.AimFOV * Config.AimFOV
local aimFovCircle: any = nil
local stickyChar: Model? = nil
local stickyNeedsRelease = false
local combatTargetPart: BasePart? = nil

local function setAimFOV(value: number)
	Config.AimFOV = math.clamp(math.floor(value), 20, 500)
	aimFovSq = Config.AimFOV * Config.AimFOV
end

local function normTeam(value: any): any
	if value == nil then
		return nil
	end
	return tonumber(value) or value
end

local function teamsEqual(a: any, b: any): boolean
	a, b = normTeam(a), normTeam(b)
	return a ~= nil and b ~= nil and a == b
end

local function getGameMode(): string
	local info = workspace:FindFirstChild("GameInfo")
	local mode = info and info:FindFirstChild("Mode")
	return if mode and mode:IsA("StringValue") then mode.Value else ""
end

local function findPlayer(name: string): Player?
	local child = Players:FindFirstChild(name)
	if child and child:IsA("Player") then
		return child
	end
	for _, player in Players:GetPlayers() do
		if player.Name == name then
			return player
		end
	end
	return nil
end

local function getLocalTeam(): any
	local id = LocalPlayer:GetAttribute("Team")
	if id == nil then
		local record = Players:FindFirstChild(LocalPlayer.Name)
		id = record and record:GetAttribute("Team")
	end
	return if id == nil then nil else normTeam(id)
end

local function hasTeamPlay(): boolean
	if getLocalTeam() == nil or LocalPlayer.TeamColor == GREY_TEAM then
		return false
	end
	local mode = getGameMode()
	return mode ~= "VOTE" and mode ~= "END"
end

local function teamColor(rel: string): Color3
	if rel == "Enemy" then
		return Config.ESPEnemyColor
	end
	if rel == "Ally" then
		return Config.ESPAllyColor
	end
	return Config.ESPNeutralColor
end

local function getTeamFor(name: string, char: Model?): any
	local record = Players:FindFirstChild(name)
	if record then
		local id = record:GetAttribute("Team")
		if id ~= nil then
			return normTeam(id)
		end
	end
	local player = findPlayer(name)
	if player then
		local id = player:GetAttribute("Team")
		if id ~= nil then
			return normTeam(id)
		end
	end
	return if char then normTeam(char:GetAttribute("Team")) else nil
end

local function relation(name: string, char: Model?): string
	if name == LocalPlayer.Name then
		return "Ally"
	end
	if name == "Skinwalker" then
		return "Enemy"
	end
	if not hasTeamPlay() then
		return "Enemy"
	end
	local pt = getTeamFor(name, char)
	if pt == nil then
		return "Enemy"
	end
	return if teamsEqual(getLocalTeam(), pt) then "Ally" else "Enemy"
end

local function displayName(name: string): string
	local player = findPlayer(name)
	return if player then player.DisplayName else name
end

local function isAllySpawnShielded(name: string): boolean
	if not hasTeamPlay() or not teamsEqual(getLocalTeam(), getTeamFor(name)) then
		return false
	end
	if not wallsFolder or not wallsFolder.Parent then
		wallsFolder = workspace:FindFirstChild("Walls")
	end
	return wallsFolder ~= nil and wallsFolder:FindFirstChild(name .. "Forcefield") ~= nil
end

local function isCombatModel(model: Instance?): (boolean, Humanoid?, BasePart?)
	if not model or not model:IsA("Model") or model == LocalPlayer.Character or model.Name == "ViewModel" then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return false
	end
	return true, hum, root
end

local function isKnownCombatant(name: string): boolean
	if name == "Skinwalker" then
		return getGameMode() == "BOSS"
	end
	if name == LocalPlayer.Name then
		return false
	end
	return Players:FindFirstChild(name) ~= nil or findPlayer(name) ~= nil
end

-- Mirror Network.GetSpawned without require() — anti-tamper kicks foreign callers.
local function getSpawned(): { [string]: Model }
	local spawned = {}
	for _, record in Players:GetChildren() do
		if record.Name == LocalPlayer.Name then
			continue
		end
		local char = workspace:FindFirstChild(record.Name)
		if not char or not char:IsA("Model") then
			continue
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			spawned[record.Name] = char
		end
	end
	return spawned
end

local function collectTargets(): { [Model]: string }
	local targets: { [Model]: string } = {}

	local function add(name: string?, char: Instance?)
		if not name or name == LocalPlayer.Name or not char or not char:IsA("Model") or targets[char] then
			return
		end
		if name == "Skinwalker" or isKnownCombatant(name) then
			targets[char] = name
		end
	end

	for name, char in getSpawned() do
		add(name, char)
	end
	for _, record in Players:GetChildren() do
		add(record.Name, workspace:FindFirstChild(record.Name))
	end
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			add(player.Name, workspace:FindFirstChild(player.Name))
			add(player.Name, player.Character)
		end
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and isKnownCombatant(child.Name) then
			add(child.Name, child)
		end
	end
	if getGameMode() == "BOSS" then
		add("Skinwalker", workspace:FindFirstChild("Skinwalker"))
	end

	return targets
end

local function hpColor(ratio: number): Color3
	if ratio > 0.55 then
		return Color3.fromRGB(72, 214, 128)
	end
	if ratio > 0.25 then
		return Color3.fromRGB(255, 196, 72)
	end
	return Color3.fromRGB(255, 86, 92)
end

local function formatDistance(studs: number): string
	if studs >= 1000 then
		return string.format("%.1fkm", studs / 1000)
	end
	return string.format("%dm", math.floor(studs))
end

-- Aimbot

local function aimPart(char: Model): BasePart?
	local part = char:FindFirstChild(Config.AimPart)
	if part and part:IsA("BasePart") then
		return part
	end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function aimOrigin(): Vector2
	if UserInputService.MouseEnabled then
		return UserInputService:GetMouseLocation()
	end
	return Camera.ViewportSize * 0.5
end

local function isThirdPerson(): boolean
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local vortex = playerScripts and playerScripts:FindFirstChild("Vortex")
	local modifiers = vortex and vortex:FindFirstChild("Modifiers")
	local flag = modifiers and modifiers:FindFirstChild("IsThirdPerson")
	if flag and flag:IsA("BoolValue") then
		return flag.Value
	end
	local api = rawget(_G, "GlobalAPI")
	local mode = api and typeof(api.Settings) == "table" and api.Settings.CameraMode
	if mode ~= nil then
		return mode ~= 1
	end
	return LocalPlayer.CameraMinZoomDistance > 1
end

local function setMouseHit(position: Vector3)
	_G.MouseHitSpot = position
	if typeof(getgenv) == "function" then
		local env = getgenv()
		if typeof(env) == "table" then
			env.MouseHitSpot = position
		end
	end
end

local function screenDistSq(worldPos: Vector3, origin: Vector2): number?
	local screen, onScreen = Camera:WorldToViewportPoint(worldPos)
	if not onScreen or screen.Z <= 0 then
		return nil
	end
	local dx, dy = screen.X - origin.X, screen.Y - origin.Y
	return dx * dx + dy * dy
end

local function isAimEligible(char: Model, name: string): boolean
	if not isCombatModel(char) or isAllySpawnShielded(name) then
		return false
	end
	if Config.AimTeamCheck and relation(name, char) == "Ally" then
		return false
	end
	return true
end

local function targetName(char: Model): string
	for model, name in collectTargets() do
		if model == char then
			return name
		end
	end
	return char.Name
end

local function charFromPart(part: BasePart): Model?
	local model = part.Parent
	return if model and model:IsA("Model") then model else nil
end

local function closestAimPart(origin: Vector2): BasePart?
	local bestPart: BasePart? = nil
	local bestDistSq = aimFovSq

	for char, name in collectTargets() do
		if not isAimEligible(char, name) then
			continue
		end
		local part = aimPart(char)
		local distSq = part and screenDistSq(part.Position, origin)
		if distSq and distSq < bestDistSq then
			bestPart, bestDistSq = part, distSq
		end
	end

	return bestPart
end

local function stickyAimPart(): BasePart?
	if not stickyChar or not stickyChar.Parent then
		return nil
	end
	if not isAimEligible(stickyChar, targetName(stickyChar)) then
		return nil
	end
	return aimPart(stickyChar)
end

local function aimAlpha(dt: number): number
	local smooth = math.clamp(Config.AimSmooth, 1, 100)
	if smooth <= 1 then
		return 1
	end
	local t = (smooth - 1) / 99
	return 1 - math.exp(-(72 * (1 - t) ^ 1.45 + 1.8) * dt)
end

local function combatHoldActive(): boolean
	return not Config.AimHold or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local function combatAimWanted(): boolean
	return Config.Aimbot or Config.SilentAim
end

local function resolveAimTarget(origin: Vector2): BasePart?
	if not combatHoldActive() then
		stickyChar = nil
		stickyNeedsRelease = false
		return nil
	end

	local part: BasePart? = nil

	if Config.AimSticky then
		if stickyNeedsRelease then
			return nil
		end
		part = stickyAimPart()
		if not part then
			stickyChar = nil
			part = closestAimPart(origin)
			if part then
				stickyChar = charFromPart(part)
			else
				stickyNeedsRelease = true
				return nil
			end
		end
	else
		stickyChar = nil
		stickyNeedsRelease = false
		part = closestAimPart(origin)
	end

	if not part or not part.Parent then
		return nil
	end
	return part
end

local function updateCombatAim(dt: number)
	local origin = aimOrigin()

	if aimFovCircle then
		aimFovCircle.Position = origin
		aimFovCircle.Radius = Config.AimFOV
		aimFovCircle.Visible = Config.Aimbot and Config.AimFOVCircle
	end

	combatTargetPart = nil
	if combatAimWanted() and combatHoldActive() then
		combatTargetPart = resolveAimTarget(origin)
	elseif not combatAimWanted() then
		stickyChar = nil
		stickyNeedsRelease = false
	end

	if Config.SilentAim and combatTargetPart then
		setMouseHit(combatTargetPart.Position)
		if
			not Config.Aimbot
			and not isThirdPerson()
			and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, combatTargetPart.Position)
		end
	end

	if not Config.Aimbot or not combatHoldActive() or not combatTargetPart then
		return
	end

	local targetPos = combatTargetPart.Position
	local alpha = aimAlpha(dt)

	if isThirdPerson() then
		local current = _G.MouseHitSpot
		setMouseHit(if typeof(current) == "Vector3" then current:Lerp(targetPos, alpha) else targetPos)
	else
		setMouseHit(targetPos)
		Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), alpha)
	end
end

-- Silent aim debugger (Vortex INVK → Network.FireServer → RemoteEvent)

local DBG_CONSOLE_INTERVAL = 4
local DBG_LINE_COUNT = 14
local DBG_HOOK_RETRY = 3
local DBG_HOOK_MAX_ATTEMPTS = 12
local DBG_GC_SCAN_INTERVAL = 6
local DBG_OVERLAY_INTERVAL = 0.12
local DBG_SYNC_SCAN_INTERVAL = 1
local DBG_FLAME_CACHE_INTERVAL = 0.5

type DbgShot = {
	at: number,
	weapon: string?,
	clock: number?,
	serverCf: CFrame?,
	suppressed: boolean?,
	ads: boolean?,
}

type DbgHit = {
	at: number,
	a: any,
	b: any,
	c: any,
	d: any,
}

local dbg = {
	netCount = 0,
	fireCount = 0,
	hitCount = 0,
	syncCount = 0,
	lastFire = nil :: DbgShot?,
	lastHitcheck = nil :: DbgHit?,
	lastSyncCf = nil :: CFrame?,
	lastSyncWeapon = nil :: string?,
	logCooldowns = {} :: { [string]: number },
	hooksReady = false,
	networkHooked = false,
	remotePath = "",
	syncPath = "",
	syncBound = 0,
	lastEvent = "",
	status = "idle",
}

local dbgTexts: { any } = {}
local DBG_SESSION_KEY = "__MicroHubGFA_Dbg"
local DBG_HOOK_BUILD = "27-sa-vortex"
local dbgNetworkHooked = false
local dbgInitPrinted = false
local dbgCapsPrinted = false
local dbgHookWorkerActive = false
local combatHookGiveUp = false
local combatHookInstallStarted = false
local combatNetworkFireOriginal: ((...any) -> ...any)? = nil
local vortexSyncHooked = false
local vortexSyncOriginal: ((...any) -> ...any)? = nil
local saHookAnnounced = false
local saLastSyncCf: CFrame? = nil

local sa = {
	vortexSync = false,
	lastFireAt = 0,
	lastSyncAt = 0,
}

local function dbgVolt(name: string): any
	if typeof(getgenv) == "function" then
		local value = getgenv()[name]
		if value ~= nil then
			return value
		end
	end
	return rawget(_G, name)
end

local voltHookfunction = dbgVolt("hookfunction")
local voltNewcclosure = dbgVolt("newcclosure")
local voltGetgc = dbgVolt("getgc")
local voltFiltergc = dbgVolt("filtergc")
local voltCheckcaller = dbgVolt("checkcaller")
local dbgSyncConns: { [Instance]: RBXScriptConnection } = {}
local dbgNextOverlayAt = 0
local dbgNextSyncScan = 0
local dbgNextFlameScan = 0
local dbgCachedFlame: BasePart? = nil
local dbgCachedCombatRemote: RemoteEvent? = nil
local dbgGcCachedApi: any = nil
local dbgGcCachedRemote: RemoteEvent? = nil
local dbgGcCachedFireFn: ((...any) -> ...any)? = nil
local dbgNextGcScan = 0
local dbgSeenClockOffset = false

local function dbgShortCf(cf: any): string
	if typeof(cf) ~= "CFrame" then
		return "—"
	end
	local p, l = cf.Position, cf.LookVector
	return string.format(
		"p(%.0f,%.0f,%.0f) lv(%.2f,%.2f,%.2f)",
		p.X,
		p.Y,
		p.Z,
		l.X,
		l.Y,
		l.Z
	)
end

local function dbgShortVal(value: any): string
	local t = typeof(value)
	if t == "string" then
		if #value > 28 then
			return string.sub(value, 1, 25) .. "..."
		end
		return value
	end
	if t == "number" then
		return string.format("%.3f", value)
	end
	if t == "boolean" then
		return if value then "true" else "false"
	end
	if t == "CFrame" then
		return dbgShortCf(value)
	end
	if t == "Instance" then
		return value.Name
	end
	return t
end

local function dbgLog(key: string, message: string, cooldown: number?)
	if not Config.AimDebugger then
		return
	end
	cooldown = cooldown or DBG_CONSOLE_INTERVAL
	local now = os.clock()
	if cooldown > 0 and now - (dbg.logCooldowns[key] or 0) < cooldown then
		return
	end
	dbg.logCooldowns[key] = now
	print("[GFA-DBG]", key, message)
end

local function dbgMaybeDecode(value: any): any
	if typeof(value) ~= "string" or string.sub(value, 1, 1) ~= "~" then
		return value
	end
	local codecModule = game:GetService("ReplicatedStorage"):FindFirstChild("DataCodec")
	if not codecModule then
		return value
	end
	local ok, codec = pcall(require, codecModule)
	if not ok or typeof(codec) ~= "table" or typeof(codec.AutoDecode) ~= "function" then
		return value
	end
	local okDecode, decoded = pcall(codec.AutoDecode, value)
	return if okDecode then decoded else value
end

local function dbgRecordNetworkEvent(eventName: any, payload: { any })
	if typeof(eventName) ~= "string" then
		return
	end
	if eventName ~= "Fire" and eventName ~= "Hitcheck" then
		return
	end
	if eventName == "Fire" and dbg.lastFire then
		if os.clock() - dbg.lastFire.at < 0.02 then
			return
		end
	end

	dbg.netCount += 1
	dbg.lastEvent = eventName

	if eventName == "Fire" then
		dbg.fireCount += 1
		local weapon = dbgMaybeDecode(payload[1])
		local clock = dbgMaybeDecode(payload[2])
		local serverCf = dbgMaybeDecode(payload[3])
		dbg.lastFire = {
			at = os.clock(),
			weapon = dbgShortVal(weapon),
			clock = if typeof(clock) == "number" then clock else nil,
			serverCf = if typeof(serverCf) == "CFrame" then serverCf else nil,
			suppressed = if typeof(dbgMaybeDecode(payload[4])) == "boolean" then dbgMaybeDecode(payload[4]) else nil,
			ads = if typeof(dbgMaybeDecode(payload[5])) == "boolean" then dbgMaybeDecode(payload[5]) else nil,
		}
		dbgLog("Fire", string.format("Fire #%d %s %s", dbg.fireCount, dbg.lastFire.weapon, dbgShortCf(dbg.lastFire.serverCf)), 2)
	elseif eventName == "Hitcheck" then
		dbg.hitCount += 1
		dbg.lastHitcheck = {
			at = os.clock(),
			a = dbgMaybeDecode(payload[1]),
			b = dbgMaybeDecode(payload[2]),
			c = dbgMaybeDecode(payload[3]),
			d = dbgMaybeDecode(payload[4]),
		}
		dbgLog(
			"Hitcheck",
			string.format(
				"#%d %s | %s | %s | %s",
				dbg.hitCount,
				dbgShortVal(dbg.lastHitcheck.a),
				dbgShortVal(dbg.lastHitcheck.b),
				dbgShortVal(dbg.lastHitcheck.c),
				dbgShortVal(dbg.lastHitcheck.d)
			),
			2
		)
	end
end

local function dbgSession(): { [string]: any }?
	if typeof(getgenv) ~= "function" then
		return nil
	end
	local env = getgenv()
	local session = env[DBG_SESSION_KEY]
	if typeof(session) ~= "table" or session.build ~= DBG_HOOK_BUILD then
		session = { build = DBG_HOOK_BUILD }
		env[DBG_SESSION_KEY] = session
	end
	return session
end

local function dbgWrapHook(fn: (...any) -> ...any): (...any) -> ...any
	if typeof(voltNewcclosure) == "function" then
		return voltNewcclosure(fn)
	end
	return fn
end

local function dbgFromGame(): boolean
	return typeof(voltCheckcaller) ~= "function" or not voltCheckcaller()
end

local function dbgHooksActive(): boolean
	return dbg.networkHooked
end

local function combatHooksWanted(): boolean
	return Config.SilentAim or Config.AimDebugger
end

local function dbgTblGet(tbl: any, key: string): any
	if typeof(tbl) ~= "table" then
		return nil
	end
	local value = rawget(tbl, key)
	if value ~= nil then
		return value
	end
	local ok, indexed = pcall(function()
		return tbl[key]
	end)
	if ok then
		return indexed
	end
	return nil
end

local function dbgNetworkReady(): boolean
	return LocalPlayer:GetAttribute("ClockOffset") ~= nil
end

local function dbgIsCombatRemote(remote: RemoteEvent): boolean
	if remote:GetFullName():find(LocalPlayer.Name, 1, true) then
		return true
	end
	if remote:IsDescendantOf(LocalPlayer) then
		return true
	end
	local record = Players:FindFirstChild(LocalPlayer.Name)
	if record and remote:IsDescendantOf(record) then
		return true
	end
	return remote:FindFirstAncestorWhichIsA("Player") == LocalPlayer
end

local function dbgIsBadRemote(remote: RemoteEvent): boolean
	return not dbgIsCombatRemote(remote)
end

local function dbgIsNetworkApi(tbl: any): boolean
	if typeof(tbl) ~= "table" then
		return false
	end
	if typeof(dbgTblGet(tbl, "FireServer")) ~= "function" then
		return false
	end
	if typeof(dbgTblGet(tbl, "OnEvent")) ~= "function" then
		return false
	end
	if typeof(dbgTblGet(tbl, "EncodeData")) ~= "function" then
		return false
	end
	if typeof(dbgTblGet(tbl, "DecodeData")) ~= "function" then
		return false
	end
	local re = dbgTblGet(tbl, "RE")
	return typeof(re) == "Instance" and re:IsA("RemoteEvent") and dbgIsCombatRemote(re)
end

local function dbgAcceptCombatRemote(remote: Instance?): RemoteEvent?
	if remote and remote:IsA("RemoteEvent") and not dbgIsBadRemote(remote) then
		dbgCachedCombatRemote = remote
		return remote
	end
	return nil
end

local function dbgCombatRemote(): RemoteEvent?
	if dbgCachedCombatRemote and dbgCachedCombatRemote.Parent then
		return dbgCachedCombatRemote
	end

	local direct = LocalPlayer:FindFirstChild("RemoteEvent")
	if dbgAcceptCombatRemote(direct) then
		return direct
	end

	for _, desc in LocalPlayer:GetDescendants() do
		if desc.Name == "RemoteEvent" and desc:IsA("RemoteEvent") then
			return dbgAcceptCombatRemote(desc)
		end
	end

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if playerScripts then
		for _, desc in playerScripts:GetDescendants() do
			if desc.Name == "RemoteEvent" and desc:IsA("RemoteEvent") then
				return dbgAcceptCombatRemote(desc)
			end
		end
	end

	local record = Players:FindFirstChild(LocalPlayer.Name)
	if record then
		local nested = record:FindFirstChild("RemoteEvent", true)
		if dbgAcceptCombatRemote(nested) then
			return nested
		end
	end

	return dbgCachedCombatRemote
end

local function dbgPrintCaps()
	if dbgCapsPrinted or not Config.AimDebugger then
		return
	end
	dbgCapsPrinted = true
	local remote = dbgCombatRemote()
	print(
		"[GFA-DBG] caps",
		"hookfunction:",
		typeof(voltHookfunction),
		"filtergc:",
		typeof(voltFiltergc),
		"getgc:",
		typeof(voltGetgc),
		"remote:",
		if remote then remote:GetFullName() else "nil"
	)
end

local function dbgRemoteScore(remote: RemoteEvent): number
	if dbgIsBadRemote(remote) then
		return 0
	end
	if remote:GetFullName():find(LocalPlayer.Name, 1, true) then
		return 100
	end
	if remote:IsDescendantOf(LocalPlayer) then
		return 100
	end
	local playerAncestor = remote:FindFirstAncestorWhichIsA("Player")
	if playerAncestor == LocalPlayer then
		return 100
	end
	local record = Players:FindFirstChild(LocalPlayer.Name)
	if record and remote:IsDescendantOf(record) then
		return 100
	end
	return 0
end

local function dbgScanNetworkTables(callback: (any, RemoteEvent) -> boolean)
	local bestApi: any = nil
	local bestRemote: RemoteEvent? = nil
	local bestScore = 0
	local candidateCount = 0

	local function consider(tbl: any): boolean
		if not dbgIsNetworkApi(tbl) then
			return false
		end
		local remote = dbgTblGet(tbl, "RE")
		if typeof(remote) ~= "Instance" or not remote:IsA("RemoteEvent") then
			return false
		end
		local score = dbgRemoteScore(remote)
		if score <= 0 then
			return false
		end
		candidateCount += 1
		if score > bestScore then
			bestApi, bestRemote, bestScore = tbl, remote, score
		end
		return false
	end

	if typeof(voltFiltergc) == "function" then
		local ok, tables = pcall(voltFiltergc, "table", {
			Keys = { "FireServer", "RE" },
		})
		if ok and typeof(tables) == "table" then
			for _, tbl in tables do
				if consider(tbl) then
					return
				end
			end
		end
		ok, tables = pcall(voltFiltergc, "table", {
			Keys = { "FireServer", "OnEvent", "EncodeData", "DecodeData", "RE" },
		})
		if ok and typeof(tables) == "table" then
			for _, tbl in tables do
				if consider(tbl) then
					return
				end
			end
		end
	end

	if typeof(voltGetgc) == "function" then
		local ok, objects = pcall(voltGetgc, true)
		if ok and typeof(objects) == "table" then
			for _, obj in objects do
				if consider(obj) then
					return
				end
			end
		end
	end

	if bestApi and bestRemote and bestScore >= 90 then
		if bestRemote then
			dbgAcceptCombatRemote(bestRemote)
		end
		callback(bestApi, bestRemote)
	end
end

local function dbgFindFireServerFunction(): ((...any) -> ...any)?
	if dbgGcCachedFireFn then
		return dbgGcCachedFireFn
	end
	if typeof(voltFiltergc) ~= "function" then
		return nil
	end
	local queries = {
		{ Constants = { "Client is disconnected from the network" } },
		{ Constants = { "disconnected from the network" } },
	}
	for _, query in queries do
		local opts: { [string]: any } = { IgnoreExecutor = true }
		for key, value in query do
			opts[key] = value
		end
		local ok, fns = pcall(voltFiltergc, "function", opts)
		if ok and typeof(fns) == "table" then
			for _, fn in fns do
				if typeof(fn) == "function" then
					dbgGcCachedFireFn = fn
					return fn
				end
			end
		end
	end
	return nil
end

local function dbgFindNetworkApi(): (any, RemoteEvent?)
	if dbgGcCachedApi and (dbgGcCachedRemote == nil or dbgGcCachedRemote.Parent) then
		return dbgGcCachedApi, dbgGcCachedRemote
	end

	if dbgNetworkReady() and not dbgSeenClockOffset then
		dbgSeenClockOffset = true
		dbgNextGcScan = 0
	end

	local now = os.clock()
	if now < dbgNextGcScan then
		return nil, nil
	end
	dbgNextGcScan = now + DBG_GC_SCAN_INTERVAL

	local fireFn = dbgFindFireServerFunction()

	local foundApi: any = nil
	local foundRemote: RemoteEvent? = nil
	dbgScanNetworkTables(function(api, remote)
		foundApi, foundRemote = api, remote
		return true
	end)
	if foundApi and foundRemote then
		local tableFn = dbgTblGet(foundApi, "FireServer")
		if typeof(tableFn) == "function" then
			dbgGcCachedApi = foundApi
			dbgGcCachedRemote = foundRemote
			if fireFn then
				dbgGcCachedFireFn = fireFn
			end
			return foundApi, foundRemote
		end
	end

	if fireFn then
		dbgGcCachedApi = { FireServer = fireFn }
		dbgGcCachedFireFn = fireFn
		return dbgGcCachedApi, dbgGcCachedRemote
	end
	return nil, nil
end

local function dbgMaybeBindRemote(self: any)
	if typeof(self) ~= "table" then
		return
	end
	local re = dbgTblGet(self, "RE")
	if typeof(re) == "Instance" and re:IsA("RemoteEvent") and dbgIsCombatRemote(re) then
		dbgAcceptCombatRemote(re)
		dbg.remotePath = re:GetFullName()
	end
end

local function dbgPrintInit(label: string, path: string)
	if dbgInitPrinted then
		return
	end
	dbgInitPrinted = true
	print("[GFA-DBG] init", label, "@", path)
end

local function dbgViewModelFlame(): BasePart?
	if dbgCachedFlame and dbgCachedFlame.Parent then
		return dbgCachedFlame
	end

	local now = os.clock()
	if now < dbgNextFlameScan then
		return dbgCachedFlame
	end
	dbgNextFlameScan = now + DBG_FLAME_CACHE_INTERVAL

	local vm = workspace:FindFirstChild("ViewModel")
	if not vm or not vm:IsA("Model") then
		dbgCachedFlame = nil
		return nil
	end

	for _, desc in vm:GetDescendants() do
		if desc.Name == "Flame" and desc:IsA("BasePart") then
			dbgCachedFlame = desc
			return desc
		end
	end

	dbgCachedFlame = nil
	return nil
end

local function saMaybeEncode(sample: any, value: any): any
	if typeof(sample) ~= "string" or string.sub(sample, 1, 1) ~= "~" then
		return value
	end
	local api = dbgGcCachedApi
	if typeof(api) ~= "table" then
		return value
	end
	local encode = dbgTblGet(api, "EncodeData")
	if typeof(encode) ~= "function" then
		return value
	end
	local ok, encoded = pcall(function()
		return encode(api, value)
	end)
	if not ok then
		ok, encoded = pcall(encode, value)
	end
	return if ok then encoded else value
end

local function saTargetModel(part: BasePart): Model?
	local model = part.Parent
	return if model and model:IsA("Model") then model else nil
end

local function saInjectHitables(hitables: any, part: BasePart): any
	local model = saTargetModel(part)
	if not model or typeof(hitables) ~= "table" then
		return hitables
	end
	for _, entry in hitables do
		if entry == model then
			return hitables
		end
	end
	table.insert(hitables, model)
	return hitables
end

local function saRewriteFirePayload(payload: { any }): { any }
	if not Config.SilentAim or not combatHoldActive() then
		return payload
	end
	local part = resolveAimTarget(aimOrigin())
	if not part then
		return payload
	end
	setMouseHit(part.Position)
	local rawCf = payload[3]
	local serverCf = dbgMaybeDecode(rawCf)
	if typeof(serverCf) ~= "CFrame" then
		return payload
	end
	local flame = dbgViewModelFlame()
	local origin = if flame then flame.Position else serverCf.Position
	local newCf = CFrame.new(origin, part.Position)
	payload[3] = saMaybeEncode(rawCf, newCf)
	sa.lastFireAt = os.clock()
	return payload
end

local function saRewriteSyncShot(shotCf: CFrame, hitables: any): (CFrame, any)
	local part = resolveAimTarget(aimOrigin())
	if not part or not Config.SilentAim or not combatHoldActive() then
		return shotCf, hitables
	end
	setMouseHit(part.Position)
	local newCf = CFrame.new(shotCf.Position, part.Position)
	saLastSyncCf = newCf
	sa.lastSyncAt = os.clock()
	return newCf, saInjectHitables(hitables, part)
end

local function combatHookVortexSync()
	if vortexSyncHooked or not Config.SilentAim or typeof(voltHookfunction) ~= "function" then
		return
	end

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local vortex = playerScripts and playerScripts:FindFirstChild("Vortex")
	local sync = vortex and vortex:FindFirstChild("Sync")
	if not sync or not sync:IsA("BindableEvent") then
		return
	end

	local fireMethod = sync.Fire
	if typeof(fireMethod) ~= "function" then
		return
	end

	local ok = pcall(function()
		vortexSyncOriginal = voltHookfunction(fireMethod, dbgWrapHook(function(self, a1, a2, a3, a4, a5, a6, a7, a8)
			if dbgFromGame() and Config.SilentAim and a1 == LocalPlayer and typeof(a4) == "CFrame" then
				a4, a7 = saRewriteSyncShot(a4, a7)
			end
			local original = vortexSyncOriginal
			if typeof(original) ~= "function" then
				return
			end
			return original(self, a1, a2, a3, a4, a5, a6, a7, a8)
		end))
	end)
	if ok and typeof(vortexSyncOriginal) == "function" then
		vortexSyncHooked = true
		sa.vortexSync = true
	end
end

local function saAnnounceHooks()
	if saHookAnnounced or not Config.SilentAim or not dbg.networkHooked then
		return
	end
	saHookAnnounced = true
	print(
		"[GFA] silent aim ready",
		if dbg.remotePath ~= "" then dbg.remotePath else "Network.FireServer",
		if sa.vortexSync then "| Vortex.Sync" else "| sync:off"
	)
end

local function dbgHookNetworkApi()
	if dbgNetworkHooked then
		return
	end

	if not dbgNetworkReady() then
		dbg.status = "waiting for ClockOffset"
		return
	end

	local api, remote = dbgFindNetworkApi()
	local target = if api then dbgTblGet(api, "FireServer") else nil
	if not target then
		return
	end
	if remote then
		if dbgIsBadRemote(remote) then
			return
		end
		dbgAcceptCombatRemote(remote)
		dbg.remotePath = remote:GetFullName()
	elseif dbg.remotePath == "" then
		dbg.remotePath = "Network.FireServer (gc fn)"
	end
	if typeof(voltHookfunction) ~= "function" then
		return
	end

	local ok = pcall(function()
		combatNetworkFireOriginal = voltHookfunction(target, dbgWrapHook(function(self, eventName, ...)
			local args = { ... }
			if dbgFromGame() then
				if Config.SilentAim and eventName == "Fire" then
					args = saRewriteFirePayload(args)
				end
				if Config.AimDebugger then
					dbgMaybeBindRemote(self)
					dbgRecordNetworkEvent(eventName, args)
				end
			end
			local fire = combatNetworkFireOriginal
			if typeof(fire) ~= "function" then
				return
			end
			return fire(self, eventName, table.unpack(args))
		end))
	end)
	if not ok or typeof(combatNetworkFireOriginal) ~= "function" then
		combatNetworkFireOriginal = nil
		return
	end
	local session = dbgSession()
	if session then
		session.networkFireFn = target
		session.hookReady = true
	end

	dbgNetworkHooked = true
	dbg.networkHooked = true
	dbg.hooksReady = true
	dbg.status = "Network.FireServer hooked"
	combatHookVortexSync()
	saAnnounceHooks()
	if Config.AimDebugger then
		dbgPrintInit("Network.FireServer hooked", dbg.remotePath)
	end
end

local function combatEnsureHooks()
	if not combatHooksWanted() or dbgHooksActive() or combatHookGiveUp or combatHookInstallStarted then
		return
	end
	combatHookInstallStarted = true
	if Config.AimDebugger then
		dbgPrintCaps()
	end
	dbgHookWorkerActive = true
	task.spawn(function()
		local attempts = 0
		while combatHooksWanted() and not dbgHooksActive() and attempts < DBG_HOOK_MAX_ATTEMPTS do
			attempts += 1
			dbgHookNetworkApi()
			if dbgHooksActive() then
				break
			end
			if typeof(voltHookfunction) ~= "function" then
				dbg.status = "hookfunction missing (Volt genv?)"
			elseif not dbgNetworkReady() then
				dbg.status = "waiting for ClockOffset"
			else
				dbg.status = "waiting for Network API (gc)"
			end
			if attempts == 5 and not dbgHooksActive() then
				dbgLog("init-fail", dbg.status, 0)
			end
			task.wait(DBG_HOOK_RETRY)
		end
		if not dbgHooksActive() then
			combatHookGiveUp = true
			dbg.status = "hook install failed (rejoin)"
			if Config.SilentAim or Config.AimDebugger then
				warn("[GFA] combat hook failed after", attempts, "tries:", dbg.status)
			end
		end
		dbgHookWorkerActive = false
		combatHookInstallStarted = false
	end)
end

local function dbgOnSyncFire(args: { any })
	if not Config.AimDebugger then
		return
	end
	local shooter = args[1]
	if shooter ~= LocalPlayer then
		return
	end
	local shotCf = args[4]
	if typeof(shotCf) ~= "CFrame" then
		return
	end
	dbg.syncCount += 1
	dbg.lastSyncCf = shotCf
	dbg.lastSyncWeapon = dbgShortVal(args[6] or args[3])
	dbgLog("Sync", string.format("#%d %s %s", dbg.syncCount, dbg.lastSyncWeapon, dbgShortCf(shotCf)), 2)
end

local function dbgHookSync()
	if not Config.AimDebugger then
		return
	end

	local now = os.clock()
	if now < dbgNextSyncScan then
		return
	end
	dbgNextSyncScan = now + DBG_SYNC_SCAN_INTERVAL

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return
	end

	for _, desc in playerScripts:GetDescendants() do
		if desc.Name == "Sync" and desc:IsA("BindableEvent") and not dbgSyncConns[desc] then
			dbgSyncConns[desc] = desc.Event:Connect(function(...)
				dbgOnSyncFire({ ... })
			end)
			dbg.syncBound += 1
			local path = desc:GetFullName()
			dbg.syncPath = if dbg.syncPath == "" then path else dbg.syncPath .. " | " .. path
		end
	end
end

local function dbgAngleTo(origin: Vector3, look: Vector3, target: Vector3): number
	local dir = target - origin
	if dir.Magnitude < 0.01 then
		return 0
	end
	return math.deg(math.acos(math.clamp(look.Unit:Dot(dir.Unit), -1, 1)))
end

local function dbgEnsureOverlay()
	if not canDraw or #dbgTexts > 0 then
		return
	end
	for i = 1, DBG_LINE_COUNT do
		local line = Drawing.new("Text")
		line.Size = 13
		line.Outline = true
		line.Center = false
		line.Visible = false
		line.Position = Vector2.new(12, 8 + (i - 1) * 15)
		dbgTexts[i] = line
	end
end

local function dbgSetLine(index: number, text: string, visible: boolean)
	local line = dbgTexts[index]
	if not line then
		return
	end
	line.Text = text
	line.Visible = visible and Config.AimDebugger
end

local function dbgHideOverlay()
	for _, line in dbgTexts do
		line.Visible = false
	end
end

local SA_STATUS_LINES = 6

local function saHideStatus()
	for i = 1, SA_STATUS_LINES do
		local line = dbgTexts[i]
		if line then
			line.Visible = false
		end
	end
end

local function saUpdateStatus()
	if not Config.SilentAim or Config.AimDebugger or not canDraw then
		return
	end
	dbgEnsureOverlay()
	local now = os.clock()
	if now < dbgNextOverlayAt then
		return
	end
	dbgNextOverlayAt = now + DBG_OVERLAY_INTERVAL

	local origin = aimOrigin()
	local part = combatTargetPart or closestAimPart(origin)
	local targetNameStr = if part and part.Parent then part.Parent.Name else "—"
	local syncToTarget = if part and saLastSyncCf
		then dbgAngleTo(saLastSyncCf.Position, saLastSyncCf.LookVector, part.Position)
		else nil
	local fireAge = if sa.lastFireAt > 0 then string.format("%.1fs", now - sa.lastFireAt) else "—"
	local syncAge = if sa.lastSyncAt > 0 then string.format("%.1fs", now - sa.lastSyncAt) else "—"

	local lines = {
		"── Silent Aim ──",
		string.format(
			"Hooks: net:%s vortex:%s | %s",
			if dbg.networkHooked then "OK" else "—",
			if sa.vortexSync then "OK" else "—",
			dbg.status
		),
		string.format("Target: %s | hold RMB + shoot", targetNameStr),
		string.format("Last redirect  fire:%s  sync:%s", fireAge, syncAge),
		string.format("Sync angle° to target: %s", if syncToTarget then string.format("%.1f", syncToTarget) else "—"),
		"Enable Debugger below to compare Fire/Sync/Hitcheck",
	}

	for i = 1, SA_STATUS_LINES do
		local line = dbgTexts[i]
		if line then
			line.Text = lines[i] or ""
			line.Visible = lines[i] ~= nil
		end
	end
	for i = SA_STATUS_LINES + 1, #dbgTexts do
		dbgTexts[i].Visible = false
	end
end

local function dbgUpdate()
	if combatHooksWanted() then
		combatEnsureHooks()
		if dbg.networkHooked then
			combatHookVortexSync()
			saAnnounceHooks()
		end
	end

	if Config.SilentAim and not Config.AimDebugger then
		saUpdateStatus()
		return
	end

	saHideStatus()

	if not Config.AimDebugger then
		dbgHideOverlay()
		return
	end

	dbgEnsureOverlay()
	dbgHookSync()

	local now = os.clock()
	if now < dbgNextOverlayAt then
		return
	end
	dbgNextOverlayAt = now + DBG_OVERLAY_INTERVAL

	local origin = aimOrigin()
	local part = combatTargetPart or closestAimPart(origin)
	local targetNameStr = if part and part.Parent then part.Parent.Name else "—"
	local mouseHit = _G.MouseHitSpot
	local mouseHitStr = if typeof(mouseHit) == "Vector3"
		then string.format("%.0f,%.0f,%.0f", mouseHit.X, mouseHit.Y, mouseHit.Z)
		else "—"
	local thirdPerson = isThirdPerson()
	local flame = dbgViewModelFlame()
	local camLook = Camera.CFrame.LookVector
	local camToTarget = if part then dbgAngleTo(Camera.CFrame.Position, camLook, part.Position) else nil
	local serverToTarget = if part and dbg.lastFire and dbg.lastFire.serverCf
		then dbgAngleTo(dbg.lastFire.serverCf.Position, dbg.lastFire.serverCf.LookVector, part.Position)
		else nil
	local syncCf = dbg.lastSyncCf or saLastSyncCf
	local syncToTarget = if part and syncCf
		then dbgAngleTo(syncCf.Position, syncCf.LookVector, part.Position)
		else nil
	local clockOffset = LocalPlayer:GetAttribute("ClockOffset")
	local networkReady = clockOffset ~= nil

	local lines = {
		"── Silent Aim Debugger ──",
		string.format(
			"Hooks: net:%s vortex:%s dbg-sync:%d | %s",
			if dbg.networkHooked then "OK" else "—",
			if sa.vortexSync then "OK" else "—",
			dbg.syncBound,
			dbg.status
		),
		string.format(
			"Net: %s | ClockOffset: %s | %s",
			if networkReady then "ready" else "pending",
			dbgShortVal(clockOffset),
			if thirdPerson then "3rd person" else "1st person"
		),
		string.format(
			"Counts  net:%d  Fire:%d  Hit:%d  Sync:%d  last:%s",
			dbg.netCount,
			dbg.fireCount,
			dbg.hitCount,
			dbg.syncCount,
			if dbg.lastEvent ~= "" then dbg.lastEvent else "—"
		),
		string.format("Target: %s | FOV ok: %s", targetNameStr, if part then "yes" else "no"),
		string.format(
			"Angles°  cam:%s  server:%s  sync:%s",
			if camToTarget then string.format("%.1f", camToTarget) else "—",
			if serverToTarget then string.format("%.1f", serverToTarget) else "—",
			if syncToTarget then string.format("%.1f", syncToTarget) else "—"
		),
		"MouseHitSpot: " .. mouseHitStr,
		string.format(
			"Flame: %s",
			if flame then dbgShortCf(flame.CFrame) else "—"
		),
		"Cam look: " .. string.format("%.2f,%.2f,%.2f", camLook.X, camLook.Y, camLook.Z),
		string.format(
			"Last Fire [%s]: %s",
			if dbg.lastFire then dbg.lastFire.weapon else "—",
			if dbg.lastFire then dbgShortCf(dbg.lastFire.serverCf) else "—"
		),
		string.format(
			"Last Sync [%s]: %s",
			dbg.lastSyncWeapon or "—",
			dbgShortCf(dbg.lastSyncCf)
		),
		string.format(
			"Last Hitcheck: %s | %s | %s | %s",
			if dbg.lastHitcheck then dbgShortVal(dbg.lastHitcheck.a) else "—",
			if dbg.lastHitcheck then dbgShortVal(dbg.lastHitcheck.b) else "—",
			if dbg.lastHitcheck then dbgShortVal(dbg.lastHitcheck.c) else "—",
			if dbg.lastHitcheck then dbgShortVal(dbg.lastHitcheck.d) else "—"
		),
		"Hook: Network Fire CFrame + Vortex Sync shot + MouseHitSpot",
		if dbg.remotePath ~= "" then dbg.remotePath else "Remote: not found yet",
	}

	for i = 1, DBG_LINE_COUNT do
		dbgSetLine(i, lines[i] or "", lines[i] ~= nil)
	end
end

-- ESP

local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0))
		local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))
		if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
			local height = math.max(12, bot.Y - top.Y)
			local width = height * 0.52
			return top.X - width * 0.5, top.Y, width, height
		end
	end

	local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
	if onScreen and pos.Z > 0 then
		local height = 56
		local width = height * 0.52
		return pos.X - width * 0.5, pos.Y - height * 0.5, width, height
	end

	local cf, size = char:GetBoundingBox()
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local ok = false

	for i = 1, 8 do
		local o = CORNER_OFFSETS[i]
		local p, on = Camera:WorldToViewportPoint((cf * CFrame.new(hx * o.X, hy * o.Y, hz * o.Z)).Position)
		if on and p.Z > 0 then
			ok = true
			minX = math.min(minX, p.X)
			minY = math.min(minY, p.Y)
			maxX = math.max(maxX, p.X)
			maxY = math.max(maxY, p.Y)
		end
	end

	if not ok then
		return nil
	end
	return minX, minY, maxX - minX, maxY - minY
end

local function mk(kind: string, props: { [string]: any })
	local d = Drawing.new(kind)
	for k, v in props do
		d[k] = v
	end
	d.Visible = false
	return d
end

local ESP_DRAWABLES = { "backdrop", "name", "hpOutline", "hpFill", "dist", "line" }

local function setVisible(entry: any, visible: boolean)
	for _, key in ESP_DRAWABLES do
		local draw = entry[key]
		draw.Visible = visible and (key ~= "line" or Config.ESPSnaplines)
	end
	for _, corner in entry.corners do
		corner.Visible = visible
	end
end

local function hideAll()
	for _, entry in esp do
		setVisible(entry, false)
	end
end

local function destroyEntry(entry: any)
	for _, key in ESP_DRAWABLES do
		entry[key]:Remove()
	end
	for _, corner in entry.corners do
		corner:Remove()
	end
end

local function drawCorners(corners: { any }, x: number, y: number, w: number, h: number, color: Color3)
	local len = math.clamp(math.min(w, h) * 0.24, 7, 16)
	local right, bottom = x + w, y + h

	corners[1].From = Vector2.new(x, y)
	corners[1].To = Vector2.new(x + len, y)
	corners[2].From = Vector2.new(x, y)
	corners[2].To = Vector2.new(x, y + len)
	corners[3].From = Vector2.new(right, y)
	corners[3].To = Vector2.new(right - len, y)
	corners[4].From = Vector2.new(right, y)
	corners[4].To = Vector2.new(right, y + len)
	corners[5].From = Vector2.new(x, bottom)
	corners[5].To = Vector2.new(x + len, bottom)
	corners[6].From = Vector2.new(x, bottom)
	corners[6].To = Vector2.new(x, bottom - len)
	corners[7].From = Vector2.new(right, bottom)
	corners[7].To = Vector2.new(right - len, bottom)
	corners[8].From = Vector2.new(right, bottom)
	corners[8].To = Vector2.new(right, bottom - len)

	for _, corner in corners do
		corner.Color = color
		corner.Visible = true
	end
end

local function ensure(char: Model)
	local entry = esp[char]
	if entry then
		return entry
	end

	local corners = table.create(8)
	for _ = 1, 8 do
		table.insert(corners, mk("Line", { Thickness = 1.2, Transparency = 0.06 }))
	end

	entry = {
		backdrop = mk("Square", { Filled = true, Thickness = 0, Transparency = 0.84 }),
		corners = corners,
		name = mk("Text", { Size = 13, Center = true, Outline = true }),
		hpOutline = mk("Square", { Filled = true, Thickness = 0, Color = BAR_BG }),
		hpFill = mk("Square", { Filled = true, Thickness = 0 }),
		dist = mk("Text", { Size = 10, Center = true, Outline = true, Transparency = 0.12 }),
		line = mk("Line", { Thickness = 1, Transparency = 0.5 }),
	}
	esp[char] = entry
	return entry
end

if canDraw then
	aimFovCircle = mk("Circle", {
		Thickness = 1,
		NumSides = 48,
		Filled = false,
		Transparency = 0.45,
		Color = Color3.fromRGB(255, 255, 255),
	})
end

local function drawTarget(name: string, char: Model, hum: Humanoid, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
	local rel = relation(name, char)
	if rel == "Ally" and not Config.ESPAllies then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local x, y, w, h = box2d(char, root)
	if not x then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local entry = ensure(char)
	local accent = teamColor(rel)
	local cx = x + w * 0.5
	local bottom = y + h
	local hp = hum.Health
	local maxHp = if hum.MaxHealth > 0 then hum.MaxHealth else 100
	local ratio = math.clamp(hp / maxHp, 0, 1)
	local barW = math.max(38, w + 4)
	local barH = 3
	local barX = cx - barW * 0.5
	local barY = bottom + 6

	entry.backdrop.Position = Vector2.new(x - 2, y - 2)
	entry.backdrop.Size = Vector2.new(w + 4, h + 4)
	entry.backdrop.Color = BACKDROP
	entry.backdrop.Visible = true

	drawCorners(entry.corners, x, y, w, h, accent)

	entry.name.Position = Vector2.new(cx, y - 17)
	entry.name.Text = string.format("%s  %d", displayName(name), math.floor(hp))
	entry.name.Color = WHITE
	entry.name.Visible = true

	entry.hpOutline.Position = Vector2.new(barX, barY)
	entry.hpOutline.Size = Vector2.new(barW, barH)
	entry.hpOutline.Visible = true

	entry.hpFill.Position = Vector2.new(barX, barY)
	entry.hpFill.Size = Vector2.new(math.max(1, barW * ratio), barH)
	entry.hpFill.Color = hpColor(ratio)
	entry.hpFill.Visible = true

	entry.dist.Position = Vector2.new(cx, barY + 7)
	entry.dist.Text = formatDistance((root.Position - camPos).Magnitude)
	entry.dist.Color = DIM
	entry.dist.Visible = true

	if snapFrom then
		entry.line.From = snapFrom
		entry.line.To = Vector2.new(cx, bottom + 1)
		entry.line.Color = accent
	end
	entry.line.Visible = Config.ESPSnaplines and snapFrom ~= nil
end

local function updateESP()
	if not canDraw then
		return
	end
	if not Config.ESP then
		if espNeedsHide then
			hideAll()
			espNeedsHide = false
		end
		return
	end
	espNeedsHide = true

	if not wallsFolder or not wallsFolder.Parent then
		wallsFolder = workspace:FindFirstChild("Walls")
	end

	local camPos = Camera.CFrame.Position
	local snapFrom = if Config.ESPSnaplines
		then Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
		else nil
	local seen: { [Model]: boolean } = {}

	for char, name in collectTargets() do
		local alive, hum, root = isCombatModel(char)
		if alive and hum and root and not isAllySpawnShielded(name) then
			seen[char] = true
			drawTarget(name, char, hum, root, camPos, snapFrom)
		end
	end

	for char, entry in esp do
		if not seen[char] or not char.Parent then
			destroyEntry(entry)
			esp[char] = nil
		end
	end
end

UILib.create({
	title = "GUNFIGHT ARENA",
	config = Config,
	pages = {
		{
			label = "Combat",
			sections = {
				{
					title = "Aimbot",
					items = {
						{ type = "toggle", key = "Aimbot", label = "Aimbot", hud = "Aimbot" },
						{ type = "toggle", key = "AimTeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "toggle", key = "AimHold", label = "Hold RMB", hud = "Hold RMB" },
						{ type = "toggle", key = "AimSticky", label = "Sticky Aim", hud = "Sticky Aim" },
						{
							type = "select",
							key = "AimPart",
							label = "Bone",
							options = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
						},
						{ type = "slider", key = "AimFOV", label = "FOV", min = 20, max = 500, step = 10, onChange = setAimFOV },
						{ type = "slider", key = "AimSmooth", label = "Smoothness", min = 1, max = 100, step = 1 },
						{ type = "toggle", key = "AimFOVCircle", label = "FOV Circle", hud = "FOV Circle" },
						{ type = "hint", text = "Sticky locks target until RMB release or death. Smoothness: 1 snap, 100 glide." },
					},
				},
			},
		},
		{
			label = "Silent Aim",
			sections = {
				{
					title = "Silent Aim",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{
							type = "hint",
							text = "Hold RMB, aim in FOV, shoot. Uses Combat team/FOV/bone/sticky. Enable Debugger to verify angles.",
						},
					},
				},
				{
					title = "Debug",
					items = {
						{ type = "toggle", key = "AimDebugger", label = "Debugger", hud = "SA Debug" },
						{
							type = "hint",
							text = "Traces Fire/Hitcheck + Sync. Rejoin once after updating. Console logs are rate-limited.",
						},
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
						{ type = "label", text = "ESP colors — tap swatch" },
						{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
						{ type = "color", key = "ESPAllyColor", label = "Ally" },
						{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
})

RunService.RenderStepped:Connect(function()
	updateESP()
	dbgUpdate()
end)
RunService:BindToRenderStep("MicroHubGFA_Aim", Enum.RenderPriority.Camera.Value + 1, updateCombatAim)

print("[MicroHub] Gunfight Arena", GAME_BUILD, "— Drawing:", canDraw)
