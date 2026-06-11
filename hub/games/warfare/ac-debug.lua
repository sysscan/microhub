local LogService = game:GetService("LogService")
local TeleportService = game:GetService("TeleportService")

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

	local ACDBG_TAG = "[WarfareAC]"
local ACDBG_MAX = 250
local ACDBG_KEYWORDS = {
	"kick", "ban", "cheat", "anticheat", "anti", "invalid", "hit", "rate", "exploit",
	"detect", "flag", "violation", "sanity", "validate", "reject", "security", "ac_",
}
local ACDBG_BRIDGE_GUESSES = {
	"HitConfirm", "Damage", "Hit", "Fire", "Bullet", "AntiCheat", "AC", "Kick", "Ban",
	"Report", "Validate", "Sanity", "Cheat", "Flag", "Violation", "HitRate", "Combat",
	"Weapon", "Shoot", "Kill", "Death", "Replication", "Replicate",
}
local acdbgLog = {}
local acdbgSeq = 0
local acdbgWrappedBridges = {}
local acdbgHookedRemotes = {}
local acdbgConns = {}
local acdbgOverlayGui = nil
local acdbgOverlayLabel = nil
local acdbgNamecallHook = nil
local acdbgBridgeNetRef = nil
local acdbgHookedFns = {}
local acdbgDescendantConn = nil
local acdbgRemoteLastLog = {}
local ACDBG_REMOTE_LOG_COOLDOWN = 1
local ACDBG_IGNORE_REMOTE_NAMES = {
	PingCheck = true,
	dataRemoteEvent = true,
}

local function acdbgShouldWatchRemote(remote)
	if not remote or not remote:IsA("Instance") then
		return false
	end
	if ACDBG_IGNORE_REMOTE_NAMES[remote.Name] then
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
		return acdbgMatchesKeywords(fullName .. " " .. remote.Name)
	end
	return true
end

local function acdbgKind(value)
	if typeof then
		return typeof(value)
	end
	return type(value)
end

local function acdbgSerialize(value, depth)
	depth = depth or 0
	if depth > 4 then
		return "<deep>"
	end
	local kind = acdbgKind(value)
	if kind == "nil" then
		return "nil"
	end
	if kind == "boolean" or kind == "number" then
		return tostring(value)
	end
	if kind == "string" then
		if #value > 160 then
			return string.format("%q...", value:sub(1, 160))
		end
		return string.format("%q", value)
	end
	if kind == "Instance" then
		return value:GetFullName()
	end
	if kind == "Vector3" then
		return string.format("V3(%.2f,%.2f,%.2f)", value.X, value.Y, value.Z)
	end
	if kind == "Vector2" then
		return string.format("V2(%.2f,%.2f)", value.X, value.Y)
	end
	if kind == "CFrame" then
		local p = value.Position
		return string.format("CF(%.2f,%.2f,%.2f)", p.X, p.Y, p.Z)
	end
	if kind == "EnumItem" then
		return tostring(value)
	end
	if kind == "table" then
		local parts = {}
		local count = 0
		for key, entry in value do
			count += 1
			if count > 14 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(key) .. "=" .. acdbgSerialize(entry, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return "<" .. kind .. ">"
end

local function acdbgSerializeArgs(args)
	local parts = {}
	for index = 1, math.min(args.n or #args, 12) do
		table.insert(parts, acdbgSerialize(args[index]))
	end
	if (args.n or #args) > 12 then
		table.insert(parts, "...")
	end
	return table.concat(parts, ", ")
end

local function acdbgMatchesKeywords(text)
	local lower = string.lower(text)
	for _, keyword in ACDBG_KEYWORDS do
		if lower:find(keyword, 1, true) then
			return true
		end
	end
	return false
end

local function acdbgPush(category, message, force)
	if not Config.DebugAC and not force then
		return
	end
	if Config.DebugFilterOnly and not force and not acdbgMatchesKeywords(category .. " " .. message) then
		return
	end

	acdbgSeq += 1
	local entry = {
		seq = acdbgSeq,
		t = tick(),
		category = category,
		message = message,
	}
	table.insert(acdbgLog, entry)
	while #acdbgLog > ACDBG_MAX do
		table.remove(acdbgLog, 1)
	end

	warn(ACDBG_TAG, string.format("[%s] %s", category, message))

	if Config.DebugOverlay and acdbgOverlayLabel then
		local lines = {}
		for index = math.max(1, #acdbgLog - 7), #acdbgLog do
			local row = acdbgLog[index]
			table.insert(lines, string.format("%d %s: %s", row.seq, row.category, row.message))
		end
		acdbgOverlayLabel.Text = table.concat(lines, "\n")
	end
end

local function acdbgRemotePath(remote)
	if not remote or not remote:IsA("Instance") then
		return tostring(remote)
	end
	return remote:GetFullName()
end

local function acdbgLogRemote(direction, remote, args)
	if not Config.DebugAC or not Config.DebugRemotes then
		return
	end
	if not acdbgShouldWatchRemote(remote) then
		return
	end
	local path = acdbgRemotePath(remote)
	local logKey = tostring(direction) .. "|" .. path
	local now = tick()
	if not Config.DebugVerbose then
		local last = acdbgRemoteLastLog[logKey]
		if last and now - last < ACDBG_REMOTE_LOG_COOLDOWN then
			return
		end
		acdbgRemoteLastLog[logKey] = now
	end
	local ok, err = pcall(function()
		local packed = table.pack(unpack(args))
		local text = string.format(
			"%s %s | %s",
			tostring(direction),
			acdbgRemotePath(remote),
			acdbgSerializeArgs(packed)
		)
		if Config.DebugVerbose and debug and typeof(debug.info) == "function" then
			local infoOk, info = pcall(debug.info, 3, "slnfa")
			if infoOk and info ~= nil then
				text ..= " | " .. tostring(info)
			end
		end
		acdbgPush("REMOTE", text)
	end)
	if not ok then
		acdbgPush("REMOTE", "log error: " .. tostring(err), true)
	end
end

local function acdbgLogBridge(direction, bridgeName, args)
	if not Config.DebugAC or not Config.DebugBridgeNet then
		return
	end
	local packed = table.pack(unpack(args))
	acdbgPush("BRIDGE", string.format("%s %s | %s", direction, bridgeName, acdbgSerializeArgs(packed)))
end

local function acdbgLogKick(source, args)
	if not Config.DebugAC or not Config.DebugKicks then
		return
	end
	local packed = table.pack(unpack(args))
	acdbgPush("KICK", string.format("%s | %s", source, acdbgSerializeArgs(packed)), true)
end

local function acdbgOnHitConfirm(payload)
	if not Config.DebugAC or not Config.DebugHits then
		return
	end
	local ratio = getRecentHitRatio()
	local msg = string.format(
		"HitConfirm %s | hits=%d shots=%d ratio=%.2f",
		acdbgSerialize(payload),
		#hitRateRecentHits,
		#hitRateRecentShots,
		ratio
	)
	acdbgPush("HIT", msg)
end

local function acdbgOnShot(redirectAim)
	if not Config.DebugAC or not Config.DebugHits or not Config.DebugVerbose then
		return
	end
	acdbgPush(
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

local function acdbgHookFunction(fn, makeHandler)
	if typeof(fn) ~= "function" or acdbgHookedFns[fn] or typeof(hookfunction) ~= "function" then
		return nil
	end
	acdbgHookedFns[fn] = true
	local original
	local handler = makeHandler(function(...)
		return original(...)
	end)
	original = hookfunction(fn, handler)
	return original
end

local function acdbgWrapBridge(bridgeName, bridge)
	if not bridge or acdbgWrappedBridges[bridge] then
		return
	end
	if not Config.DebugAC or not Config.DebugBridgeNet then
		return
	end
	acdbgWrappedBridges[bridge] = bridgeName

	for _, methodName in { "Fire", "Invoke", "Send" } do
		local method = bridge[methodName]
		if typeof(method) == "function" then
			acdbgHookFunction(method, function(callOriginal)
				return function(...)
					acdbgLogBridge("OUT", bridgeName, { ... })
					return callOriginal(...)
				end
			end)
		end
	end

	local connect = bridge.Connect
	if typeof(connect) == "function" then
		acdbgHookFunction(connect, function(callOriginal)
			return function(self, callback)
				if typeof(callback) ~= "function" then
					return callOriginal(self, callback)
				end
				return callOriginal(self, function(...)
					acdbgLogBridge("IN", bridgeName, { ... })
					return callback(...)
				end)
			end
		end)
	end
end

local function acdbgHookIncomingRemote(remote)
	if not acdbgShouldWatchRemote(remote) or acdbgHookedRemotes[remote] then
		return
	end
	acdbgHookedRemotes[remote] = true

	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		table.insert(acdbgConns, remote.OnClientEvent:Connect(function(...)
			acdbgLogRemote("IN", remote, { ... })
		end))
	end
end

local function acdbgScanRemotes(logEach, hookIncoming)
	local remotes = {}
	for _, descendant in ipairs(game:GetDescendants()) do
		if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") or descendant:IsA("UnreliableRemoteEvent") then
			table.insert(remotes, descendant)
			if hookIncoming and Config.DebugAC then
				acdbgHookIncomingRemote(descendant)
			end
		end
	end
	table.sort(remotes, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	if logEach then
		acdbgPush("SCAN", "Found " .. #remotes .. " remotes", true)
		for _, remote in ipairs(remotes) do
			acdbgPush("SCAN", remote.ClassName .. " " .. remote:GetFullName(), true)
		end
	end
	return remotes
end

local function acdbgScanSuspiciousModules()
	local hits = {}
	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("ModuleScript") then
			local lower = string.lower(descendant.Name)
			if lower:find("anticheat", 1, true)
				or lower:find("anti", 1, true) and lower:find("cheat", 1, true)
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
	acdbgPush("SCAN", "Suspicious modules: " .. #hits, true)
	for _, path in ipairs(hits) do
		acdbgPush("SCAN", path, true)
	end
	return hits
end

local function acdbgProbeBridges(bridgeNet)
	if not bridgeNet or typeof(bridgeNet.ReferenceBridge) ~= "function" then
		return
	end
	acdbgPush("PROBE", "Probing BridgeNet bridges", true)
	for _, name in ipairs(ACDBG_BRIDGE_GUESSES) do
		local ok, bridge = pcall(bridgeNet.ReferenceBridge, name)
		if ok and bridge then
			acdbgPush("PROBE", "Bridge exists: " .. name, true)
			acdbgWrapBridge(name, bridge)
		end
	end
end

local function acdbgInstallBridgeNet(bridgeNet)
	if not bridgeNet then
		return
	end
	acdbgBridgeNetRef = bridgeNet
end

local function acdbgEnsureOverlay()
	if acdbgOverlayGui then
		acdbgOverlayGui.Enabled = Config.DebugAC and Config.DebugOverlay
		return
	end
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
	acdbgOverlayGui = Instance.new("ScreenGui")
	acdbgOverlayGui.Name = "MicroHub_WarfareACDebug"
	acdbgOverlayGui.ResetOnSpawn = false
	acdbgOverlayGui.IgnoreGuiInset = true
	acdbgOverlayGui.DisplayOrder = 1000
	acdbgOverlayGui.Parent = playerGui

	acdbgOverlayLabel = Instance.new("TextLabel")
	acdbgOverlayLabel.Name = "Log"
	acdbgOverlayLabel.BackgroundTransparency = 0.35
	acdbgOverlayLabel.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	acdbgOverlayLabel.TextColor3 = Color3.fromRGB(220, 230, 240)
	acdbgOverlayLabel.TextStrokeTransparency = 0.5
	acdbgOverlayLabel.Font = Enum.Font.Code
	acdbgOverlayLabel.TextSize = 13
	acdbgOverlayLabel.TextXAlignment = Enum.TextXAlignment.Left
	acdbgOverlayLabel.TextYAlignment = Enum.TextYAlignment.Top
	acdbgOverlayLabel.Size = UDim2.new(0, 520, 0, 150)
	acdbgOverlayLabel.Position = UDim2.fromOffset(8, 8)
	acdbgOverlayLabel.TextWrapped = true
	acdbgOverlayLabel.Parent = acdbgOverlayGui
	acdbgOverlayGui.Enabled = Config.DebugAC and Config.DebugOverlay
end

local function acdbgInstallNamecallHook()
	if acdbgNamecallHook or typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
		return
	end
	local wrap = newcclosure
	if typeof(wrap) ~= "function" then
		wrap = function(fn)
			return fn
		end
	end
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
		local method = getnamecallmethod()
		if Config.DebugAC then
			if Config.DebugRemotes and (method == "FireServer" or method == "InvokeServer") then
				if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent") then
					if acdbgShouldWatchRemote(self) then
						acdbgLogRemote("OUT", self, { ... })
					end
				end
			end
			if Config.DebugKicks then
				if method == "Kick" and self == LocalPlayer then
					acdbgLogKick("LocalPlayer:Kick", { ... })
				elseif method == "Teleport" or method == "TeleportToPlaceInstance" then
					if self == TeleportService then
						acdbgLogKick("TeleportService:" .. method, { ... })
					end
				end
			end
		end
		return oldNamecall(self, ...)
	end))
	acdbgNamecallHook = oldNamecall
	acdbgPush("HOOK", "Installed __namecall remote/kick hook", true)
end

local function acdbgInstallLogHook()
	table.insert(acdbgConns, LogService.MessageOut:Connect(function(message, messageType)
		if not Config.DebugAC then
			return
		end
		if messageType == Enum.MessageType.MessageError or acdbgMatchesKeywords(message) then
			acdbgPush("LOG", tostring(messageType) .. " | " .. message)
		end
	end))
end

local function acdbgInstallDescendantHook()
	if acdbgDescendantConn then
		return
	end
	acdbgDescendantConn = game.DescendantAdded:Connect(function(descendant)
		if not Config.DebugAC then
			return
		end
		if descendant:IsA("RemoteEvent") or descendant:IsA("UnreliableRemoteEvent") then
			if acdbgShouldWatchRemote(descendant) then
				acdbgHookIncomingRemote(descendant)
				acdbgPush("SCAN", "New remote: " .. descendant:GetFullName(), true)
			end
		end
	end)
	table.insert(acdbgConns, acdbgDescendantConn)
end

local acdbgInstalled = false
local function acdbgInstall()
	if acdbgInstalled then
		return
	end
	acdbgInstalled = true
	acdbgInstallNamecallHook()
	acdbgInstallLogHook()
	acdbgInstallDescendantHook()
	acdbgPush("BOOT", "AC debug hooks installed", true)
end

local function acdbgSyncBridgeWrap()
	if not Config.DebugAC or not Config.DebugBridgeNet or not acdbgBridgeNetRef then
		return
	end
	local ok, bridge = pcall(acdbgBridgeNetRef.ReferenceBridge, acdbgBridgeNetRef, "HitConfirm")
	if ok and bridge then
		acdbgWrapBridge("HitConfirm", bridge)
	end
end

local function acdbgSync()
	if Config.DebugAC then
		acdbgInstall()
		acdbgEnsureOverlay()
		acdbgSyncBridgeWrap()
	else
		if acdbgOverlayGui then
			acdbgOverlayGui.Enabled = false
		end
	end
end

local function acdbgPrintLog()
	acdbgPush("DUMP", "Printing " .. #acdbgLog .. " buffered entries", true)
	for _, entry in ipairs(acdbgLog) do
		warn(ACDBG_TAG, string.format("%d [%.2f] [%s] %s", entry.seq, entry.t, entry.category, entry.message))
	end
end

local function acdbgClearLog()
	table.clear(acdbgLog)
	acdbgSeq = 0
	if acdbgOverlayLabel then
		acdbgOverlayLabel.Text = ""
	end
	acdbgPush("DUMP", "Log cleared", true)
end

local function acdbgDumpHitStats()
	acdbgPush(
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
	local function warfareUnload()
		for _, conn in ipairs(acdbgConns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(acdbgConns)
		if acdbgOverlayGui then
			acdbgOverlayGui:Destroy()
			acdbgOverlayGui = nil
			acdbgOverlayLabel = nil
		end
		if acdbgDescendantConn then
			acdbgDescendantConn:Disconnect()
			acdbgDescendantConn = nil
		end
	end

	local genv = if typeof(getgenv) == "function" then getgenv() else _G
	genv.__WarfareACLog = acdbgLog
	genv.__WarfareACDump = acdbgPrintLog

	return {
		sync = acdbgSync,
		install = acdbgInstall,
		installBridgeNet = acdbgInstallBridgeNet,
		probeBridges = acdbgProbeBridges,
		wrapBridge = acdbgWrapBridge,
		onHitConfirm = acdbgOnHitConfirm,
		onShot = acdbgOnShot,
		push = acdbgPush,
		scanRemotes = acdbgScanRemotes,
		scanSuspiciousModules = acdbgScanSuspiciousModules,
		printLog = acdbgPrintLog,
		clearLog = acdbgClearLog,
		dumpHitStats = acdbgDumpHitStats,
		conns = acdbgConns,
		unload = warfareUnload,
	}
end

return M