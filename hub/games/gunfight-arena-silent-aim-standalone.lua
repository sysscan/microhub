--[[
	Gunfight Arena — Silent Aim (standalone reference)
	Build: 29-sa-hooksafe | PlaceIds: 15514727567, 14518422161
	Executor: Volt (hookfunction, filtergc, getgc, newcclosure, checkcaller)

	SHOOT PATH (decompiled Vortex):
	1. Fire() builds bullet CFrame v16
	2. script.Sync:Fire(player, ..., shotCf, velocity, weapon, GetHitables(shotCf), ...)
	   → client hit detection uses shot CFrame + hitables list
	3. INVK("Fire", weapon, clock, serverCf, ...) → Network.FireServer
	   → server CFrame = flame pos + camera look
	4. Server responds; client queues INVK("Hitcheck", ...) from hit results

	SILENT AIM REDIRECTS (no camera movement):
	• Vortex.Sync Fire hook → rewrite args[4] shot CFrame + inject target into args[7] hitables
	• Network.FireServer hook → rewrite Fire payload[3] server CFrame
	• RenderStep → cache closest FOV target in saShotTarget; set MouseHitSpot in 3rd person only

	NEVER require(ReplicatedStorage.Network) — anti-tamper kicks.
	NEVER hook all Sync BindableEvents — only PlayerScripts.Vortex.Sync (SecondThread.Sync is receive-only).
	NEVER run FOV scans / isThirdPerson inside hooks — use saShotTarget cache from render step.

	Rejoin after updating hook build tag.
]]

local BUILD = "29-sa-hooksafe"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
	SilentAim = true,
	AimTeamCheck = true,
	AimFOV = 120,
	AimPart = "Head",
}

local aimFovSq = Config.AimFOV * Config.AimFOV
local saShotTarget: BasePart? = nil
local GREY_TEAM = BrickColor.new("Medium stone grey")

-- ── Volt APIs ─────────────────────────────────────────────────────────────

local function volt(name: string): any
	if typeof(getgenv) == "function" then
		local v = getgenv()[name]
		if v ~= nil then return v end
	end
	return rawget(_G, name)
end

local hookfunction = volt("hookfunction")
local newcclosure = volt("newcclosure")
local filtergc = volt("filtergc")
local getgc = volt("getgc")
local checkcaller = volt("checkcaller")

local function wrapHook(fn: (...any) -> ...any)
	return if typeof(newcclosure) == "function" then newcclosure(fn) else fn
end

local function fromGame(): boolean
	return typeof(checkcaller) ~= "function" or not checkcaller()
end

-- ── Target selection ──────────────────────────────────────────────────────

local function normTeam(v: any): any
	return if v == nil then nil else tonumber(v) or v
end

local function getLocalTeam(): any
	local id = LocalPlayer:GetAttribute("Team")
	if id == nil then
		local rec = Players:FindFirstChild(LocalPlayer.Name)
		id = rec and rec:GetAttribute("Team")
	end
	return if id == nil then nil else normTeam(id)
end

local function getGameMode(): string
	local info = workspace:FindFirstChild("GameInfo")
	local mode = info and info:FindFirstChild("Mode")
	return if mode and mode:IsA("StringValue") then mode.Value else ""
end

local function hasTeamPlay(): boolean
	if getLocalTeam() == nil or LocalPlayer.TeamColor == GREY_TEAM then
		return false
	end
	local mode = getGameMode()
	return mode ~= "VOTE" and mode ~= "END"
end

local function getTeamFor(name: string, char: Model?): any
	local rec = Players:FindFirstChild(name)
	if rec then
		local id = rec:GetAttribute("Team")
		if id ~= nil then return normTeam(id) end
	end
	return if char then normTeam(char:GetAttribute("Team")) else nil
end

local function relation(name: string, char: Model?): string
	if name == LocalPlayer.Name or name == "Skinwalker" then
		return if name == "Skinwalker" then "Enemy" else "Ally"
	end
	if not hasTeamPlay() then return "Enemy" end
	local pt = getTeamFor(name, char)
	if pt == nil then return "Enemy" end
	return if getLocalTeam() == pt then "Ally" else "Enemy"
end

local function getSpawned(): { [string]: Model }
	local out = {}
	for _, rec in Players:GetChildren() do
		if rec.Name == LocalPlayer.Name then continue end
		local char = workspace:FindFirstChild(rec.Name)
		if char and char:IsA("Model") then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				out[rec.Name] = char
			end
		end
	end
	return out
end

local function collectTargets(): { [Model]: string }
	local t: { [Model]: string } = {}
	local function add(name: string?, char: Instance?)
		if not name or name == LocalPlayer.Name or not char or not char:IsA("Model") or t[char] then
			return
		end
		if name == "Skinwalker" or Players:FindFirstChild(name) then
			t[char] = name
		end
	end
	for name, char in getSpawned() do add(name, char) end
	for _, rec in Players:GetChildren() do add(rec.Name, workspace:FindFirstChild(rec.Name)) end
	if getGameMode() == "BOSS" then
		add("Skinwalker", workspace:FindFirstChild("Skinwalker"))
	end
	return t
end

local function aimPart(char: Model): BasePart?
	local p = char:FindFirstChild(Config.AimPart)
	if p and p:IsA("BasePart") then return p end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function aimOrigin(): Vector2
	if UserInputService.MouseEnabled then
		return UserInputService:GetMouseLocation()
	end
	return Camera.ViewportSize * 0.5
end

local function screenDistSq(pos: Vector3, origin: Vector2): number?
	local s, on = Camera:WorldToViewportPoint(pos)
	if not on or s.Z <= 0 then return nil end
	local dx, dy = s.X - origin.X, s.Y - origin.Y
	return dx * dx + dy * dy
end

local function isEligible(char: Model, name: string): boolean
	if not char:IsA("Model") or char == LocalPlayer.Character then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return false end
	if Config.AimTeamCheck and relation(name, char) == "Ally" then return false end
	return true
end

local function closestInFov(origin: Vector2): BasePart?
	local best: BasePart? = nil
	local bestSq = aimFovSq
	for char, name in collectTargets() do
		if not isEligible(char, name) then continue end
		local part = aimPart(char)
		local dsq = part and screenDistSq(part.Position, origin)
		if dsq and dsq < bestSq then
			best, bestSq = part, dsq
		end
	end
	return best
end

local function isThirdPerson(): boolean
	local ps = LocalPlayer:FindFirstChild("PlayerScripts")
	local vortex = ps and ps:FindFirstChild("Vortex")
	local flag = vortex and vortex:FindFirstChild("Modifiers")
	flag = flag and flag:FindFirstChild("IsThirdPerson")
	if flag and flag:IsA("BoolValue") then return flag.Value end
	return LocalPlayer.CameraMinZoomDistance > 1
end

local function setMouseHit(pos: Vector3)
	_G.MouseHitSpot = pos
	if typeof(getgenv) == "function" then
		local env = getgenv()
		if typeof(env) == "table" then env.MouseHitSpot = pos end
	end
end

-- ── Network discovery ─────────────────────────────────────────────────────

local HOOK_BUILD = BUILD
local SESSION_KEY = "__GFA_SA"
local GC_INTERVAL = 6
local HOOK_RETRY = 3
local MAX_ATTEMPTS = 12

local networkHooked = false
local networkOriginal: ((...any) -> ...any)? = nil
local vortexSyncHooked = false
local vortexSyncOriginal: ((...any) -> ...any)? = nil
local cachedApi: any = nil
local cachedRemote: RemoteEvent? = nil
local nextGcScan = 0
local hookGiveUp = false
local hookInstalling = false
local status = "idle"

local function tblGet(t: any, k: string): any
	if typeof(t) ~= "table" then return nil end
	local v = rawget(t, k)
	if v ~= nil then return v end
	local ok, x = pcall(function() return t[k] end)
	return if ok then x else nil
end

local function isCombatRemote(re: RemoteEvent): boolean
	if re:GetFullName():find(LocalPlayer.Name, 1, true) then return true end
	if re:IsDescendantOf(LocalPlayer) then return true end
	local rec = Players:FindFirstChild(LocalPlayer.Name)
	if rec and re:IsDescendantOf(rec) then return true end
	return re:FindFirstAncestorWhichIsA("Player") == LocalPlayer
end

local function isNetworkApi(t: any): boolean
	if typeof(t) ~= "table" then return false end
	if typeof(tblGet(t, "FireServer")) ~= "function" then return false end
	if typeof(tblGet(t, "OnEvent")) ~= "function" then return false end
	if typeof(tblGet(t, "EncodeData")) ~= "function" then return false end
	if typeof(tblGet(t, "DecodeData")) ~= "function" then return false end
	local re = tblGet(t, "RE")
	return typeof(re) == "Instance" and re:IsA("RemoteEvent") and isCombatRemote(re)
end

local function findNetworkApi(): any
	if cachedApi and (cachedRemote == nil or cachedRemote.Parent) then
		return cachedApi
	end
	if LocalPlayer:GetAttribute("ClockOffset") == nil then return nil end
	local now = os.clock()
	if now < nextGcScan then return nil end
	nextGcScan = now + GC_INTERVAL

	local bestApi, bestScore = nil, 0
	local function consider(tbl: any)
		if not isNetworkApi(tbl) then return end
		local re = tblGet(tbl, "RE")
		if typeof(re) ~= "Instance" or not re:IsA("RemoteEvent") then return end
		local score = if isCombatRemote(re) then 100 else 0
		if score > bestScore then bestApi, bestScore = tbl, score end
	end

	if typeof(filtergc) == "function" then
		for _, keys in { { "FireServer", "RE" }, { "FireServer", "OnEvent", "EncodeData", "DecodeData", "RE" } } do
			local ok, tables = pcall(filtergc, "table", { Keys = keys })
			if ok and typeof(tables) == "table" then
				for _, tbl in tables do consider(tbl) end
			end
		end
	end
	if typeof(getgc) == "function" then
		local ok, objs = pcall(getgc, true)
		if ok and typeof(objs) == "table" then
			for _, obj in objs do consider(obj) end
		end
	end

	if bestApi and bestScore >= 90 then
		cachedApi = bestApi
		cachedRemote = tblGet(bestApi, "RE")
		return bestApi
	end

	if typeof(filtergc) == "function" then
		local ok, fns = pcall(filtergc, "function", {
			Constants = { "Client is disconnected from the network" },
			IgnoreExecutor = true,
		})
		if ok and typeof(fns) == "table" and typeof(fns[1]) == "function" then
			cachedApi = { FireServer = fns[1] }
			return cachedApi
		end
	end
	return nil
end

local function maybeDecode(v: any): any
	if typeof(v) ~= "string" or string.sub(v, 1, 1) ~= "~" then return v end
	local codec = game:GetService("ReplicatedStorage"):FindFirstChild("DataCodec")
	if not codec then return v end
	local ok, mod = pcall(require, codec)
	if not ok or typeof(mod) ~= "table" or typeof(mod.AutoDecode) ~= "function" then return v end
	local ok2, out = pcall(mod.AutoDecode, v)
	return if ok2 then out else v
end

local function maybeEncode(sample: any, value: any): any
	if typeof(sample) ~= "string" or string.sub(sample, 1, 1) ~= "~" then return value end
	local encode = cachedApi and tblGet(cachedApi, "EncodeData")
	if typeof(encode) ~= "function" then return value end
	local ok, enc = pcall(function() return encode(cachedApi, value) end)
	if not ok then ok, enc = pcall(encode, value) end
	return if ok then enc else value
end

-- ── Silent aim rewrites (hooks read saShotTarget only — no scans here) ───

local function hookTarget(): BasePart?
	local p = saShotTarget
	return if p and p.Parent then p else nil
end

local function injectHitables(hitables: any, part: BasePart): any
	local model = part.Parent
	if not model or not model:IsA("Model") or typeof(hitables) ~= "table" then
		return hitables
	end
	for _, e in hitables do
		if e == model then return hitables end
	end
	local out = table.create(#hitables + 1)
	for i, e in hitables do out[i] = e end
	out[#out + 1] = model
	return out
end

local function rewriteFirePayload(payload: { any }): { any }
	if not Config.SilentAim then return payload end
	local part = hookTarget()
	if not part then return payload end
	local raw = payload[3]
	local cf = maybeDecode(raw)
	if typeof(cf) ~= "CFrame" then return payload end
	payload[3] = maybeEncode(raw, CFrame.new(cf.Position, part.Position))
	return payload
end

local function rewriteSyncShot(shotCf: CFrame, hitables: any): (CFrame, any)
	if not Config.SilentAim then return shotCf, hitables end
	local part = hookTarget()
	if not part then return shotCf, hitables end
	local newCf = CFrame.new(shotCf.Position, part.Position)
	return newCf, injectHitables(hitables, part)
end

-- ── Hook install ──────────────────────────────────────────────────────────

local function hookVortexSync()
	if vortexSyncHooked or not Config.SilentAim or typeof(hookfunction) ~= "function" then
		return
	end
	local vortex = LocalPlayer:FindFirstChild("PlayerScripts")
	vortex = vortex and vortex:FindFirstChild("Vortex")
	local sync = vortex and vortex:FindFirstChild("Sync")
	if not sync or not sync:IsA("BindableEvent") then return end
	local fireFn = sync.Fire
	if typeof(fireFn) ~= "function" then return end

	local ok = pcall(function()
		vortexSyncOriginal = hookfunction(fireFn, wrapHook(function(self, a1, a2, a3, a4, a5, a6, a7, a8)
			if fromGame() and Config.SilentAim and a1 == LocalPlayer and typeof(a4) == "CFrame" then
				local okR, newCf, newHit = pcall(rewriteSyncShot, a4, a7)
				if okR and typeof(newCf) == "CFrame" then
					a4, a7 = newCf, newHit
				end
			end
			local orig = vortexSyncOriginal
			if typeof(orig) ~= "function" then return end
			return orig(self, a1, a2, a3, a4, a5, a6, a7, a8)
		end))
	end)
	if ok and typeof(vortexSyncOriginal) == "function" then
		vortexSyncHooked = true
	end
end

local function hookNetwork()
	if networkHooked or LocalPlayer:GetAttribute("ClockOffset") == nil then
		return
	end
	local api = findNetworkApi()
	local target = api and tblGet(api, "FireServer")
	if not target or typeof(hookfunction) ~= "function" then return end

	local ok = pcall(function()
		networkOriginal = hookfunction(target, wrapHook(function(self, eventName, ...)
			local args = { ... }
			if fromGame() and Config.SilentAim and eventName == "Fire" then
				local okR, newArgs = pcall(rewriteFirePayload, args)
				if okR and typeof(newArgs) == "table" then args = newArgs end
			end
			local orig = networkOriginal
			if typeof(orig) ~= "function" then return end
			return orig(self, eventName, table.unpack(args))
		end))
	end)
	if ok and typeof(networkOriginal) == "function" then
		networkHooked = true
		status = "ready"
		hookVortexSync()
		print("[GFA-SA]", BUILD, "hooks ready", vortexSyncHooked and "+ Vortex.Sync" or "")
	end
end

local function ensureHooks()
	if not Config.SilentAim or networkHooked or hookGiveUp or hookInstalling then return end
	hookInstalling = true
	task.spawn(function()
		local n = 0
		while Config.SilentAim and not networkHooked and n < MAX_ATTEMPTS do
			n += 1
			hookNetwork()
			if not networkHooked then task.wait(HOOK_RETRY) end
		end
		if not networkHooked then
			hookGiveUp = true
			status = "failed — rejoin"
			warn("[GFA-SA] hook install failed")
		end
		hookInstalling = false
	end)
end

-- ── Per-frame target cache ────────────────────────────────────────────────

local function onFrame()
	if not Config.SilentAim then
		saShotTarget = nil
		return
	end
	ensureHooks()
	if networkHooked then hookVortexSync() end

	local part = closestInFov(aimOrigin())
	saShotTarget = if part and part.Parent then part else nil

	if saShotTarget and isThirdPerson() then
		setMouseHit(saShotTarget.Position)
	end
end

RunService:BindToRenderStep("GFA_SilentAim", Enum.RenderPriority.Camera.Value, onFrame)

print("[GFA-SA] loaded", BUILD, "— set Config.SilentAim = true, rejoin after updates")
