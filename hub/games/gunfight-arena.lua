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

local GAME_BUILD = "35-sa-volley"
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
local saShotTarget: BasePart? = nil

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
	if child and child:IsA("Player") then return child end
	for _, p in Players:GetPlayers() do
		if p.Name == name then return p end
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
	local rec = Players:FindFirstChild(name)
	local id = rec and rec:GetAttribute("Team")
	if id == nil then
		local p = findPlayer(name)
		id = p and p:GetAttribute("Team")
	end
	if id == nil and char then id = char:GetAttribute("Team") end
	return if id == nil then nil else normTeam(id)
end

local function relation(name: string, char: Model?): string
	if name == LocalPlayer.Name then return "Ally" end
	if name == "Skinwalker" or not hasTeamPlay() then return "Enemy" end
	local pt = getTeamFor(name, char)
	return if pt ~= nil and teamsEqual(getLocalTeam(), pt) then "Ally" else "Enemy"
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
	local t: { [Model]: string } = {}
	local function add(name: string?, char: Instance?)
		if not name or name == LocalPlayer.Name or not char or not char:IsA("Model") or t[char] then return end
		if name == "Skinwalker" or isKnownCombatant(name) then t[char] = name end
	end
	for name, char in getSpawned() do add(name, char) end
	for _, rec in Players:GetChildren() do add(rec.Name, workspace:FindFirstChild(rec.Name)) end
	for _, p in Players:GetPlayers() do
		if p ~= LocalPlayer then add(p.Name, workspace:FindFirstChild(p.Name)); add(p.Name, p.Character) end
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and isKnownCombatant(child.Name) then add(child.Name, child) end
	end
	if getGameMode() == "BOSS" then add("Skinwalker", workspace:FindFirstChild("Skinwalker")) end
	return t
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
	saShotTarget = nil
	if Config.Aimbot and combatHoldActive() then
		combatTargetPart = resolveAimTarget(origin)
	elseif Config.SilentAim then
		combatTargetPart = closestAimPart(origin)
	end
	saShotTarget = if Config.SilentAim and combatTargetPart and combatTargetPart.Parent then combatTargetPart else nil
	if not combatAimWanted() then
		stickyChar = nil
		stickyNeedsRelease = false
	end

	if Config.SilentAim and not Config.Aimbot and saShotTarget and isThirdPerson() then
		setMouseHit(saShotTarget.Position)
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

-- Combat hooks: silent aim + debugger (Vortex Sync -> Network.FireServer)

local HOOK_RETRY, HOOK_MAX, GC_INTERVAL = 3, 12, 6
local OVERLAY_DT, SYNC_SCAN, FLAME_CACHE, LOG_CD = 0.12, 1, 0.5, 4
local OVERLAY_MAX = 17

local C = {
	net = 0, fire = 0, hit = 0, sync = 0, syncBound = 0,
	netHooked = false, vortexHooked = false, giveUp = false, installing = false,
	announced = false, capsDone = false, initDone = false,
	status = "idle", remote = "", lastEvt = "",
	lastFire = nil :: any, lastHit = nil :: any, lastSyncCf = nil :: CFrame?, lastSyncWep = "",
	logCd = {} :: { [string]: number },
	saFireAt = 0, saSyncAt = 0, saSyncCf = nil :: CFrame?,
	sa = {
		tgt = "-", tgtSrc = "-",
		sync = "-", fire = "-", encode = "-",
		volley = 0, lastVolleyAt = 0, lastSummaryVolley = 0,
		hitVolley = 0, hitName = "", lastIssue = "-",
	},
}
local netOrig: ((...any) -> ...any)?, vortexOrig: ((...any) -> ...any)?
local vortexSyncRef: BindableEvent? = nil
local saVSyncConn: RBXScriptConnection? = nil
local netApi: any, netRemote: RemoteEvent?, netFireFn: ((...any) -> ...any)?
local nextGc, nextOv, nextSync, nextFlame, sawClock = 0, 0, 0, 0, false
local cachedFlame: BasePart?
local ovLines: { any } = {}
local syncConns: { [Instance]: RBXScriptConnection } = {}

local function volt(n: string): any
	if typeof(getgenv) == "function" then
		local v = getgenv()[n]
		if v ~= nil then return v end
	end
	return rawget(_G, n)
end

local hookfn = volt("hookfunction")
local newcc = volt("newcclosure")
local filtergc = volt("filtergc")
local getgc = volt("getgc")
local chkcaller = volt("checkcaller")

local function wrap(fn: (...any) -> ...any): (...any) -> ...any
	return if typeof(newcc) == "function" then newcc(fn) else fn
end

local function fromGame(): boolean
	return typeof(chkcaller) ~= "function" or not chkcaller()
end

local function tblGet(t: any, k: string): any
	if typeof(t) ~= "table" then return nil end
	local v = rawget(t, k)
	if v ~= nil then return v end
	local ok, x = pcall(function() return t[k] end)
	return if ok then x else nil
end

local function shortCf(cf: any): string
	if typeof(cf) ~= "CFrame" then return "-" end
	local p, l = cf.Position, cf.LookVector
	return string.format("p(%.0f,%.0f,%.0f) lv(%.2f,%.2f,%.2f)", p.X, p.Y, p.Z, l.X, l.Y, l.Z)
end

local function short(v: any): string
	local t = typeof(v)
	if t == "string" then return #v > 28 and string.sub(v, 1, 25) .. "..." or v end
	if t == "number" then return string.format("%.3f", v) end
	if t == "boolean" then return if v then "true" else "false" end
	if t == "CFrame" then return shortCf(v) end
	if t == "Instance" then return v.Name end
	return t
end

local function dbgLog(key: string, msg: string, cd: number?)
	if not Config.AimDebugger then return end
	cd = cd or LOG_CD
	local now = os.clock()
	if cd > 0 and now - (C.logCd[key] or 0) < cd then return end
	C.logCd[key] = now
	print("[GFA-DBG]", key, msg)
end

local function saApiLabel(): string
	if netApi and typeof(tblGet(netApi, "EncodeData")) == "function" then return "full" end
	return "gc-fn"
end

local function saNeedsEncode(sample: any): boolean
	return typeof(sample) == "string" and string.sub(sample, 1, 1) == "~"
end

local function saEncodeLabel(sample: any, result: any): string
	if not saNeedsEncode(sample) then return "plain" end
	if typeof(result) == "string" and string.sub(result, 1, 1) == "~" then return "OK" end
	return "FAIL"
end

local function saDbgSkip(layer: string, reason: string)
	if not Config.AimDebugger then return end
	C.sa.lastIssue = layer .. ":" .. reason
	dbgLog("SA-skip", layer .. " " .. reason, 0.25)
end

local function saOnVSyncEvent()
	if not Config.SilentAim then return end
	C.sa.volley += 1
	C.sa.lastVolleyAt = os.clock()
	if C.sa.sync ~= "OK" then
		C.sa.sync = "event"
	end
	C.sa.fire, C.sa.encode = "-", "-"
end

local function bindSaVolleyTracker()
	if saVSyncConn then return end
	local sync = vortexSyncRef
	if not sync then
		local ps = LocalPlayer:FindFirstChild("PlayerScripts")
		local vortex = ps and ps:FindFirstChild("Vortex")
		sync = vortex and vortex:FindFirstChild("Sync")
	end
	if not sync or not sync:IsA("BindableEvent") then return end
	vortexSyncRef = sync
	saVSyncConn = sync.Event:Connect(function(a1: any)
		if a1 == LocalPlayer then
			saOnVSyncEvent()
		end
	end)
end

local function saDiagShotSummary()
	if not Config.AimDebugger or not Config.SilentAim then return end
	local volley = C.sa.volley
	if volley <= 0 or C.sa.lastSummaryVolley == volley then return end
	C.sa.lastSummaryVolley = volley
	dbgLog(
		"SA-shot",
		string.format(
			"volley #%d (net Fire #%d) tgt=%s(%s) sync=%s fire=%s encode=%s api=%s",
			volley,
			C.fire,
			C.sa.tgt,
			C.sa.tgtSrc,
			C.sa.sync,
			C.sa.fire,
			C.sa.encode,
			saApiLabel()
		),
		0
	)
	task.delay(0.6, function()
		if not Config.AimDebugger or not Config.SilentAim then return end
		if C.sa.lastSummaryVolley ~= volley then return end
		if C.sa.hitVolley == volley then
			dbgLog("SA-hit", string.format("volley #%d confirmed %s", volley, C.sa.hitName), 0)
		else
			dbgLog("SA-miss", string.format("volley #%d no Hitcheck in 600ms (%s)", volley, C.sa.lastIssue), 0)
		end
	end)
end

local function decode(v: any): any
	if typeof(v) ~= "string" or string.sub(v, 1, 1) ~= "~" then return v end
	local mod = game:GetService("ReplicatedStorage"):FindFirstChild("DataCodec")
	if not mod then return v end
	local ok, codec = pcall(require, mod)
	if not ok or typeof(codec) ~= "table" or typeof(codec.AutoDecode) ~= "function" then return v end
	local ok2, out = pcall(codec.AutoDecode, v)
	return if ok2 then out else v
end

local function encode(sample: any, value: any): any
	if typeof(sample) ~= "string" or string.sub(sample, 1, 1) ~= "~" then return value end
	local enc = netApi and tblGet(netApi, "EncodeData")
	if typeof(enc) ~= "function" then return value end
	local ok, out = pcall(function() return enc(netApi, value) end)
	if not ok then ok, out = pcall(enc, value) end
	return if ok then out else value
end

local function netReady(): boolean
	return LocalPlayer:GetAttribute("ClockOffset") ~= nil
end

local function isCombatRemote(re: RemoteEvent): boolean
	if re:GetFullName():find(LocalPlayer.Name, 1, true) then return true end
	if re:IsDescendantOf(LocalPlayer) then return true end
	local rec = Players:FindFirstChild(LocalPlayer.Name)
	if rec and re:IsDescendantOf(rec) then return true end
	return re:FindFirstAncestorWhichIsA("Player") == LocalPlayer
end

local function isNetworkApi(tbl: any): boolean
	if typeof(tbl) ~= "table" then return false end
	for _, k in { "FireServer", "OnEvent", "EncodeData", "DecodeData" } do
		if typeof(tblGet(tbl, k)) ~= "function" then return false end
	end
	local re = tblGet(tbl, "RE")
	return typeof(re) == "Instance" and re:IsA("RemoteEvent") and isCombatRemote(re)
end

local function findFireFn(): ((...any) -> ...any)?
	if netFireFn then return netFireFn end
	if typeof(filtergc) ~= "function" then return nil end
	for _, q in { { Constants = { "Client is disconnected from the network" } }, { Constants = { "disconnected from the network" } } } do
		local ok, fns = pcall(filtergc, "function", { IgnoreExecutor = true, Constants = q.Constants })
		if ok and typeof(fns) == "table" then
			for _, fn in fns do
				if typeof(fn) == "function" then netFireFn = fn; return fn end
			end
		end
	end
	return nil
end

local function remoteScore(re: RemoteEvent): number
	if not isCombatRemote(re) then return 0 end
	if re:GetFullName():find(LocalPlayer.Name, 1, true) then return 100 end
	if re:IsDescendantOf(LocalPlayer) then return 100 end
	local rec = Players:FindFirstChild(LocalPlayer.Name)
	if rec and re:IsDescendantOf(rec) then return 100 end
	return 50
end

local function findCombatRemote(): RemoteEvent?
	if netRemote and netRemote.Parent then return netRemote end
	local direct = LocalPlayer:FindFirstChild("RemoteEvent")
	if direct and direct:IsA("RemoteEvent") and isCombatRemote(direct) then return direct end
	for _, desc in LocalPlayer:GetDescendants() do
		if desc.Name == "RemoteEvent" and desc:IsA("RemoteEvent") and isCombatRemote(desc) then return desc end
	end
	local ps = LocalPlayer:FindFirstChild("PlayerScripts")
	if ps then
		for _, desc in ps:GetDescendants() do
			if desc.Name == "RemoteEvent" and desc:IsA("RemoteEvent") and isCombatRemote(desc) then return desc end
		end
	end
	local rec = Players:FindFirstChild(LocalPlayer.Name)
	if rec then
		local nested = rec:FindFirstChild("RemoteEvent", true)
		if nested and nested:IsA("RemoteEvent") and isCombatRemote(nested) then return nested end
	end
	return nil
end

local function bindNetworkApi(self: any)
	if typeof(self) ~= "table" or typeof(tblGet(self, "EncodeData")) ~= "function" then return end
	netApi = self
	local re = tblGet(self, "RE")
	if typeof(re) == "Instance" and re:IsA("RemoteEvent") and isCombatRemote(re) then
		netRemote = re
		local path = re:GetFullName()
		if C.remote ~= path then
			C.remote = path
			if Config.AimDebugger then print("[GFA-DBG] bound Network API @", path) end
		end
	end
end

local function findApiByRemote(re: RemoteEvent): any
	if typeof(getgc) ~= "function" then return nil end
	local ok, objs = pcall(getgc, true)
	if not ok or typeof(objs) ~= "table" then return nil end
	for _, obj in objs do
		if typeof(obj) ~= "table" then continue end
		if tblGet(obj, "RE") ~= re then continue end
		if typeof(tblGet(obj, "FireServer")) ~= "function" then continue end
		if typeof(tblGet(obj, "EncodeData")) ~= "function" then continue end
		return obj
	end
	return nil
end

local function findNetworkApi(): (any, RemoteEvent?)
	if netApi and typeof(tblGet(netApi, "EncodeData")) == "function" and (netRemote == nil or netRemote.Parent) then
		return netApi, netRemote
	end
	if netReady() and not sawClock then sawClock, nextGc = true, 0 end
	local now = os.clock()
	if now < nextGc then return nil, nil end
	nextGc = now + GC_INTERVAL

	local bestApi, bestRe, bestScore = nil, nil, 0
	local function consider(tbl: any)
		if not isNetworkApi(tbl) then return end
		local re = tblGet(tbl, "RE")
		if typeof(re) ~= "Instance" or not re:IsA("RemoteEvent") then return end
		local score = remoteScore(re)
		if score > bestScore then bestApi, bestRe, bestScore = tbl, re, score end
	end

	if typeof(filtergc) == "function" then
		for _, keys in { { "FireServer", "RE" }, { "FireServer", "OnEvent", "EncodeData", "DecodeData", "RE" } } do
			local ok, tables = pcall(filtergc, "table", { Keys = keys })
			if ok and typeof(tables) == "table" then for _, tbl in tables do consider(tbl) end end
		end
	end
	if typeof(getgc) == "function" then
		local ok, objs = pcall(getgc, true)
		if ok and typeof(objs) == "table" then for _, o in objs do consider(o) end end
	end

	if bestApi and bestRe and bestScore >= 50 then
		netApi, netRemote = bestApi, bestRe
		C.remote = bestRe:GetFullName()
		findFireFn()
		return bestApi, bestRe
	end

	local re = findCombatRemote()
	if re then
		netRemote = re
		local apiByRe = findApiByRemote(re)
		if apiByRe then
			netApi = apiByRe
			C.remote = re:GetFullName()
			findFireFn()
			return apiByRe, re
		end
	end
	local fn = findFireFn()
	if fn then
		if not netApi or typeof(tblGet(netApi, "EncodeData")) ~= "function" then
			netApi = { FireServer = fn }
		end
		return netApi, netRemote
	end
	return nil, nil
end

local function recordNet(evt: any, payload: { any })
	if typeof(evt) ~= "string" or (evt ~= "Fire" and evt ~= "Hitcheck") then return end
	if evt == "Fire" and C.lastFire and os.clock() - C.lastFire.at < 0.02 then return end
	C.net += 1; C.lastEvt = evt
	if evt == "Fire" then
		C.fire += 1
		local w, clk, cf = decode(payload[1]), decode(payload[2]), decode(payload[3])
		C.lastFire = {
			at = os.clock(), weapon = short(w),
			serverCf = if typeof(cf) == "CFrame" then cf else nil,
			clock = if typeof(clk) == "number" then clk else nil,
		}
		dbgLog("Fire", string.format("Fire #%d %s %s", C.fire, C.lastFire.weapon, shortCf(C.lastFire.serverCf)), 2)
		if Config.SilentAim then
			saDiagShotSummary()
		end
	else
		C.hit += 1
		C.lastHit = { at = os.clock(), a = decode(payload[1]), b = decode(payload[2]), c = decode(payload[3]), d = decode(payload[4]) }
		dbgLog("Hitcheck", string.format("#%d %s | %s | %s | %s", C.hit, short(C.lastHit.a), short(C.lastHit.b), short(C.lastHit.c), short(C.lastHit.d)), 2)
		if C.sa.volley > 0 and os.clock() - C.sa.lastVolleyAt < 0.75 then
			C.sa.hitVolley = C.sa.volley
			C.sa.hitName = short(C.lastHit.b)
		end
	end
end

local function viewFlame(): BasePart?
	if cachedFlame and cachedFlame.Parent then return cachedFlame end
	local now = os.clock()
	if now < nextFlame then return cachedFlame end
	nextFlame = now + FLAME_CACHE
	local vm = workspace:FindFirstChild("ViewModel")
	if not vm or not vm:IsA("Model") then cachedFlame = nil; return nil end
	for _, d in vm:GetDescendants() do
		if d.Name == "Flame" and d:IsA("BasePart") then cachedFlame = d; return d end
	end
	cachedFlame = nil
	return nil
end

local function saResolvePart(): (BasePart?, string)
	local p = saShotTarget
	if p and p.Parent then return p, "cache" end
	p = closestAimPart(aimOrigin())
	return if p then p else nil, if p then "fov" else "none"
end

local function saAimMouseHit(part: BasePart)
	setMouseHit(part.Position)
end

local function saShotOrigin(fallback: Vector3): Vector3
	local flame = viewFlame()
	return if flame then flame.Position else fallback
end

local function saDbgRedirect(kind: string, part: BasePart, cf: CFrame, extra: string?)
	if not Config.AimDebugger then return end
	local name = if part.Parent then part.Parent.Name else "?"
	local tail = if extra then " " .. extra else ""
	dbgLog("SA-" .. kind, string.format("-> %s %s%s", name, shortCf(cf), tail), 0.5)
end

local function injectHitables(hitables: any, part: BasePart): any
	local model = part.Parent
	if not model or not model:IsA("Model") or typeof(hitables) ~= "table" then return hitables end
	for _, e in hitables do if e == model then return hitables end end
	table.insert(hitables, model)
	return hitables
end

local function rewriteFire(payload: { any }): { any }
	if not Config.SilentAim then return payload end
	local part, src = saResolvePart()
	if not part then
		C.sa.fire = "skip:no-target"
		saDbgSkip("Fire", "no FOV target")
		return payload
	end
	C.sa.tgt = part.Parent and part.Parent.Name or "?"
	C.sa.tgtSrc = src
	saAimMouseHit(part)
	local raw = payload[3]
	local cf = decode(raw)
	if typeof(cf) ~= "CFrame" then
		C.sa.fire = "skip:bad-cf"
		saDbgSkip("Fire", "payload[3] not CFrame (" .. typeof(cf) .. ")")
		return payload
	end
	local newCf = CFrame.new(saShotOrigin(cf.Position), part.Position)
	local encoded = encode(raw, newCf)
	C.sa.encode = saEncodeLabel(raw, encoded)
	if C.sa.encode == "FAIL" then
		saDbgSkip("Fire", "EncodeData failed — api=" .. saApiLabel())
	end
	payload[3] = encoded
	C.sa.fire = "OK"
	C.saFireAt = os.clock()
	saDbgRedirect("Fire", part, newCf, "enc=" .. C.sa.encode)
	return payload
end

local function rewriteSync(shotCf: CFrame, hitables: any): (CFrame, any)
	if not Config.SilentAim then return shotCf, hitables end
	local part, src = saResolvePart()
	if not part then
		C.sa.sync = "skip:no-target"
		saDbgSkip("Sync", "no FOV target")
		return shotCf, hitables
	end
	C.sa.tgt = part.Parent and part.Parent.Name or "?"
	C.sa.tgtSrc = src
	saAimMouseHit(part)
	local newCf = CFrame.new(saShotOrigin(shotCf.Position), part.Position)
	C.saSyncCf, C.saSyncAt = newCf, os.clock()
	C.sa.sync = "OK"
	local model = part.Parent
	local injected = model and model:IsA("Model") and typeof(hitables) == "table"
	saDbgRedirect("Sync", part, newCf, if injected then "hitables+1" else "hitables?")
	return newCf, injectHitables(hitables, part)
end

local function isVortexSync(self: any): boolean
	if vortexSyncRef and self == vortexSyncRef then return true end
	if typeof(self) ~= "Instance" or not self:IsA("BindableEvent") or self.Name ~= "Sync" then return false end
	local vortex = self.Parent
	return vortex and vortex.Name == "Vortex" and vortex:IsDescendantOf(LocalPlayer)
end

local function vortexSyncHandler(orig: (...any) -> ...any)
	return wrap(function(self, a1, a2, a3, a4, a5, a6, a7, a8)
		if Config.SilentAim and isVortexSync(self) and a1 == LocalPlayer and typeof(a4) == "CFrame" then
			if fromGame() then
				local okR, nc, nh = pcall(rewriteSync, a4, a7)
				if okR and typeof(nc) == "CFrame" then a4, a7 = nc, nh end
			elseif Config.AimDebugger then
				C.sa.sync = "skip:caller"
				saDbgSkip("Sync", "executor caller (checkcaller)")
			end
		end
		return orig(self, a1, a2, a3, a4, a5, a6, a7, a8)
	end)
end

local function hookVortex()
	if C.vortexHooked or not Config.SilentAim or typeof(hookfn) ~= "function" then return end
	local ps = LocalPlayer:FindFirstChild("PlayerScripts")
	local vortex = ps and ps:FindFirstChild("Vortex")
	local sync = vortex and vortex:FindFirstChild("Sync")
	if not sync or not sync:IsA("BindableEvent") then return end
	vortexSyncRef = sync
	bindSaVolleyTracker()
	local syncFire = sync.Fire
	local ok = false
	if typeof(syncFire) == "function" then
		ok = pcall(function()
			vortexOrig = hookfn(syncFire, vortexSyncHandler(syncFire))
		end)
	end
	if not ok or typeof(vortexOrig) ~= "function" then
		vortexOrig = nil
		local probe = Instance.new("BindableEvent")
		local beFire = probe.Fire
		probe:Destroy()
		if typeof(beFire) == "function" then
			ok = pcall(function()
				vortexOrig = hookfn(beFire, vortexSyncHandler(beFire))
			end)
		end
	end
	if ok and typeof(vortexOrig) == "function" then C.vortexHooked = true end
end

local function announceSA()
	if C.announced or not Config.SilentAim or not C.netHooked then return end
	C.announced = true
	print("[GFA] silent aim ready", if C.remote ~= "" then C.remote else "Network.FireServer", if C.vortexHooked then "| Vortex.Sync" else "| sync:off")
end

local function hookNetwork(allowGcFallback: boolean?)
	if C.netHooked or not netReady() then
		if not netReady() then C.status = "waiting for ClockOffset" end
		return
	end
	local api, remote = findNetworkApi()
	local hasFullApi = api and typeof(tblGet(api, "EncodeData")) == "function"
	if Config.SilentAim and not hasFullApi and not allowGcFallback then return end
	local target = api and tblGet(api, "FireServer")
	if not target or typeof(hookfn) ~= "function" then return end
	if remote then
		if not isCombatRemote(remote) then return end
		C.remote = remote:GetFullName()
	elseif C.remote == "" then
		C.remote = "Network.FireServer (gc fn)"
	end
	local ok = pcall(function()
		netOrig = hookfn(target, wrap(function(self, eventName, ...)
			local args = { ... }
			if fromGame() then
				bindNetworkApi(self)
				if Config.SilentAim and eventName == "Fire" then
					local okR, na = pcall(rewriteFire, args)
					if okR and typeof(na) == "table" then args = na end
				end
				if Config.AimDebugger then recordNet(eventName, args) end
			elseif Config.AimDebugger and Config.SilentAim and eventName == "Fire" then
				C.sa.fire = "skip:caller"
				saDbgSkip("Fire", "executor caller (checkcaller)")
			end
			local o = netOrig
			return if typeof(o) == "function" then o(self, eventName, table.unpack(args)) else nil
		end))
	end)
	if not ok or typeof(netOrig) ~= "function" then netOrig = nil; return end
	C.netHooked = true
	C.status = "Network.FireServer hooked"
	hookVortex()
	announceSA()
	if Config.AimDebugger and not C.initDone then
		C.initDone = true
		print(
			"[GFA-DBG] init Network.FireServer @", C.remote,
			"| api:", saApiLabel(),
			"| vortex:", if C.vortexHooked then "BindableEvent.Fire" else "off"
		)
	end
end

local function ensureHooks()
	if not (Config.SilentAim or Config.AimDebugger) or C.netHooked or C.giveUp or C.installing then return end
	C.installing = true
	if Config.AimDebugger and not C.capsDone then
		C.capsDone = true
		print("[GFA-DBG] caps hookfunction:", typeof(hookfn), "filtergc:", typeof(filtergc), "getgc:", typeof(getgc), "remote:", C.remote ~= "" and C.remote or "nil")
	end
	task.spawn(function()
		local n = 0
		while (Config.SilentAim or Config.AimDebugger) and not C.netHooked and n < HOOK_MAX do
			n += 1
			hookNetwork(n >= 3)
			if not C.netHooked then
				C.status = if typeof(hookfn) ~= "function" then "hookfunction missing (Volt genv?)"
					elseif not netReady() then "waiting for ClockOffset"
					else "waiting for Network API (gc)"
				if n == 5 then dbgLog("init-fail", C.status, 0) end
				task.wait(HOOK_RETRY)
			end
		end
		if not C.netHooked then
			C.giveUp = true
			C.status = "hook install failed (rejoin)"
			if Config.SilentAim or Config.AimDebugger then warn("[GFA] combat hook failed after", n, "tries:", C.status) end
		end
		C.installing = false
	end)
end

local function bindSyncListeners()
	if not Config.AimDebugger then return end
	local now = os.clock()
	if now < nextSync then return end
	nextSync = now + SYNC_SCAN
	local ps = LocalPlayer:FindFirstChild("PlayerScripts")
	if not ps then return end
	local function bindSync(sync: Instance, label: string)
		if not sync:IsA("BindableEvent") or syncConns[sync] then return end
		syncConns[sync] = sync.Event:Connect(function(...)
			if not Config.AimDebugger then return end
			local args = { ... }
			if args[1] ~= LocalPlayer or typeof(args[4]) ~= "CFrame" then return end
			C.sync += 1
			C.lastSyncCf = args[4]
			C.lastSyncWep = short(args[6] or args[3])
			dbgLog(label, string.format("#%d %s %s", C.sync, C.lastSyncWep, shortCf(args[4])), 2)
		end)
		C.syncBound += 1
	end
	local vortex = ps:FindFirstChild("Vortex")
	local vSync = vortex and vortex:FindFirstChild("Sync")
	if vSync then bindSync(vSync, "VSync") end
	for _, desc in ps:GetDescendants() do
		if desc.Name == "Sync" and desc:IsA("BindableEvent") and desc ~= vSync then
			bindSync(desc, "Sync")
		end
	end
end

local function angleTo(origin: Vector3, look: Vector3, target: Vector3): number
	local dir = target - origin
	if dir.Magnitude < 0.01 then return 0 end
	return math.deg(math.acos(math.clamp(look.Unit:Dot(dir.Unit), -1, 1)))
end

local function overlayEnsure()
	if not canDraw or #ovLines > 0 then return end
	for i = 1, OVERLAY_MAX do
		local line = Drawing.new("Text")
		line.Size, line.Outline, line.Center, line.Visible = 13, true, false, false
		line.Position = Vector2.new(12, 8 + (i - 1) * 15)
		ovLines[i] = line
	end
end

local function overlayHide()
	for _, line in ovLines do line.Visible = false end
end

local function overlayShow(lines: { string }, dbgMode: boolean)
	overlayEnsure()
	for i = 1, OVERLAY_MAX do
		local line = ovLines[i]
		if line then
			line.Text = lines[i] or ""
			line.Visible = lines[i] ~= nil and (dbgMode and Config.AimDebugger or not dbgMode)
		end
	end
end

local function combatOverlayUpdate()
	if not canDraw then return end
	local now = os.clock()
	if now < nextOv then return end
	nextOv = now + OVERLAY_DT

	local origin = aimOrigin()
	local part = combatTargetPart or closestAimPart(origin)
	local tName = if part and part.Parent then part.Parent.Name else "—"

	if Config.SilentAim and not Config.AimDebugger then
		local syncAng = if part and C.saSyncCf then angleTo(C.saSyncCf.Position, C.saSyncCf.LookVector, part.Position) else nil
		overlayShow({
			"-- Silent Aim --",
			string.format("Hooks: net:%s vortex:%s | %s", if C.netHooked then "OK" else "-", if C.vortexHooked then "OK" else "-", C.status),
			string.format("Target: %s | FOV lock (no camera move)", tName),
			string.format("Last redirect  fire:%s  sync:%s",
				if C.saFireAt > 0 then string.format("%.1fs", now - C.saFireAt) else "-",
				if C.saSyncAt > 0 then string.format("%.1fs", now - C.saSyncAt) else "-"),
			string.format("Sync angle to target: %s", if syncAng then string.format("%.1f deg", syncAng) else "-"),
			"Enable Debugger below to compare Fire/Sync/Hitcheck",
		}, false)
		return
	end

	if not Config.AimDebugger then overlayHide(); return end

	bindSyncListeners()
	local mh = _G.MouseHitSpot
	local mhStr = if typeof(mh) == "Vector3" then string.format("%.0f,%.0f,%.0f", mh.X, mh.Y, mh.Z) else "-"
	local third = isThirdPerson()
	local flame = viewFlame()
	local camLook = Camera.CFrame.LookVector
	local camAng = if part then angleTo(Camera.CFrame.Position, camLook, part.Position) else nil
	local srvAng = if part and C.lastFire and C.lastFire.serverCf
		then angleTo(C.lastFire.serverCf.Position, C.lastFire.serverCf.LookVector, part.Position) else nil
	local syncCf = C.lastSyncCf or C.saSyncCf
	local syncAng = if part and syncCf then angleTo(syncCf.Position, syncCf.LookVector, part.Position) else nil
	local clk = LocalPlayer:GetAttribute("ClockOffset")

	local sa = C.sa
	local hitVerdict = if sa.hitVolley == sa.volley and sa.volley > 0
		then "HIT " .. sa.hitName
		elseif sa.volley > 0 then "pending/miss" else "-"
	overlayShow({
		"-- Silent Aim Debugger --",
		string.format("Hooks: net:%s vortex:%s sync:%d | %s", if C.netHooked then "OK" else "-", if C.vortexHooked then "OK" else "-", C.syncBound, C.status),
		string.format(
			"SA volley #%d (Fire #%d) tgt=%s(%s) sync=%s fire=%s enc=%s",
			sa.volley, C.fire, sa.tgt, sa.tgtSrc, sa.sync, sa.fire, sa.encode
		),
		string.format("SA verdict: %s | issue: %s | api: %s", hitVerdict, sa.lastIssue, saApiLabel()),
		string.format("Net: %s | %s | flame: %s", if clk ~= nil then "ready" else "pending", if third then "3rd" else "1st", if flame then "OK" else "MISS"),
		string.format("FOV target: %s | angles cam/srv/sync: %s / %s / %s",
			tName,
			if camAng then string.format("%.1f", camAng) else "-",
			if srvAng then string.format("%.1f", srvAng) else "-",
			if syncAng then string.format("%.1f", syncAng) else "-"),
		string.format("Counts Fire:%d Hit:%d VSync+Sync:%d", C.fire, C.hit, C.sync),
		"MouseHitSpot: " .. mhStr,
		string.format("Last Fire [%s]: %s", if C.lastFire then C.lastFire.weapon else "-", if C.lastFire then shortCf(C.lastFire.serverCf) else "-"),
		string.format("Last VSync [%s]: %s", C.lastSyncWep ~= "" and C.lastSyncWep or "-", shortCf(C.lastSyncCf)),
		string.format("Last Hitcheck: %s | %s | %s | %s",
			if C.lastHit then short(C.lastHit.a) else "-", if C.lastHit then short(C.lastHit.b) else "-",
			if C.lastHit then short(C.lastHit.c) else "-", if C.lastHit then short(C.lastHit.d) else "-"),
		"sync: OK=hooked | event=VSync only | SA-shot/hit/miss per volley",
		if C.remote ~= "" then C.remote else "Remote: not found yet",
		nil,
		nil,
	}, true)
end

local function combatUpdate()
	if Config.SilentAim or Config.AimDebugger then
		ensureHooks()
		if C.netHooked then
			hookVortex()
			bindSaVolleyTracker()
			announceSA()
		end
	end
	combatOverlayUpdate()
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
							text = "Redirects shots to closest FOV target. No camera move. Uses Combat team check, FOV, bone.",
						},
					},
				},
				{
					title = "Debug",
					items = {
						{ type = "toggle", key = "AimDebugger", label = "Debugger", hud = "SA Debug" },
						{
							type = "hint",
							text = "Console: SA-shot / SA-hit / SA-miss / SA-skip tell you exactly why SA failed. Rejoin after updates.",
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
	combatUpdate()
end)
RunService:BindToRenderStep("MicroHubGFA_Aim", Enum.RenderPriority.Camera.Value + 1, updateCombatAim)

print("[MicroHub] Gunfight Arena", GAME_BUILD, "— Drawing:", canDraw)
