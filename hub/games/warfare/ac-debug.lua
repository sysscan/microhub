--[[
	Warfare AC debug — game-integrated combat pipeline logger.
	Taps BridgeNet bridges from WeaponClient / BulletSimulator, correlates
	FireBullet → HitPlayer → HitConfirm, and watches Framework remotes.
	Lazy install when DebugAC is enabled; no hookfunction on BridgeNet internals.
]]

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local M = {}

-- Bridges used by WeaponClient + BulletSimulator (decompile-confirmed)
local COMBAT_OUT = { "FireBullet", "HitPlayer", "WeaponAction", "ReplicateBullet", "Launcher" }
local COMBAT_IN = { "HitConfirm", "AdvancedDamage", "MessageEvent" }
local OTHER_OUT = {
	"SuppressorState", "Supression", "Sound", "MedicineEvent", "HolsterServer",
	"Grenade", "AmmoBox", "LaserState", "LoadData", "LoadGuns",
}
local OTHER_IN = { "FallDamage", "HeadMovement", "DroneEvent", "GlassShatter" }

local GAME_LOG_PATTERNS = {
	"invalid packet",
	"invalid firerate",
	"equip error",
	"likely exploiter",
	"handleinvalidplayer",
	"reject",
	"violation",
	"anticheat",
}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local ReplicatedStorage = opts.replicatedStorage
	local hitRate = opts.hitRate
	local getRecentHitRatio = hitRate.getRecentHitRatio
	local hitRateRecentHits = hitRate.recentHits
	local hitRateRecentShots = hitRate.recentShots
	local HIT_RATE_WINDOW = hitRate.hitRateWindow

	local TAG = "[WarfareAC]"
	local LOG_MAX = 300
	local REMOTE_COOLDOWN = 1.5
	local OVERLAY_INTERVAL = 0.35
	local SHOT_MATCH_WINDOW = 3
	local SHOT_MAX_PENDING = 40

	local log = {}
	local seq = 0
	local conns = {}
	local remoteLastLog = {}
	local bridgeTaps = {}
	local bridgeInboundConns = {}
	local overlayGui = nil
	local overlayLabel = nil
	local hooksReady = false
	local bridgesInstalled = false
	local logConn = nil
	local overlayDirty = false
	local lastOverlayAt = 0
	local lastLogDedupe = {}
	local shotSeq = 0
	local pendingShots = {}
	local pipelineStats = {
		fireBullet = 0,
		hitPlayer = 0,
		hitConfirm = 0,
		orphanHitPlayer = 0,
		orphanConfirm = 0,
		rejectedShots = 0,
		secureSettingsCalls = 0,
	}

	local function kindOf(value)
		return if typeof then typeof(value) else type(value)
	end

	local function vec3(v)
		if kindOf(v) ~= "Vector3" then
			return "?"
		end
		return string.format("(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
	end

	local function cfPos(cf)
		if kindOf(cf) ~= "CFrame" then
			return "?"
		end
		return vec3(cf.Position)
	end

	local function playerLabel(userId)
		if kindOf(userId) ~= "number" then
			return tostring(userId)
		end
		local plr = Players:GetPlayerByUserId(userId)
		return if plr then plr.Name else ("uid:" .. userId)
	end

	local function serialize(value, depth)
		depth = depth or 0
		if depth > 2 then
			return "<deep>"
		end
		local kind = kindOf(value)
		if kind == "nil" or kind == "boolean" or kind == "number" then
			return tostring(value)
		end
		if kind == "string" then
			if #value > 64 then
				return string.format("%q..", value:sub(1, 64))
			end
			return string.format("%q", value)
		end
		if kind == "Instance" then
			return value:GetFullName()
		end
		if kind == "Vector3" then
			return vec3(value)
		end
		if kind == "CFrame" then
			return "CF" .. cfPos(value)
		end
		if kind == "table" then
			local parts = {}
			local count = 0
			for key, entry in value do
				count += 1
				if count > 6 then
					table.insert(parts, "...")
					break
				end
				table.insert(parts, tostring(key) .. "=" .. serialize(entry, depth + 1))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
		return "<" .. kind .. ">"
	end

	local function matchesGameLog(text)
		local lower = string.lower(text)
		for _, pattern in GAME_LOG_PATTERNS do
			if lower:find(pattern, 1, true) then
				return true
			end
		end
		return false
	end

	local function refreshOverlay()
		if not Config.DebugOverlay or not overlayLabel then
			return
		end
		local now = tick()
		if not overlayDirty or now - lastOverlayAt < OVERLAY_INTERVAL then
			return
		end
		overlayDirty = false
		lastOverlayAt = now
		local lines = {
			string.format(
				"FB:%d HP:%d HC:%d rej:%d ratio:%.2f",
				pipelineStats.fireBullet,
				pipelineStats.hitPlayer,
				pipelineStats.hitConfirm,
				pipelineStats.rejectedShots,
				getRecentHitRatio()
			),
		}
		for index = math.max(1, #log - 5), #log do
			local row = log[index]
			table.insert(lines, string.format("%s %s", row.category, row.message:sub(1, 72)))
		end
		overlayLabel.Text = table.concat(lines, "\n")
	end

	local function push(category, message, force)
		if not Config.DebugAC and not force then
			return
		end

		seq += 1
		table.insert(log, { seq = seq, t = tick(), category = category, message = message })
		while #log > LOG_MAX do
			table.remove(log, 1)
		end

		local loud = force
			or category == "KICK"
			or category == "ACLOG"
			or category == "REJECT"
			or category == "BOOT"
			or category == "PIPE"
		if loud then
			warn(TAG, string.format("[%s] %s", category, message))
		end

		if Config.DebugOverlay then
			overlayDirty = true
			refreshOverlay()
		end
	end

	local function formatFireBullet(p)
		if kindOf(p) ~= "table" then
			return serialize(p)
		end
		return string.format(
			"type=%s seed=%s fireTime=%s speed=%.0f muzzle=%s",
			tostring(p.BulletType or p.bulletType or "?"),
			tostring(p.seed or "?"),
			tostring(p.fireTime or "?"),
			tonumber(p.bulletSpeed) or 0,
			cfPos(p.muzzleCF)
		)
	end

	local function formatHitPlayer(p)
		if kindOf(p) ~= "table" then
			return serialize(p)
		end
		return string.format(
			"target=%s part=%s dist=%.0f speed=%.0f type=%s hit=%s",
			playerLabel(p.hitUserId),
			tostring(p.hitPartName or "?"),
			tonumber(p.distanceTraveled) or 0,
			tonumber(p.velocityMagnitude or p.bulletSpeed) or 0,
			tostring(p.bulletType or "?"),
			vec3(p.hitPosition)
		)
	end

	local function formatHitConfirm(p)
		if kindOf(p) ~= "table" then
			return serialize(p)
		end
		return string.format(
			"dmg=%s head=%s target=%s pos=%s",
			tostring(p.damage or "?"),
			tostring(p.isHeadshot),
			playerLabel(p.hitUserId or p.userId or p.targetUserId or p.victimUserId),
			vec3(p.hitPosition)
		)
	end

	local function registerPendingShot(firePayload, meta)
		shotSeq += 1
		local entry = {
			id = shotSeq,
			t = tick(),
			fireTime = firePayload and firePayload.fireTime,
			bulletType = firePayload and (firePayload.BulletType or firePayload.bulletType),
			muzzle = firePayload and firePayload.muzzleCF and firePayload.muzzleCF.Position,
			redirected = meta and meta.redirected,
			hubAim = meta and meta.hubAim,
			hitPlayer = false,
			confirmed = false,
		}
		table.insert(pendingShots, entry)
		while #pendingShots > SHOT_MAX_PENDING do
			table.remove(pendingShots, 1)
		end
		return entry
	end

	local function mergeFireBullet(firePayload)
		local now = tick()
		for index = #pendingShots, 1, -1 do
			local shot = pendingShots[index]
			if now - shot.t < 0.2 and not shot.fireTime then
				shot.fireTime = firePayload.fireTime
				shot.bulletType = firePayload.BulletType or firePayload.bulletType
				shot.muzzle = firePayload.muzzleCF and firePayload.muzzleCF.Position
				return shot
			end
		end
		return registerPendingShot(firePayload, nil)
	end

	local function findPendingShot(fireTime, bulletType)
		local now = tick()
		local newestOpen = nil
		for index = #pendingShots, 1, -1 do
			local shot = pendingShots[index]
			if now - shot.t > SHOT_MATCH_WINDOW then
				continue
			end
			if shot.confirmed then
				continue
			end
			if fireTime and shot.fireTime and shot.fireTime == fireTime then
				return shot
			end
			if bulletType and shot.bulletType and shot.bulletType == bulletType and not shot.hitPlayer then
				return shot
			end
			if not newestOpen or shot.t > newestOpen.t then
				newestOpen = shot
			end
		end
		return newestOpen
	end

	local function onBridgeOutbound(name, payload)
		if not Config.DebugAC or not Config.DebugBridgeNet then
			return
		end

		if name == "FireBullet" then
			pipelineStats.fireBullet += 1
			mergeFireBullet(payload)
			push("FIRE", formatFireBullet(payload))
			return
		end

		if name == "HitPlayer" then
			pipelineStats.hitPlayer += 1
			local shot = findPendingShot(payload and payload.fireTime, payload and payload.bulletType)
			if shot then
				shot.hitPlayer = true
			else
				pipelineStats.orphanHitPlayer += 1
				push("PIPE", "HitPlayer without matching FireBullet", true)
			end
			push("HIT→", formatHitPlayer(payload))
			return
		end

		push("BR→", name .. " " .. serialize(payload))
	end

	local function onBridgeInbound(name, payload)
		if not Config.DebugAC or not Config.DebugBridgeNet then
			return
		end

		if name == "HitConfirm" then
			pipelineStats.hitConfirm += 1
			local shot = findPendingShot(payload and payload.fireTime, nil)
			if shot then
				shot.confirmed = true
				local lag = tick() - shot.t
				push(
					"HIT✓",
					string.format(
						"%s lag=%.2fs hub=%s ratio=%.2f",
						formatHitConfirm(payload),
						lag,
						tostring(shot.hubAim),
						getRecentHitRatio()
					)
				)
			else
				pipelineStats.orphanConfirm += 1
				push("HIT✓", formatHitConfirm(payload) .. " (unmatched)", true)
			end
			return
		end

		if name == "MessageEvent" and kindOf(payload) == "table" then
			local text = tostring(payload.Text or payload.text or payload.message or "")
			if text ~= "" and (matchesGameLog(text) or Config.DebugVerbose) then
				push("MSG", text, matchesGameLog(text))
			end
			return
		end

		push("BR←", name .. " " .. serialize(payload))
	end

	local function tapBridgeFire(bridgeName, bridge)
		if not bridge or bridgeTaps[bridge] then
			return
		end

		-- Use BridgeNet OutboundMiddleware — replacing bridge.Fire breaks ClientBridge:Fire checks.
		if typeof(bridge.OutboundMiddleware) == "function" then
			local middlewareFn = function(payload)
				pcall(onBridgeOutbound, bridgeName, payload)
				return payload
			end
			local prevMiddleware = bridge._outboundMiddleware
			local combined = { middlewareFn }
			if typeof(prevMiddleware) == "table" then
				for _, fn in prevMiddleware do
					table.insert(combined, fn)
				end
			end
			bridge:OutboundMiddleware(combined)
			bridgeTaps[bridge] = {
				name = bridgeName,
				prevMiddleware = prevMiddleware,
			}
			return
		end

		if typeof(bridge.Fire) ~= "function" then
			return
		end
		local oldFire = bridge.Fire
		bridgeTaps[bridge] = { name = bridgeName, oldFire = oldFire }
		function bridge.Fire(self, payload, ...)
			pcall(onBridgeOutbound, bridgeName, payload)
			return oldFire(self, payload, ...)
		end
	end

	local function listenBridge(bridgeName, bridge)
		if not bridge or typeof(bridge.Connect) ~= "function" then
			return
		end
		local conn = bridge:Connect(function(payload, ...)
			pcall(onBridgeInbound, bridgeName, payload)
		end)
		table.insert(bridgeInboundConns, conn)
	end

	local function restoreBridgeTaps()
		for bridge, tap in bridgeTaps do
			if tap.oldFire then
				bridge.Fire = tap.oldFire
			elseif tap.name then
				bridge._outboundMiddleware = tap.prevMiddleware
			end
		end
		table.clear(bridgeTaps)
	end

	local function uninstallGameBridges()
		if not bridgesInstalled then
			return
		end
		restoreBridgeTaps()
		for _, conn in bridgeInboundConns do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(bridgeInboundConns)
		bridgesInstalled = false
	end

	local function installGameBridges(bridgeNet)
		if bridgesInstalled or not bridgeNet or typeof(bridgeNet.ReferenceBridge) ~= "function" then
			return
		end
		if not Config.DebugAC then
			return
		end
		bridgesInstalled = true

		local function ref(name)
			local ok, bridge = pcall(function()
				return bridgeNet.ReferenceBridge(name)
			end)
			if ok and bridge then
				return bridge
			end
			return nil
		end

		for _, name in COMBAT_OUT do
			tapBridgeFire(name, ref(name))
		end
		for _, name in OTHER_OUT do
			if Config.DebugVerbose then
				tapBridgeFire(name, ref(name))
			end
		end

		for _, name in COMBAT_IN do
			listenBridge(name, ref(name))
		end
		for _, name in OTHER_IN do
			if Config.DebugVerbose then
				listenBridge(name, ref(name))
			end
		end

		push(
			"BOOT",
			string.format(
				"Game bridges tapped (out=%d in=%d)",
				#COMBAT_OUT + (Config.DebugVerbose and #OTHER_OUT or 0),
				#COMBAT_IN + (Config.DebugVerbose and #OTHER_IN or 0)
			),
			true
		)
	end

	local function isFrameworkRemote(remote)
		local path = remote:GetFullName()
		return path:find("ReplicatedStorage.Framework", 1, true) == 1
			or path:find("ReplicatedStorage.Game", 1, true) == 1
	end

	local function logFrameworkRemote(direction, remote, args)
		if not Config.DebugAC or not Config.DebugRemotes then
			return
		end
		if not isFrameworkRemote(remote) then
			return
		end

		local now = tick()
		local path = remote:GetFullName()
		local logKey = direction .. "|" .. path
		local last = remoteLastLog[logKey]
		if last and now - last < REMOTE_COOLDOWN and not Config.DebugVerbose then
			return
		end
		remoteLastLog[logKey] = now

		if remote.Name == "GetSecureSettings" and direction == "OUT" then
			pipelineStats.secureSettingsCalls += 1
			push("SECURE", "InvokeServer gun=" .. serialize(args[1]))
			return
		end

		push("REMOTE", string.format("%s %s | %s", direction, path, serialize(args[1])))
	end

	local function logKick(source, args)
		if not Config.DebugAC or not Config.DebugKicks then
			return
		end
		push("KICK", source .. " | " .. serialize(args[1]), true)
	end

	local function onHitConfirm(payload)
		if not Config.DebugAC or not Config.DebugHits then
			return
		end
		-- Inbound detail logged by bridge listener; this hook is for init.lua hit-rate + markers
	end

	local function onSimulateShot(meta)
		if not Config.DebugAC or not Config.DebugHits then
			return
		end

		registerPendingShot(nil, meta)

		if Config.DebugVerbose or meta.redirected or meta.bulletTp then
			push(
				"SHOT",
				string.format(
					"redirect=%s tp=%s aim=%s part=%s type=%s muzzle=%s ratio=%.2f hs=%.2f",
					tostring(meta.redirected),
					tostring(meta.bulletTp),
					tostring(meta.hubAim),
					tostring(meta.aimPart or "?"),
					tostring(meta.bulletType or "?"),
					cfPos(meta.muzzleCF),
					getRecentHitRatio(),
					if hitRate.getRecentHeadshotRatio then hitRate.getRecentHeadshotRatio() else 0
				)
			)
		end
	end

	local oldNamecall = nil

	local function installNamecallHook()
		if oldNamecall or typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
			return
		end

		local wrap = newcclosure
		if typeof(wrap) ~= "function" then
			wrap = function(fn)
				return fn
			end
		end

		oldNamecall = hookmetamethod(
			game,
			"__namecall",
			wrap(function(self, ...)
				if not Config.DebugAC then
					return oldNamecall(self, ...)
				end
				if typeof(checkcaller) == "function" and checkcaller() then
					return oldNamecall(self, ...)
				end

				local method = getnamecallmethod()
				local shouldLogRemote = Config.DebugRemotes
					and (method == "FireServer" or method == "InvokeServer")
				local shouldLogKick = Config.DebugKicks
					and (
						(method == "Kick" and self == LocalPlayer)
						or (
							(method == "Teleport" or method == "TeleportToPlaceInstance")
							and self == TeleportService
						)
					)

				if not shouldLogRemote and not shouldLogKick then
					return oldNamecall(self, ...)
				end

				local args = { ... }

				-- InvokeServer must complete before any logging; IsA during namecall breaks some executors.
				local results = { oldNamecall(self, table.unpack(args)) }

				pcall(function()
					if shouldLogRemote then
						local isRemote = false
						pcall(function()
							isRemote = self:IsA("RemoteEvent")
								or self:IsA("RemoteFunction")
								or self:IsA("UnreliableRemoteEvent")
						end)
						if isRemote and isFrameworkRemote(self) then
							logFrameworkRemote("OUT", self, args)
						end
					elseif shouldLogKick then
						if method == "Kick" and self == LocalPlayer then
							logKick("LocalPlayer:Kick", args)
						else
							logKick("TeleportService:" .. method, args)
						end
					end
				end)

				return table.unpack(results)
			end)
		)
	end

	local function installLogHook()
		if logConn then
			return
		end
		logConn = LogService.MessageOut:Connect(function(message, messageType)
			if not Config.DebugAC then
				return
			end
			local text = tostring(message)
			local isError = messageType == Enum.MessageType.MessageError
			if not isError and not matchesGameLog(text) then
				return
			end
			local dedupeKey = tostring(messageType) .. "|" .. text
			local now = tick()
			local last = lastLogDedupe[dedupeKey]
			if last and now - last < 2 then
				return
			end
			lastLogDedupe[dedupeKey] = now

			local category = if matchesGameLog(text) then "ACLOG" else "LOG"
			if text:lower():find("invalid packet", 1, true) then
				pipelineStats.rejectedShots += 1
				category = "REJECT"
			end
			push(category, text, category == "ACLOG" or category == "REJECT")
		end)
		table.insert(conns, logConn)
	end

	local function ensureHooks()
		if hooksReady then
			return
		end
		hooksReady = true
		installNamecallHook()
		installLogHook()
	end

	local function ensureOverlay()
		if overlayGui then
			overlayGui.Enabled = Config.DebugAC and Config.DebugOverlay
			return
		end
		local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
		overlayGui = Instance.new("ScreenGui")
		overlayGui.Name = "MicroHub_WarfareACDebug"
		overlayGui.ResetOnSpawn = false
		overlayGui.IgnoreGuiInset = true
		overlayGui.DisplayOrder = 1000
		overlayGui.Parent = playerGui

		overlayLabel = Instance.new("TextLabel")
		overlayLabel.Name = "Log"
		overlayLabel.BackgroundTransparency = 0.35
		overlayLabel.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
		overlayLabel.TextColor3 = Color3.fromRGB(220, 230, 240)
		overlayLabel.TextStrokeTransparency = 0.5
		overlayLabel.Font = Enum.Font.Code
		overlayLabel.TextSize = 12
		overlayLabel.TextXAlignment = Enum.TextXAlignment.Left
		overlayLabel.TextYAlignment = Enum.TextYAlignment.Top
		overlayLabel.Size = UDim2.new(0, 560, 0, 160)
		overlayLabel.Position = UDim2.fromOffset(8, 8)
		overlayLabel.TextWrapped = true
		overlayLabel.Parent = overlayGui
		overlayGui.Enabled = Config.DebugAC and Config.DebugOverlay
	end

	local function ensureOverlayLoop()
		if overlayConn then
			return
		end
		overlayConn = RunService.Heartbeat:Connect(function()
			if Config.DebugAC and Config.DebugOverlay and overlayDirty then
				refreshOverlay()
			end
		end)
		table.insert(conns, overlayConn)
	end

	local overlayConn = nil

	local function findDescendantByName(root, name)
		if not root then
			return nil
		end
		for _, descendant in root:GetDescendants() do
			if descendant.Name == name then
				return descendant
			end
		end
		return nil
	end

	local function scanGameSurfaces()
		push("SCAN", "Warfare security surfaces", true)

		local paths = {
			"ReplicatedStorage.Framework.Modules.BridgeNet2.src.Server.HandleInvalidPlayer",
			"ReplicatedStorage.Framework.Modules.BulletSimulator",
			"ReplicatedStorage.Framework.Modules.MagazineController",
			"ReplicatedStorage.Framework.Remotes.GetSecureSettings",
		}
		for _, path in paths do
			local inst = game
			for part in string.gmatch(path, "[^%.]+") do
				inst = inst and inst:FindFirstChild(part)
			end
			push("SCAN", path .. " → " .. (if inst then inst.ClassName else "MISSING"), true)
		end

		local gameRoot = ReplicatedStorage:FindFirstChild("Game")
		local teams = findDescendantByName(gameRoot, "TeamsService")
		local packets = findDescendantByName(gameRoot, "Packets")
		push(
			"SCAN",
			"TeamsService → " .. (if teams then teams:GetFullName() else "MISSING"),
			true
		)
		push(
			"SCAN",
			"Packets → " .. (if packets then packets:GetFullName() else "MISSING"),
			true
		)

		local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local weaponClient = playerScripts and findDescendantByName(playerScripts, "WeaponClient")
		push(
			"SCAN",
			"WeaponClient → " .. (if weaponClient then weaponClient:GetFullName() else "MISSING"),
			true
		)

		return paths
	end

	local function requireBridgeNet()
		local framework = ReplicatedStorage:FindFirstChild("Framework")
		local modules = framework and framework:FindFirstChild("Modules")
		local bridgeMod = modules and modules:FindFirstChild("BridgeNet2")
		if not bridgeMod then
			return nil
		end
		local ok, bridgeNet = pcall(require, bridgeMod)
		if ok then
			return bridgeNet
		end
		return nil
	end

	local function sync()
		if Config.DebugAC then
			ensureHooks()
			installGameBridges(requireBridgeNet())
			ensureOverlay()
			ensureOverlayLoop()
			if overlayGui then
				overlayGui.Enabled = Config.DebugOverlay
			end
		else
			uninstallGameBridges()
			if overlayGui then
				overlayGui.Enabled = false
			end
		end
	end

	local function install()
		if Config.DebugAC then
			sync()
		end
	end

	local function printLog()
		push("DUMP", "Printing " .. #log .. " entries", true)
		for _, entry in ipairs(log) do
			warn(TAG, string.format("%d [%.2f] [%s] %s", entry.seq, entry.t, entry.category, entry.message))
		end
	end

	local function clearLog()
		table.clear(log)
		seq = 0
		overlayDirty = false
		if overlayLabel then
			overlayLabel.Text = ""
		end
		push("DUMP", "Log cleared", true)
	end

	local function dumpHitStats()
		local headRatio = if hitRate.getRecentHeadshotRatio then hitRate.getRecentHeadshotRatio() else 0
		push(
			"STAT",
			string.format(
				"hub hits=%d shots=%d ratio=%.2f hs=%.2f | pipeline FB=%d HP=%d HC=%d orphanHP=%d orphanHC=%d reject=%d secure=%d",
				#hitRateRecentHits,
				#hitRateRecentShots,
				getRecentHitRatio(),
				headRatio,
				pipelineStats.fireBullet,
				pipelineStats.hitPlayer,
				pipelineStats.hitConfirm,
				pipelineStats.orphanHitPlayer,
				pipelineStats.orphanConfirm,
				pipelineStats.rejectedShots,
				pipelineStats.secureSettingsCalls
			),
			true
		)
	end

	local function dumpPipeline()
		dumpHitStats()
		local open = 0
		for _, shot in pendingShots do
			if not shot.confirmed then
				open += 1
			end
		end
		push("PIPE", string.format("pending unmatched shots=%d / %d", open, #pendingShots), true)
	end

	local function unload()
		uninstallGameBridges()
		for _, conn in ipairs(conns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(conns)
		logConn = nil
		overlayConn = nil
		hooksReady = false
		if overlayGui then
			overlayGui:Destroy()
			overlayGui = nil
			overlayLabel = nil
		end
		table.clear(remoteLastLog)
		table.clear(lastLogDedupe)
		table.clear(pendingShots)
	end

	local genv = if typeof(getgenv) == "function" then getgenv() else _G
	genv.__WarfareACLog = log
	genv.__WarfareACDump = printLog
	genv.__WarfareACStats = pipelineStats

	return {
		sync = sync,
		install = install,
		installGameBridges = installGameBridges,
		onHitConfirm = onHitConfirm,
		onSimulateShot = onSimulateShot,
		push = push,
		scanGameSurfaces = scanGameSurfaces,
		dumpPipeline = dumpPipeline,
		printLog = printLog,
		clearLog = clearLog,
		dumpHitStats = dumpHitStats,
		conns = conns,
		unload = unload,
	}
end

return M
