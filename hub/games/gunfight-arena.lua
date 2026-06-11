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

local GAME_BUILD = "56-esp-boxfix"
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
	if Config.Aimbot and combatHoldActive() then
		combatTargetPart = resolveAimTarget(origin)
	elseif Config.SilentAim then
		local bestPart: BasePart? = nil
		local bestDist = math.huge
		for char, name in collectTargets() do
			if not isAimEligible(char, name) then continue end
			local part = char:FindFirstChild("HumanoidRootPart") or aimPart(char)
			if not part then continue end
			local distSq = screenDistSq(part.Position, origin)
			if distSq and distSq < bestDist then
				bestPart, bestDist = part, distSq
			end
		end
		combatTargetPart = bestPart
	end
	if not combatAimWanted() then
		stickyChar = nil
		stickyNeedsRelease = false
	end

	if Config.SilentAim and not Config.Aimbot and combatTargetPart then
		setMouseHit(combatTargetPart.Position)
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

-- Network hook: silent aim + debugger (filtergc table rawset)

local function voltApi(name: string): any
	if typeof(getgenv) == "function" then
		local v = getgenv()[name]
		if v ~= nil then return v end
	end
	return rawget(_G, name)
end

local filtergc = voltApi("filtergc")
local hookfn = voltApi("hookfunction")
local newcc = voltApi("newcclosure")
local hookmetamethod = voltApi("hookmetamethod")
local getnamecallmethod = voltApi("getnamecallmethod")
local netHooked = false
local netInstalling = false
local vortexHooked = false
local namecallHooked = false
local vortexHookMode = ""
local namecallOrig: ((...any) -> ...any)?
local vortexSyncRef: BindableEvent? = nil
local syncDbgConn: RBXScriptConnection? = nil
local dbgCounts = { fire = 0, hit = 0, vsync = 0 }
local saStickyPart: BasePart? = nil
local saStickyUntil = 0
local SA_STICKY_SEC = 0.2
local cachedFlame: BasePart? = nil
local nextFlame = 0

local function viewFlame(): BasePart?
	if cachedFlame and cachedFlame.Parent then
		return cachedFlame
	end
	local now = os.clock()
	if now < nextFlame then
		return cachedFlame
	end
	nextFlame = now + 0.5
	cachedFlame = nil
	local vm = workspace:FindFirstChild("ViewModel")
	if not vm or not vm:IsA("Model") then
		return nil
	end
	for _, d in vm:GetDescendants() do
		if d.Name == "Flame" and d:IsA("BasePart") then
			cachedFlame = d
			return d
		end
	end
	return nil
end

local function saShotOrigin(fallback: Vector3): Vector3
	local flame = viewFlame()
	return if flame then flame.Position else fallback
end

local function saScanTarget(): BasePart?
	local origin = aimOrigin()
	local bestPart: BasePart? = nil
	local bestDist = math.huge
	for char, name in collectTargets() do
		if not isAimEligible(char, name) then continue end
		local part = char:FindFirstChild("HumanoidRootPart") or aimPart(char)
		if not part then continue end
		local distSq = screenDistSq(part.Position, origin)
		if distSq and distSq < bestDist then
			bestPart, bestDist = part, distSq
		end
	end
	return bestPart
end

local function saLockTarget(part: BasePart?)
	if not part or not part.Parent then return nil end
	saStickyPart, saStickyUntil = part, os.clock() + SA_STICKY_SEC
	return part
end

local function saFireTarget(): BasePart?
	local now = os.clock()
	if saStickyPart and saStickyPart.Parent and now < saStickyUntil then
		local model = saStickyPart.Parent
		if model and model:IsA("Model") and isAimEligible(model, targetName(model)) then
			saStickyUntil = now + SA_STICKY_SEC
			return saStickyPart
		end
	end
	local p = combatTargetPart
	if p and p.Parent then return saLockTarget(p) end
	return saLockTarget(saScanTarget())
end

local function saAimCf(cf: CFrame, part: BasePart): CFrame
	return CFrame.new(saShotOrigin(cf.Position), part.Position)
end

local function saInjectHitables(hitables: any, part: BasePart): any
	local model = part.Parent
	if not model or not model:IsA("Model") or typeof(hitables) ~= "table" then return hitables end
	for _, e in hitables do if e == model then return hitables end end
	table.insert(hitables, model)
	return hitables
end

local function dbgDecode(v: any): any
	if typeof(v) ~= "string" or string.sub(v, 1, 1) ~= "~" then return v end
	local mod = game:GetService("ReplicatedStorage"):FindFirstChild("DataCodec")
	if not mod then return v end
	local ok, codec = pcall(require, mod)
	if not ok or typeof(codec) ~= "table" or typeof(codec.AutoDecode) ~= "function" then return v end
	local ok2, out = pcall(codec.AutoDecode, v)
	return if ok2 then out else v
end

local function dbgShortCf(cf: any): string
	if typeof(cf) ~= "CFrame" then return "-" end
	local p, l = cf.Position, cf.LookVector
	return string.format("p(%.0f,%.0f,%.0f) lv(%.2f,%.2f,%.2f)", p.X, p.Y, p.Z, l.X, l.Y, l.Z)
end

local function dbgShort(v: any): string
	local t = typeof(v)
	if t == "string" then return #v > 32 and string.sub(v, 1, 29) .. "..." or v end
	if t == "number" then return string.format("%.3f", v) end
	if t == "boolean" then return tostring(v) end
	if t == "CFrame" then return dbgShortCf(v) end
	if t == "Instance" then return v.Name end
	return t
end

local function netEncode(net: any, sample: any, value: any): any
	if typeof(sample) ~= "string" or string.sub(sample, 1, 1) ~= "~" then return value end
	local enc = rawget(net, "EncodeData")
	if typeof(enc) ~= "function" then return value end
	local ok, out = pcall(function() return enc(net, value) end)
	if not ok then ok, out = pcall(enc, value) end
	return if ok then out else value
end

local function isVortexSync(self: any): boolean
	if vortexSyncRef and self == vortexSyncRef then
		return true
	end
	if typeof(self) ~= "Instance" or not self:IsA("BindableEvent") or self.Name ~= "Sync" then
		return false
	end
	local vortex = self.Parent
	return vortex and vortex.Name == "Vortex" and vortex:IsDescendantOf(LocalPlayer)
end

local function saRewriteSync(a4: CFrame, a7: any, part: BasePart): (CFrame, any)
	if isThirdPerson() then
		setMouseHit(part.Position)
	end
	return saAimCf(a4, part), saInjectHitables(a7, part)
end

local function saApplySyncArgs(args: { any }): { any }
	if not Config.SilentAim or args[1] ~= LocalPlayer or typeof(args[4]) ~= "CFrame" then
		return args
	end
	local part = saFireTarget()
	if not part then
		return args
	end
	args[4], args[7] = saRewriteSync(args[4], args[7], part)
	if Config.AimDebugger then
		local tgt = if part.Parent then part.Parent.Name else "?"
		print("[GFA-DBG] SA-Sync ->", tgt, dbgShortCf(args[4]))
	end
	return args
end

local function saRewriteHitcheck(net: any, payload: { any }, part: BasePart): { any }
	local model = part.Parent
	if not model or not model:IsA("Model") then
		return payload
	end
	local extra = dbgDecode(payload[4])
	if typeof(extra) ~= "table" then
		extra = {}
	end
	return {
		netEncode(net, payload[1], workspace),
		netEncode(net, payload[2], model),
		netEncode(net, payload[3], part),
		netEncode(net, payload[4], extra),
	}
end

local function vortexSyncHandler(orig: (...any) -> ...any)
	local wrap = if typeof(newcc) == "function" then newcc else function(f) return f end
	return wrap(function(self, a1, a2, a3, a4, a5, a6, a7, a8)
		if Config.SilentAim and a1 == LocalPlayer and typeof(a4) == "CFrame" then
			local args = saApplySyncArgs({ a1, a2, a3, a4, a5, a6, a7, a8 })
			a1, a2, a3, a4, a5, a6, a7, a8 = table.unpack(args)
		end
		return orig(self, a1, a2, a3, a4, a5, a6, a7, a8)
	end)
end

local function tryHookSyncNamecall()
	if namecallHooked or vortexHooked or not Config.SilentAim then
		return
	end
	if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
		return
	end
	local wrap = if typeof(newcc) == "function" then newcc else function(f) return f end
	local ok = pcall(function()
		namecallOrig = hookmetamethod(game, "__namecall", wrap(function(self, ...)
			local method = getnamecallmethod()
			if method == "Fire" and isVortexSync(self) then
				local args = saApplySyncArgs({ ... })
				local o = namecallOrig
				return if typeof(o) == "function" then o(self, table.unpack(args)) else nil
			end
			local o = namecallOrig
			return if typeof(o) == "function" then o(self, ...) else nil
		end))
	end)
	if ok and typeof(namecallOrig) == "function" then
		namecallHooked = true
		vortexHooked = true
		vortexHookMode = "__namecall"
		print("[GFA] Vortex.Sync hooked via", vortexHookMode)
	end
end

local function tryHookSyncFire()
	if vortexHooked or not Config.SilentAim or typeof(hookfn) ~= "function" then
		return
	end
	local sync = vortexSyncRef
	if not sync then
		return
	end
	local syncFire = sync.Fire
	if typeof(syncFire) ~= "function" then
		return
	end
	local vortexOrig: ((...any) -> ...any)?
	local ok = pcall(function()
		vortexOrig = hookfn(syncFire, vortexSyncHandler(syncFire))
	end)
	if ok and typeof(vortexOrig) == "function" then
		vortexHooked = true
		vortexHookMode = "sync.Fire"
		print("[GFA] Vortex.Sync hooked via", vortexHookMode)
	end
end

local function bindSyncDbg()
	if not Config.AimDebugger or syncDbgConn then
		return
	end
	local sync = vortexSyncRef
	if not sync then
		return
	end
	syncDbgConn = sync.Event:Connect(function(...)
		local args = { ... }
		if args[1] ~= LocalPlayer or typeof(args[4]) ~= "CFrame" then
			return
		end
		dbgCounts.vsync += 1
		print(
			"[GFA-DBG] VSync",
			string.format("#%d %s %s", dbgCounts.vsync, dbgShort(args[6] or args[3]), dbgShortCf(args[4]))
		)
	end)
end

local function resolveVortexSync(): BindableEvent?
	local ps = LocalPlayer:FindFirstChild("PlayerScripts")
	local vortex = ps and ps:FindFirstChild("Vortex")
	local sync = vortex and vortex:FindFirstChild("Sync")
	if sync and sync:IsA("BindableEvent") then
		return sync
	end
	return nil
end

local function tryHookVortexSync()
	if vortexHooked or not Config.SilentAim then
		return
	end
	local sync = resolveVortexSync()
	if not sync then
		return
	end
	vortexSyncRef = sync
	tryHookSyncNamecall()
	if not vortexHooked then
		tryHookSyncFire()
	end
	if vortexHooked then
		bindSyncDbg()
	end
end

local function installNetworkHook(): boolean
	if netHooked or typeof(filtergc) ~= "function" then return false end
	if LocalPlayer:GetAttribute("ClockOffset") == nil then return false end

	local ok, net = pcall(filtergc, "table", { Keys = { "FireServer", "InvokeClient" } }, true)
	if not ok or typeof(net) ~= "table" then return false end

	local oldFire = rawget(net, "FireServer")
	if typeof(oldFire) ~= "function" then return false end

	rawset(net, "FireServer", function(...)
		local args = { ... }
		local eventName = args[2]
		local payload = { table.unpack(args, 3) }

		if Config.SilentAim then
			local part = saFireTarget()
			if eventName == "Fire" and part then
				setMouseHit(part.Position)
				local raw = payload[3]
				local cf = dbgDecode(raw)
				if typeof(cf) == "CFrame" then
					payload[3] = netEncode(net, raw, saAimCf(cf, part))
					if Config.AimDebugger then
						local tgt = if part.Parent then part.Parent.Name else "?"
						print("[GFA-DBG] SA-Fire ->", tgt, dbgShortCf(dbgDecode(payload[3])))
					end
				end
			elseif eventName == "Hitcheck" and part then
				payload = saRewriteHitcheck(net, payload, part)
				if Config.AimDebugger then
					local tgt = if part.Parent then part.Parent.Name else "?"
					print("[GFA-DBG] SA-Hitcheck ->", tgt)
				end
			elseif eventName == "Fire" and Config.AimDebugger then
				print("[GFA-DBG] SA-skip no target")
			end
		end

		if Config.AimDebugger and eventName == "Fire" then
			dbgCounts.fire += 1
			local w, clk, cf = dbgDecode(payload[1]), dbgDecode(payload[2]), dbgDecode(payload[3])
			print("[GFA-DBG] Fire", string.format("#%d %s clk=%s %s", dbgCounts.fire, dbgShort(w), dbgShort(clk), dbgShortCf(cf)))
		elseif Config.AimDebugger and eventName == "Hitcheck" then
			dbgCounts.hit += 1
			local a, b, c, d = dbgDecode(payload[1]), dbgDecode(payload[2]), dbgDecode(payload[3]), dbgDecode(payload[4])
			print("[GFA-DBG] Hitcheck", string.format("#%d %s | %s | %s | %s", dbgCounts.hit, dbgShort(a), dbgShort(b), dbgShort(c), dbgShort(d)))
		end

		if #payload > 0 then
			return oldFire(args[1], eventName, table.unpack(payload))
		end
		return oldFire(table.unpack(args))
	end)

	netHooked = true
	tryHookVortexSync()
	print(
		"[GFA] network hooked via filtergc",
		if Config.SilentAim then "| silent aim" else "",
		if vortexHooked then "| " .. vortexHookMode else "",
		if Config.AimDebugger then "| debugger" else ""
	)
	return true
end

local function ensureNetworkHook()
	if not (Config.SilentAim or Config.AimDebugger) or netHooked or netInstalling then return end
	netInstalling = true
	task.spawn(function()
		for _ = 1, 20 do
			if not (Config.SilentAim or Config.AimDebugger) then break end
			if installNetworkHook() then break end
			task.wait(1)
		end
		netInstalling = false
	end)
end

local function updateCombatNetwork()
	if Config.SilentAim or Config.AimDebugger then
		ensureNetworkHook()
		if netHooked then
			tryHookVortexSync()
			if Config.AimDebugger then
				bindSyncDbg()
			end
		end
	end
end

-- ESP

local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
	if not char.Parent or not root.Parent then
		return nil
	end

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

	local okBb, cf, size = pcall(char.GetBoundingBox, char)
	if not okBb or typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return nil
	end
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
				{
					title = "Silent Aim",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "hint", text = "Redirects Fire CFrame to closest on-screen enemy. No camera move. Uses team check." },
						{ type = "toggle", key = "AimDebugger", label = "Network Debugger", hud = "Net Debug" },
						{ type = "hint", text = "Logs Fire / Hitcheck / SA-Fire. Rejoin after toggling hooks." },
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
	updateCombatNetwork()
end)
RunService:BindToRenderStep("MicroHubGFA_Aim", Enum.RenderPriority.Camera.Value + 1, updateCombatAim)

print("[MicroHub] Gunfight Arena", GAME_BUILD, "— Drawing:", canDraw)
