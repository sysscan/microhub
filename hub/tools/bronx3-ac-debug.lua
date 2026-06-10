--[[
	Tha Bronx 3 anti-cheat debug logger for Volt.
	Writes to the Volt workspace via appendfile/writefile:
	https://docs.voltbz.net/docs/filesystem
	https://docs.voltbz.net/docs/filesystem/appendfile

	Usage (standalone):
		dofile("hub/tools/bronx3-ac-debug.lua")
		getgenv().__Bronx3ACDebugAutoStart = true
		dofile("hub/tools/bronx3-ac-debug.lua")

	Usage (from hub):
		Enable the "AC Debug" toggle in Tha Bronx 3 menu.

	Log output:
		hub/tools/bronx3-ac-debug/logs/<session>.log
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local function getGenv()
	return getgenv and getgenv() or _G
end

local LOG_ROOT = "hub/tools/bronx3-ac-debug/logs"
local FLUSH_INTERVAL = 1.25
local SAMPLE_INTERVAL = 0.5
local MARK_COOLDOWN = 0.08

local REMOTE_WATCH = {
	ClientPing = true,
	AE = true,
	FireServer = true,
	CServer = true,
	Physics = true,
	SENDSERVER = true,
	LoggerEvent = true,
	InflictTarget = true,
	RespawnRE = true,
	Died = true,
	NoShoot = true,
}

local SUSPICIOUS_ATTRS = {
	LastACPos = true,
	LayingPivot = true,
	MaxMoney = true,
	Vomit = true,
	SodaSprint = true,
	FCarryTarget = true,
	FCarriedBy = true,
}

local session = {
	running = false,
	context = {},
	queue = {},
	lastFlush = 0,
	lastSample = 0,
	lastPos = nil,
	lastMark = {},
	conns = {},
	characterConns = {},
	hooks = {},
	logPath = nil,
	seq = 0,
}

local function addConn(conn)
	table.insert(session.conns, conn)
	return conn
end

local function clearCharacterConns()
	for _, conn in ipairs(session.characterConns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(session.characterConns)
end

local function addCharacterConn(conn)
	table.insert(session.characterConns, conn)
	return conn
end

local function canWriteFiles()
	return typeof(appendfile) == "function" and typeof(writefile) == "function"
end

local function ensureLogDir()
	if typeof(isfolder) ~= "function" or typeof(makefolder) ~= "function" then
		return
	end
	if not isfolder("hub") then
		pcall(makefolder, "hub")
	end
	if not isfolder("hub/tools") then
		pcall(makefolder, "hub/tools")
	end
	if not isfolder("hub/tools/bronx3-ac-debug") then
		pcall(makefolder, "hub/tools/bronx3-ac-debug")
	end
	if not isfolder(LOG_ROOT) then
		pcall(makefolder, LOG_ROOT)
	end
end

local function encodeValue(value, depth)
	depth = depth or 0
	if depth > 2 then
		return "<depth>"
	end
	local t = typeof(value)
	if t == "nil" then
		return "nil"
	end
	if t == "boolean" or t == "number" then
		return tostring(value)
	end
	if t == "string" then
		if #value > 120 then
			return string.format("%q...", value:sub(1, 117))
		end
		return string.format("%q", value)
	end
	if t == "Vector3" then
		return string.format("Vector3(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
	end
	if t == "CFrame" then
		local p = value.Position
		return string.format("CFrame(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
	end
	if t == "Instance" then
		return value:GetFullName()
	end
	if t == "EnumItem" then
		return tostring(value)
	end
	if t == "table" then
		local parts = {}
		local count = 0
		for k, v in pairs(value) do
			count += 1
			if count > 8 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. encodeValue(v, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return t
end

local function callerHint()
	if typeof(getcallingscript) == "function" then
		local scr = getcallingscript()
		if scr then
			return scr:GetFullName()
		end
	end
	local ok, src = pcall(debug.info, 3, "s")
	if ok and typeof(src) == "string" then
		return src
	end
	return "unknown"
end

local function push(kind, message, data)
	session.seq += 1
	local line = {
		seq = session.seq,
		t = os.date("%Y-%m-%d %H:%M:%S"),
		epoch = os.clock(),
		kind = kind,
		msg = message,
		data = data,
		ctx = session.context,
	}
	table.insert(session.queue, line)
	warn("[Bronx3ACDebug]", kind, message, data and encodeValue(data) or "")
	if #session.queue >= 64 then
		Bronx3ACDebug.flush(true)
	end
end

local function formatLine(entry)
	local dataText = ""
	if entry.data ~= nil then
		dataText = " | data=" .. encodeValue(entry.data)
	end
	local ctxText = ""
	if typeof(entry.ctx) == "table" then
		ctxText = string.format(
			" | ctx fly=%s bypass=%s speed=%s flySpd=%s",
			tostring(entry.ctx.fly),
			tostring(entry.ctx.acBypass),
			tostring(entry.ctx.speedBoost),
			tostring(entry.ctx.flySpeed)
		)
	end
	return string.format(
		"[%s] #%d %s %s%s%s\n",
		entry.t,
		entry.seq,
		entry.kind,
		entry.msg,
		ctxText,
		dataText
	)
end

local function flushLines(lines)
	if not canWriteFiles() or #lines == 0 then
		return false
	end
	ensureLogDir()
	local payload = {}
	for _, entry in ipairs(lines) do
		table.insert(payload, formatLine(entry))
	end
	local text = table.concat(payload)
	local ok = pcall(function()
		if session.logPath and typeof(isfile) == "function" and isfile(session.logPath) then
			appendfile(session.logPath, text)
		else
			writefile(session.logPath, text)
		end
	end)
	return ok
end

local function getCharacterSnapshot()
	local character = LocalPlayer.Character
	if not character then
		return { hasCharacter = false }
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local snap = {
		hasCharacter = true,
		health = humanoid and humanoid.Health or nil,
		walkSpeed = humanoid and humanoid.WalkSpeed or nil,
		state = humanoid and tostring(humanoid:GetState()) or nil,
		rootAnchored = root and root.Anchored or nil,
		rootPos = root and root.Position or nil,
		rootVel = root and root.AssemblyLinearVelocity or nil,
		rootAngVel = root and root.AssemblyAngularVelocity or nil,
		lastAcPos = LocalPlayer:GetAttribute("LastACPos"),
		layingPivot = LocalPlayer:GetAttribute("LayingPivot"),
	}
	if session.lastPos and root then
		snap.deltaStuds = (root.Position - session.lastPos).Magnitude
	end
	if root then
		session.lastPos = root.Position
	end
	return snap
end

local function shouldLogRemote(name, fullName)
	if REMOTE_WATCH[name] then
		return true
	end
	local lower = string.lower(name)
	return lower:find("kick") ~= nil
		or lower:find("ping") ~= nil
		or lower:find("cheat") ~= nil
		or lower:find("ac") ~= nil
		or lower:find("ban") ~= nil
		or lower:find("log") ~= nil
end

local function summarizeArgs(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, encodeValue(select(i, ...)))
	end
	return table.concat(parts, " | ")
end

local function installKickHook()
	if typeof(hookfunction) ~= "function" or typeof(newcclosure) ~= "function" then
		push("HOOK", "kick hook unavailable")
		return
	end
	if session.hooks.kick then
		return
	end

	local kickFn = LocalPlayer.Kick
	if typeof(kickFn) ~= "function" then
		push("HOOK", "LocalPlayer.Kick not found")
		return
	end

	local original = hookfunction(
		kickFn,
		newcclosure(function(self, ...)
			if self == LocalPlayer then
				push("KICK", "LocalPlayer:Kick called", {
					args = summarizeArgs(...),
					caller = callerHint(),
					snapshot = getCharacterSnapshot(),
				})
			end
			return original(self, ...)
		end, "Bronx3ACDebug.Kick")
	)
	session.hooks.kick = original
	push("HOOK", "LocalPlayer.Kick hooked")
end

local function installNamecallHook()
	if typeof(hookfunction) ~= "function" or typeof(newcclosure) ~= "function" then
		return
	end
	if typeof(getrawmetatable) ~= "function" or typeof(getnamecallmethod) ~= "function" then
		push("HOOK", "namecall hook unavailable")
		return
	end
	if session.hooks.namecall then
		return
	end

	local mt = getrawmetatable(game)
	if not mt then
		push("HOOK", "game metatable unavailable")
		return
	end
	local original = hookfunction(
		mt.__namecall,
		newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if method == "Kick" and self == LocalPlayer then
				push("KICK", "__namecall Kick", {
					args = summarizeArgs(...),
					caller = callerHint(),
					snapshot = getCharacterSnapshot(),
				})
			elseif method == "FireServer" and self:IsA("RemoteEvent") then
				local name = self.Name
				if shouldLogRemote(name, self:GetFullName()) then
					push("REMOTE", "FireServer " .. self:GetFullName(), {
						args = summarizeArgs(...),
						caller = callerHint(),
					})
				end
			elseif method == "InvokeServer" and self:IsA("RemoteFunction") then
				local name = self.Name
				if shouldLogRemote(name, self:GetFullName()) then
					push("REMOTE", "InvokeServer " .. self:GetFullName(), {
						args = summarizeArgs(...),
						caller = callerHint(),
					})
				end
			end
			return original(self, ...)
		end, "Bronx3ACDebug.Namecall")
	)
	session.hooks.namecall = original
	push("HOOK", "__namecall hooked")
end

local function bindCharacter(character)
	clearCharacterConns()

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid then
		addCharacterConn(humanoid.StateChanged:Connect(function(oldState, newState)
			push("HUMANOID", "StateChanged", { from = tostring(oldState), to = tostring(newState) })
		end))
		addCharacterConn(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			push("HUMANOID", "WalkSpeed=" .. tostring(humanoid.WalkSpeed), getCharacterSnapshot())
		end))
	end
	if root then
		session.lastPos = root.Position
		addCharacterConn(root:GetPropertyChangedSignal("Anchored"):Connect(function()
			push("ROOT", "Anchored=" .. tostring(root.Anchored), getCharacterSnapshot())
		end))
		addCharacterConn(root:GetPropertyChangedSignal("CFrame"):Connect(function()
			local snap = getCharacterSnapshot()
			if snap.deltaStuds and snap.deltaStuds > 8 then
				push("ROOT", "Large CFrame delta", snap)
			end
		end))
	end
end

local Bronx3ACDebug = {}

function Bronx3ACDebug.setContext(ctx)
	if typeof(ctx) ~= "table" then
		return
	end
	session.context = {
		fly = ctx.fly == true,
		acBypass = ctx.acBypass == true,
		speedBoost = ctx.speedBoost == true,
		flySpeed = ctx.flySpeed,
		walkSpeed = ctx.walkSpeed,
	}
end

function Bronx3ACDebug.mark(tag, detail)
	if not session.running then
		return
	end
	local now = os.clock()
	local last = session.lastMark[tag] or 0
	if now - last < MARK_COOLDOWN then
		return
	end
	session.lastMark[tag] = now
	push("MARK", tag, detail)
end

function Bronx3ACDebug.flush(force)
	if not canWriteFiles() then
		return false
	end
	if #session.queue == 0 then
		return true
	end
	local now = os.clock()
	if not force and now - session.lastFlush < FLUSH_INTERVAL then
		return true
	end
	local batch = session.queue
	session.queue = {}
	local ok = flushLines(batch)
	session.lastFlush = now
	if not ok then
		for i = #batch, 1, -1 do
			table.insert(session.queue, 1, batch[i])
		end
	end
	return ok
end

function Bronx3ACDebug.start(ctx)
	if session.running then
		Bronx3ACDebug.setContext(ctx or {})
		return Bronx3ACDebug
	end
	if not canWriteFiles() then
		warn("[Bronx3ACDebug] appendfile/writefile unavailable — logging disabled")
		return Bronx3ACDebug
	end

	ensureLogDir()
	session.logPath = LOG_ROOT .. "/session-" .. os.date("%Y%m%d-%H%M%S") .. ".log"
	session.running = true
	session.seq = 0
	session.queue = {}
	session.lastFlush = 0
	session.lastSample = 0
	session.lastPos = nil
	table.clear(session.lastMark)

	Bronx3ACDebug.setContext(ctx or {})

	local executorName, executorVersion = "unknown", "unknown"
	if typeof(identifyexecutor) == "function" then
		local ok, a, b = pcall(identifyexecutor)
		if ok then
			executorName, executorVersion = a or executorName, b or executorVersion
		end
	end

	writefile(
		session.logPath,
		string.format(
			"=== Tha Bronx 3 AC Debug Session ===\nstarted=%s\nplaceId=%s\nuserId=%s\nexecutor=%s %s\nlogPath=%s\n\n",
			os.date("%Y-%m-%d %H:%M:%S"),
			tostring(game.PlaceId),
			tostring(LocalPlayer.UserId),
			tostring(executorName),
			tostring(executorVersion),
			session.logPath
		)
	)

	push("SESSION", "started", {
		placeId = game.PlaceId,
		userId = LocalPlayer.UserId,
		executor = executorName,
		version = executorVersion,
	})

	installKickHook()
	installNamecallHook()

	table.insert(session.conns, LocalPlayer.AttributeChanged:Connect(function(name)
		local value = LocalPlayer:GetAttribute(name)
		local priority = SUSPICIOUS_ATTRS[name] and "ATTR!" or "ATTR"
		push(priority, name .. "=" .. encodeValue(value), getCharacterSnapshot())
	end))

	table.insert(session.conns, LocalPlayer.CharacterAdded:Connect(function(character)
		push("CHAR", "CharacterAdded", getCharacterSnapshot())
		bindCharacter(character)
	end))

	table.insert(session.conns, LocalPlayer.CharacterRemoving:Connect(function()
		push("CHAR", "CharacterRemoving", getCharacterSnapshot())
	end))

	table.insert(session.conns, RunService.Heartbeat:Connect(function()
		if not session.running then
			return
		end
		local now = os.clock()
		if now - session.lastSample >= SAMPLE_INTERVAL then
			session.lastSample = now
			local snap = getCharacterSnapshot()
			local level = "SAMPLE"
			if snap.deltaStuds and snap.deltaStuds > 20 then
				level = "SAMPLE!"
			end
			if snap.lastAcPos ~= nil then
				level = "SAMPLE!"
			end
			push(level, "heartbeat", snap)
		end
		Bronx3ACDebug.flush(false)
	end))

	if LocalPlayer.Character then
		bindCharacter(LocalPlayer.Character)
	end

	for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
		if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
			if shouldLogRemote(remote.Name, remote:GetFullName()) then
				push("REMOTE", "discovered " .. remote:GetFullName(), { class = remote.ClassName })
			end
		end
	end

	push("SESSION", "ready", { logPath = session.logPath })
	Bronx3ACDebug.flush(true)

	getGenv().__Bronx3ACDebugLogPath = session.logPath
	return Bronx3ACDebug
end

function Bronx3ACDebug.stop()
	if not session.running then
		return
	end
	push("SESSION", "stopped", getCharacterSnapshot())
	Bronx3ACDebug.flush(true)
	session.running = false
	for _, conn in ipairs(session.conns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(session.conns)
	clearCharacterConns()
	session.hooks = {}
end

function Bronx3ACDebug.isRunning()
	return session.running
end

function Bronx3ACDebug.getLogPath()
	return session.logPath
end

getGenv().__Bronx3ACDebug = Bronx3ACDebug

if getGenv().__Bronx3ACDebugAutoStart then
	Bronx3ACDebug.start(getGenv().__Bronx3ACDebugContext)
end

return Bronx3ACDebug
