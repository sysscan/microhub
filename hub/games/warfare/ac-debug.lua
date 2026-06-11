--[[
	Warfare AC debug — passive logging with lazy hooks.
	Designed to stay off the hot path unless DebugAC is enabled.
]]

local LogService = game:GetService("LogService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local M = {}

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
	local LOG_MAX = 250
	local REMOTE_COOLDOWN = 2
	local OVERLAY_INTERVAL = 0.35
	local LOG_PRUNE_INTERVAL = 30

	local KEYWORDS = {
		"kick", "ban", "cheat", "anticheat", "anti", "invalid", "hit", "rate", "exploit",
		"detect", "flag", "violation", "sanity", "validate", "reject", "security", "ac_",
	}

	local BRIDGE_GUESSES = {
		"HitConfirm", "Damage", "Hit", "Fire", "Bullet", "AntiCheat", "AC", "Kick", "Ban",
		"Report", "Validate", "Sanity", "Cheat", "Flag", "Violation", "HitRate", "Combat",
		"Weapon", "Shoot", "Kill", "Death", "Replication", "Replicate",
	}

	local IGNORE_REMOTE_NAMES = {
		PingCheck = true,
		dataRemoteEvent = true,
	}

	local log = {}
	local seq = 0
	local conns = {}
	local remoteLastLog = {}
	local knownBridges = {}
	local bridgeNetRef = nil
	local overlayGui = nil
	local overlayLabel = nil
	local hooksReady = false
	local logConn = nil
	local overlayDirty = false
	local lastOverlayAt = 0
	local lastLogPruneAt = 0

	local function kindOf(value)
		return if typeof then typeof(value) else type(value)
	end

	local function matchesKeywords(text)
		local lower = string.lower(text)
		for _, keyword in KEYWORDS do
			if lower:find(keyword, 1, true) then
				return true
			end
		end
		return false
	end

	local function shouldWatchRemote(remote)
		if not remote or not remote:IsA("Instance") then
			return false
		end
		if IGNORE_REMOTE_NAMES[remote.Name] then
			return false
		end
		local fullName = remote:GetFullName()
		if fullName:find("RobloxReplicatedStorage", 1, true) then
			return false
		end
		if fullName:find("BridgeNet2", 1, true) and remote.Name == "dataRemoteEvent" then
			return false
		end
		if not Config.DebugVerbose and fullName:find("ReplicatedStorage.Game.", 1, true) then
			return false
		end
		if Config.DebugFilterOnly then
			return matchesKeywords(fullName .. " " .. remote.Name)
		end
		return true
	end

	local function serialize(value, depth)
		depth = depth or 0
		if depth > 3 then
			return "<deep>"
		end
		local kind = kindOf(value)
		if kind == "nil" or kind == "boolean" or kind == "number" then
			return tostring(value)
		end
		if kind == "string" then
			if #value > 96 then
				return string.format("%q...", value:sub(1, 96))
			end
			return string.format("%q", value)
		end
		if kind == "Instance" then
			return value:GetFullName()
		end
		if kind == "Vector3" then
			return string.format("V3(%.1f,%.1f,%.1f)", value.X, value.Y, value.Z)
		end
		if kind == "Vector2" then
			return string.format("V2(%.1f,%.1f)", value.X, value.Y)
		end
		if kind == "CFrame" then
			local p = value.Position
			return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
		end
		if kind == "EnumItem" then
			return tostring(value)
		end
		if kind == "table" then
			local parts = {}
			local count = 0
			for key, entry in value do
				count += 1
				if count > 8 then
					table.insert(parts, "...")
					break
				end
				table.insert(parts, tostring(key) .. "=" .. serialize(entry, depth + 1))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
		return "<" .. kind .. ">"
	end

	local function serializeArgs(args)
		local parts = {}
		local limit = math.min(args.n or #args, 8)
		for index = 1, limit do
			table.insert(parts, serialize(args[index]))
		end
		if (args.n or #args) > limit then
			table.insert(parts, "...")
		end
		return table.concat(parts, ", ")
	end

	local function pruneRemoteLogCache(now)
		if now - lastLogPruneAt < LOG_PRUNE_INTERVAL then
			return
		end
		lastLogPruneAt = now
		for key, when in remoteLastLog do
			if now - when > 60 then
				remoteLastLog[key] = nil
			end
		end
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
		local lines = {}
		for index = math.max(1, #log - 7), #log do
			local row = log[index]
			table.insert(lines, string.format("%d %s: %s", row.seq, row.category, row.message))
		end
		overlayLabel.Text = table.concat(lines, "\n")
	end

	local function push(category, message, force)
		if not Config.DebugAC and not force then
			return
		end
		if Config.DebugFilterOnly and not force and not matchesKeywords(category .. " " .. message) then
			return
		end

		seq += 1
		table.insert(log, {
			seq = seq,
			t = tick(),
			category = category,
			message = message,
		})
		while #log > LOG_MAX do
			table.remove(log, 1)
		end

		local loud = force
			or category == "KICK"
			or category == "BOOT"
			or category == "PROBE"
			or category == "DUMP"
		if loud then
			warn(TAG, string.format("[%s] %s", category, message))
		end

		if Config.DebugOverlay then
			overlayDirty = true
			refreshOverlay()
		end
	end

	local function remotePath(remote)
		if remote and remote:IsA("Instance") then
			return remote:GetFullName()
		end
		return tostring(remote)
	end

	local function logRemote(direction, remote, args)
		if not Config.DebugAC or not Config.DebugRemotes then
			return
		end
		if not shouldWatchRemote(remote) then
			return
		end

		local now = tick()
		pruneRemoteLogCache(now)
		local path = remotePath(remote)
		local logKey = tostring(direction) .. "|" .. path
		if not Config.DebugVerbose then
			local last = remoteLastLog[logKey]
			if last and now - last < REMOTE_COOLDOWN then
				return
			end
			remoteLastLog[logKey] = now
		end

		local ok, err = pcall(function()
			local packed = table.pack(unpack(args))
			push("REMOTE", string.format("%s %s | %s", direction, path, serializeArgs(packed)))
		end)
		if not ok then
			push("REMOTE", "log error: " .. tostring(err), true)
		end
	end

	local function logKick(source, args)
		if not Config.DebugAC or not Config.DebugKicks then
			return
		end
		local packed = table.pack(unpack(args))
		push("KICK", string.format("%s | %s", source, serializeArgs(packed)), true)
	end

	local function onHitConfirm(payload)
		if not Config.DebugAC or not Config.DebugHits then
			return
		end
		push(
			"HIT",
			string.format(
				"HitConfirm %s | hits=%d shots=%d ratio=%.2f",
				serialize(payload),
				#hitRateRecentHits,
				#hitRateRecentShots,
				getRecentHitRatio()
			)
		)
	end

	local function onShot(redirectAim)
		if not Config.DebugAC or not Config.DebugHits or not Config.DebugVerbose then
			return
		end
		push(
			"SHOT",
			string.format(
				"redirect=%s ratio=%.2f hits=%d shots=%d",
				tostring(redirectAim),
				getRecentHitRatio(),
				#hitRateRecentHits,
				#hitRateRecentShots
			)
		)
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
				if Config.DebugAC then
					local method = getnamecallmethod()
					if typeof(checkcaller) == "function" and checkcaller() then
						return oldNamecall(self, ...)
					end
					if Config.DebugRemotes and (method == "FireServer" or method == "InvokeServer") then
						if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent") then
							logRemote("OUT", self, { ... })
						end
					elseif Config.DebugKicks then
						if method == "Kick" and self == LocalPlayer then
							logKick("LocalPlayer:Kick", { ... })
						elseif (method == "Teleport" or method == "TeleportToPlaceInstance") and self == TeleportService then
							logKick("TeleportService:" .. method, { ... })
						end
					end
				end
				return oldNamecall(self, ...)
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
			if messageType == Enum.MessageType.MessageError or matchesKeywords(message) then
				push("LOG", tostring(messageType) .. " | " .. message)
			end
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
		push("BOOT", "AC debug hooks installed", true)
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
		overlayLabel.TextSize = 13
		overlayLabel.TextXAlignment = Enum.TextXAlignment.Left
		overlayLabel.TextYAlignment = Enum.TextYAlignment.Top
		overlayLabel.Size = UDim2.new(0, 520, 0, 150)
		overlayLabel.Position = UDim2.fromOffset(8, 8)
		overlayLabel.TextWrapped = true
		overlayLabel.Parent = overlayGui
		overlayGui.Enabled = Config.DebugAC and Config.DebugOverlay
	end

	local overlayConn = nil
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

	local function scanRemotes(logEach, _hookIncoming)
		local remotes = {}
		for _, descendant in ipairs(game:GetDescendants()) do
			if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") or descendant:IsA("UnreliableRemoteEvent") then
				if shouldWatchRemote(descendant) then
					table.insert(remotes, descendant)
				end
			end
		end
		table.sort(remotes, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)
		if logEach then
			push("SCAN", "Found " .. #remotes .. " remotes (list only — no incoming hooks)", true)
			for _, remote in ipairs(remotes) do
				push("SCAN", remote.ClassName .. " " .. remote:GetFullName(), true)
			end
		end
		return remotes
	end

	local function scanSuspiciousModules()
		local hits = {}
		for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
			if descendant:IsA("ModuleScript") then
				local lower = string.lower(descendant.Name)
				if lower:find("anticheat", 1, true)
					or (lower:find("anti", 1, true) and lower:find("cheat", 1, true))
					or lower:find("validate", 1, true)
					or lower:find("security", 1, true)
					or lower:find("sanity", 1, true)
					or lower:find("kick", 1, true)
					or lower:find("exploit", 1, true)
				then
					table.insert(hits, descendant:GetFullName())
				end
			end
		end
		table.sort(hits)
		push("SCAN", "Suspicious modules: " .. #hits, true)
		for _, path in ipairs(hits) do
			push("SCAN", path, true)
		end
		return hits
	end

	local function installBridgeNet(bridgeNet)
		if bridgeNet then
			bridgeNetRef = bridgeNet
		end
	end

	local function wrapBridge(bridgeName, bridge)
		if bridge and not knownBridges[bridge] then
			knownBridges[bridge] = bridgeName
		end
	end

	local function probeBridges(bridgeNet)
		if not bridgeNet or typeof(bridgeNet.ReferenceBridge) ~= "function" then
			return
		end
		push("PROBE", "Probing BridgeNet bridges (existence only)", true)
		for _, name in ipairs(BRIDGE_GUESSES) do
			local ok, bridge = pcall(function()
				return bridgeNet.ReferenceBridge(name)
			end)
			if ok and bridge then
				knownBridges[bridge] = name
				push("PROBE", "Bridge exists: " .. name, true)
			end
		end
	end

	local function sync()
		if Config.DebugAC then
			ensureHooks()
			ensureOverlay()
			ensureOverlayLoop()
			if overlayGui then
				overlayGui.Enabled = Config.DebugOverlay
			end
		elseif overlayGui then
			overlayGui.Enabled = false
		end
	end

	local function install()
		if Config.DebugAC then
			sync()
		end
	end

	local function printLog()
		push("DUMP", "Printing " .. #log .. " buffered entries", true)
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
		push(
			"STAT",
			string.format(
				"hits=%d shots=%d ratio=%.2f window=%.1fs",
				#hitRateRecentHits,
				#hitRateRecentShots,
				getRecentHitRatio(),
				HIT_RATE_WINDOW
			),
			true
		)
	end

	local function unload()
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
		table.clear(knownBridges)
		bridgeNetRef = nil
	end

	local genv = if typeof(getgenv) == "function" then getgenv() else _G
	genv.__WarfareACLog = log
	genv.__WarfareACDump = printLog

	return {
		sync = sync,
		install = install,
		installBridgeNet = installBridgeNet,
		probeBridges = probeBridges,
		wrapBridge = wrapBridge,
		onHitConfirm = onHitConfirm,
		onShot = onShot,
		push = push,
		scanRemotes = scanRemotes,
		scanSuspiciousModules = scanSuspiciousModules,
		printLog = printLog,
		clearLog = clearLog,
		dumpHitStats = dumpHitStats,
		conns = conns,
		unload = unload,
	}
end

return M
