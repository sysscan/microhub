--[[ AC / speed instrumentation for Deadzone Classic (diagnosis only). ]]

local require = shared.__MicroHubRequire
local ACLib = require("games/deadzone-classic/ac.lua")

local M = {}

local MAX_ENTRIES = 200
local SNAPSHOT_INTERVAL = 3
local WALK_LOG_EPSILON = 0.05

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Constants = opts.constants

	local entries: { { t: number, tag: string, detail: any } } = {}
	local globalConnections: { RBXScriptConnection } = {}
	local charConnections: { RBXScriptConnection } = {}
	local snapshotThread: thread? = nil
	local started = false
	local lastWalkLog = 0
	local lastJumpLog = 0

	local function formatDetail(detail: any): string
		if detail == nil then
			return ""
		end
		if type(detail) ~= "table" then
			return tostring(detail)
		end
		local parts = {}
		for k, v in detail do
			table.insert(parts, tostring(k) .. "=" .. tostring(v))
		end
		table.sort(parts)
		return table.concat(parts, ", ")
	end

	local function log(tag: string, detail: any?)
		if not Config.DebugAC then
			return
		end
		table.insert(entries, {
			t = os.clock(),
			tag = tag,
			detail = detail,
		})
		if #entries > MAX_ENTRIES then
			table.remove(entries, 1)
		end
		if Config.DebugLivePrint then
			print("[DZ-DBG]", tag, formatDetail(detail))
		end
	end

	local function movementSnapshot(): { [string]: any }
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local horizVel = 0
		if root and root:IsA("BasePart") then
			local v = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			horizVel = v.Magnitude
		end
		local diag = ACLib.getDiagnostics()
		return {
			configWalk = Config.WalkSpeed,
			configSprint = Config.SprintSpeed,
			alwaysSprint = Config.AlwaysSprint,
			acBypass = Config.ACBypass,
			humWalk = hum and math.floor(hum.WalkSpeed * 10) / 10 or "nil",
			humJump = hum and math.floor(hum.JumpPower * 10) / 10 or "nil",
			horizVel = math.floor(horizVel * 10) / 10,
			safeWalk = Constants.MAX_SAFE_WALK,
			hookInstalled = diag.hookInstalled,
			clientAcOff = diag.clientNeutralized,
			disabledConns = diag.disabledCount,
			activeAcConns = diag.activeAcConnections,
			canGetconnections = diag.canInspectConnections,
			canHook = diag.canHook,
			aimStepUnbound = diag.aimStepUnbound,
		}
	end

	local function snapshot(label: string?)
		log(label or "snapshot", movementSnapshot())
	end

	local function dump()
		print("[DeadzoneClassic] debug log (" .. tostring(#entries) .. " entries)")
		for _, row in entries do
			print(string.format("[%.2f] %s | %s", row.t, row.tag, formatDetail(row.detail)))
		end
		print("[DeadzoneClassic] latest diagnostics:", formatDetail(movementSnapshot()))
	end

	local function clear()
		table.clear(entries)
	end

	local function clearCharConnections()
		for _, conn in charConnections do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(charConnections)
	end

	local function stop()
		if snapshotThread then
			pcall(task.cancel, snapshotThread)
			snapshotThread = nil
		end
		clearCharConnections()
		for _, conn in globalConnections do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(globalConnections)
		started = false
	end

	local function watchCharacter(char: Model)
		clearCharConnections()
		task.defer(function()
			if not Config.DebugAC or not started then
				return
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum then
				hum = char:WaitForChild("Humanoid", 10)
			end
			if not hum or not hum:IsA("Humanoid") then
				return
			end

			table.insert(charConnections, hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if not Config.DebugAC then
					return
				end
				local value = hum.WalkSpeed
				if math.abs(value - lastWalkLog) < WALK_LOG_EPSILON then
					return
				end
				lastWalkLog = value
				log("walkspeed_changed", { value = value })
			end))

			table.insert(charConnections, hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
				if not Config.DebugAC then
					return
				end
				local value = hum.JumpPower
				if math.abs(value - lastJumpLog) < WALK_LOG_EPSILON then
					return
				end
				lastJumpLog = value
				log("jumppower_changed", { value = value })
			end))

			snapshot("character_ready")
		end)
	end

	local function bindGlobals()
		local genv = typeof(getgenv) == "function" and getgenv() or _G
		genv.__DeadzoneClassicDebug = {
			log = log,
			snapshot = snapshot,
			dump = dump,
			clear = clear,
		}
		genv.__DeadzoneClassicDebugDump = dump
	end

	local function unbindGlobals()
		local genv = typeof(getgenv) == "function" and getgenv() or _G
		genv.__DeadzoneClassicDebug = nil
		genv.__DeadzoneClassicDebugDump = nil
	end

	local function start()
		if started then
			return
		end
		started = true
		bindGlobals()
		log("debugger_start", movementSnapshot())

		if LocalPlayer.Character then
			watchCharacter(LocalPlayer.Character)
		end
		table.insert(globalConnections, LocalPlayer.CharacterAdded:Connect(watchCharacter))

		snapshotThread = task.spawn(function()
			while started and Config.DebugAC do
				task.wait(SNAPSHOT_INTERVAL)
				if started and Config.DebugAC then
					snapshot("heartbeat")
				end
			end
			snapshotThread = nil
		end)
	end

	local function setEnabled(enabled: boolean)
		Config.DebugAC = enabled == true
		if Config.DebugAC then
			start()
			snapshot("debug_enabled")
		else
			if started then
				snapshot("debug_disabled")
				dump()
			end
			stop()
			unbindGlobals()
		end
	end

	local function destroy()
		stop()
		unbindGlobals()
	end

	return {
		log = log,
		snapshot = snapshot,
		dump = dump,
		clear = clear,
		start = start,
		stop = stop,
		setEnabled = setEnabled,
		destroy = destroy,
	}
end

return M
