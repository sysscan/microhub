local HttpService = game:GetService("HttpService")

local M = {}

local function stringifyArg(arg)
	local ok, encoded = pcall(function()
		if typeof(arg) == "Instance" then
			return arg:GetFullName()
		end
		if typeof(arg) == "table" then
			return HttpService:JSONEncode(arg)
		end
		return tostring(arg)
	end)
	if ok then
		return encoded
	end
	return "<unserializable>"
end

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local services = opts.services
	local util = opts.util
	local vehicles = opts.vehicles
	local remotes = opts.remotes

	local logs = table.create(64)
	local loggerInstalled = false
	local hookedFire = {}
	local hookedInvoke = {}
	local lastPosition: Vector3? = nil
	local monitorStarted = false

	local function emit(message: string, remoteOnly: boolean?)
		if remoteOnly and not Config.RemoteProbeLog then
			return
		end
		local line = string.format("[AR Probe %.1f] %s", tick(), message)
		table.insert(logs, 1, line)
		if #logs > 200 then
			table.remove(logs)
		end
		print(line)
		warn(line)
	end

	local function log(message: string)
		emit(message, false)
	end

	local function getLogs()
		return logs
	end

	local function clearLogs()
		table.clear(logs)
	end

	local function dumpLogs()
		for index = #logs, 1, -1 do
			print(logs[index])
		end
	end

	local function wrapHook(fn)
		if typeof(newcclosure) == "function" then
			return newcclosure(fn)
		end
		return fn
	end

	local function hookRemoteEvent(remote: RemoteEvent)
		if hookedFire[remote] or typeof(hookfunction) ~= "function" then
			return
		end
		local original = hookfunction(remote.FireServer, wrapHook(function(self, ...)
			if Config.RemoteProbeLog and self == remote then
				local packed = table.pack(...)
				local parts = table.create(packed.n)
				for index = 1, packed.n do
					parts[index] = stringifyArg(packed[index])
				end
				emit(remote.Name .. ":FireServer(" .. table.concat(parts, ", ") .. ")", true)
			end
			return original(self, ...)
		end))
		hookedFire[remote] = original
	end

	local function hookRemoteFunction(remote: RemoteFunction)
		if hookedInvoke[remote] or typeof(hookfunction) ~= "function" then
			return
		end
		local original = hookfunction(remote.InvokeServer, wrapHook(function(self, ...)
			if Config.RemoteProbeLog and self == remote then
				local packed = table.pack(...)
				local parts = table.create(packed.n)
				for index = 1, packed.n do
					parts[index] = stringifyArg(packed[index])
				end
				emit(remote.Name .. ":InvokeServer(" .. table.concat(parts, ", ") .. ")", true)
			end
			return original(self, ...)
		end))
		hookedInvoke[remote] = original
	end

	local function installRemoteLogger()
		if loggerInstalled then
			return true
		end
		if typeof(hookfunction) ~= "function" then
			log("hookfunction unavailable — logger not installed")
			return false
		end

		local folder = services.remotesFolder
		if not folder then
			log("Remotes folder missing")
			return false
		end

		for _, child in folder:GetChildren() do
			if child:IsA("RemoteEvent") then
				hookRemoteEvent(child)
			elseif child:IsA("RemoteFunction") then
				hookRemoteFunction(child)
			end
		end

		loggerInstalled = true
		log("Remote logger installed on " .. tostring(#folder:GetChildren()) .. " remotes")
		return true
	end

	local function listRemotes()
		local folder = services.remotesFolder
		if not folder then
			log("Remotes folder missing")
			return {}
		end
		local names = table.create(folder:GetChildCount())
		for _, child in folder:GetChildren() do
			table.insert(names, child.Name .. " (" .. child.ClassName .. ")")
			log(child.Name .. " (" .. child.ClassName .. ")")
		end
		table.sort(names)
		return names
	end

	local function logPlayerState()
		local folder = util.getPlayerFolder()
		if not folder then
			log("player folder missing")
			return
		end
		local values = folder:FindFirstChild("Values")
		local alive = folder:FindFirstChild("Alive")
		if values then
			for _, child in values:GetChildren() do
				if child:IsA("ValueBase") then
					log("Values." .. child.Name .. "=" .. tostring(child.Value))
				end
			end
		end
		if alive then
			for _, child in alive:GetChildren() do
				if child:IsA("ValueBase") then
					log("Alive." .. child.Name .. "=" .. tostring(child.Value))
				end
			end
		end
		if vehicles then
			log("VehicleState: " .. vehicles.describeVehicle(vehicles.getActiveVehicle()))
		end
	end

	local function probeFellZero()
		local remote = services.getRemote("Fell")
		if not remote then
			log("Fell remote missing")
			return false
		end
		local ok, err = pcall(function()
			remote:FireServer(0)
		end)
		log("probe Fell(0): " .. (ok and "ok" or tostring(err)))
		return ok
	end

	local function probeEntangle()
		local remote = services.getRemote("Entangle")
		if not remote then
			log("Entangle remote missing")
			return false
		end
		local ok, err = pcall(function()
			remote:FireServer()
		end)
		log("probe Entangle(): " .. (ok and "ok" or tostring(err)))
		return ok
	end

	local function probeCrouch()
		local remote = services.getRemote("Crouch")
		if not remote then
			log("Crouch remote missing")
			return false
		end
		local ok, err = pcall(function()
			remote:FireServer(false)
		end)
		log("probe Crouch(false): " .. (ok and "ok" or tostring(err)))
		return ok
	end

	local function probeVehicleHorn()
		local vehicle = vehicles and vehicles.getActiveVehicle()
		if not vehicle then
			log("no active vehicle for horn probe")
			return false
		end
		local ok, err = vehicles.fireVehicleRemote(vehicle, "Horn")
		log("probe vehicle Horn: " .. (ok and "ok" or tostring(err)))
		return ok
	end

	local function probeVehicleExit()
		local vehicle = vehicles and vehicles.getActiveVehicle()
		if not vehicle then
			log("no active vehicle for exit probe")
			return false
		end
		local ok, err = vehicles.fireVehicleRemote(vehicle, "Exit")
		log("probe vehicle Exit: " .. (ok and "ok" or tostring(err)))
		return ok
	end

	local function scanVehicles()
		local vehiclesFolder = workspace:FindFirstChild("Vehicles")
		if not vehiclesFolder then
			log("workspace.Vehicles missing")
			return
		end
		local count = 0
		for _, vehicle in vehiclesFolder:GetChildren() do
			count += 1
			if vehicles then
				log(vehicles.describeVehicle(vehicle))
			else
				log(vehicle.Name .. " id=" .. tostring(vehicle:GetAttribute("Id")))
			end
		end
		log("scanned " .. tostring(count) .. " vehicles")
	end

	local function probeToolReload()
		local ok, err = remotes.reloadGun()
		log("probe Tool_RE Reload: " .. (ok and "ok" or tostring(err)))
		return ok
	end

	local function getProbeInterval()
		return math.clamp(
			tonumber(Config.ProbeLogInterval) or Constants.DEFAULT_PROBE_LOG_INTERVAL,
			5,
			60
		)
	end

	local function logMovementSnapshot()
		local root = util.getRoot()
		local humanoid = util.getHumanoid()
		if not root then
			log("snapshot: no character root")
			return
		end

		local position = root.Position
		local velocity = root.AssemblyLinearVelocity
		local moved = 0
		if lastPosition then
			moved = (position - lastPosition).Magnitude
		end
		lastPosition = position

		local flags = table.concat({
			"Fly=" .. tostring(Config.Fly),
			"FlyMode=" .. tostring(Config.FlyMode),
			"Speed=" .. tostring(Config.SpeedBoost),
			"SilentAim=" .. tostring(Config.SilentAim),
			"AutoShoot=" .. tostring(Config.AutoShoot),
			"NoClip=" .. tostring(Config.NoClip),
		}, " ")

		log(string.format(
			"snapshot pos=(%.0f,%.0f,%.0f) velY=%.1f moved=%.1f walkspeed=%.1f | %s",
			position.X,
			position.Y,
			position.Z,
			velocity.Y,
			moved,
			humanoid and humanoid.WalkSpeed or 0,
			flags
		))

		if vehicles and vehicles.isInVehicle() then
			log("snapshot vehicle: " .. vehicles.describeVehicle(vehicles.getActiveVehicle()))
		end
	end

	local function logToggle(key, value)
		log("toggle " .. tostring(key) .. "=" .. tostring(value))
		logMovementSnapshot()
	end

	local function dumpRecentLogs(count: number?)
		local limit = math.clamp(count or 25, 1, 200)
		log("--- last " .. tostring(limit) .. " probe lines ---")
		for index = math.min(#logs, limit), 1, -1 do
			print(logs[index])
		end
		log("--- end probe dump ---")
	end

	local function runStartupReport()
		log("=== AC PROBE START build " .. tostring(Constants.GAME_BUILD) .. " ===")
		log("Logging to F9 — check Warning AND Output tabs")
		installRemoteLogger()
		listRemotes()
		logMovementSnapshot()
	end

	local function runSpawnedReport(connections)
		logPlayerState()
		scanVehicles()
		log("=== toggle hub features; each change logs here ===")
		local folder = util.getPlayerFolder()
		if folder then
			watchPlayerFolder(folder, connections)
		end
	end

	local function watchPlayerFolder(folder, connections)
		local values = folder:FindFirstChild("Values")
		local alive = folder:FindFirstChild("Alive")
		if not values or not alive then
			return
		end

		local watched = { "InVehicle", "Spawned", "Sprinting" }
		for _, name in watched do
			local value = values:FindFirstChild(name)
			if value and value:IsA("ValueBase") then
				table.insert(
					connections,
					value.Changed:Connect(function()
						log("CHANGED Values." .. name .. "=" .. tostring(value.Value))
					end)
				)
			end
		end

		local currentVehicle = alive:FindFirstChild("CurrentVehicle")
		if currentVehicle and currentVehicle:IsA("ValueBase") then
			table.insert(
				connections,
				currentVehicle.Changed:Connect(function()
					log("CHANGED Alive.CurrentVehicle=" .. tostring(currentVehicle.Value))
					logPlayerState()
				end)
			)
		end
	end

	local function startAutoMonitor(monitorOpts)
		if monitorStarted then
			return
		end
		if Config.ProbeAutoLog == false then
			return
		end
		monitorStarted = true

		local connections = monitorOpts.connections
		local runService = monitorOpts.runService
		local localPlayer = monitorOpts.localPlayer

		runStartupReport()

		task.spawn(function()
			services.waitForPlayerFolder(25)
			runSpawnedReport(connections)
		end)

		local lastSnapshotAt = 0
		table.insert(connections, runService.Heartbeat:Connect(function()
			local now = tick()
			if now - lastSnapshotAt < getProbeInterval() then
				return
			end
			lastSnapshotAt = now
			logMovementSnapshot()
		end))

		table.insert(connections, localPlayer.CharacterRemoving:Connect(function()
			log("!!! CHARACTER REMOVING — possible death or kick !!!")
			logPlayerState()
			dumpRecentLogs(30)
		end))

		table.insert(connections, localPlayer.OnTeleport:Connect(function(state)
			log("!!! ON TELEPORT state=" .. tostring(state) .. " — possible kick !!!")
			dumpRecentLogs(30)
		end))
	end

	return {
		log = log,
		getLogs = getLogs,
		clearLogs = clearLogs,
		dumpLogs = dumpLogs,
		dumpRecentLogs = dumpRecentLogs,
		listRemotes = listRemotes,
		logPlayerState = logPlayerState,
		logMovementSnapshot = logMovementSnapshot,
		logToggle = logToggle,
		installRemoteLogger = installRemoteLogger,
		runStartupReport = runStartupReport,
		startAutoMonitor = startAutoMonitor,
		probeFellZero = probeFellZero,
		probeEntangle = probeEntangle,
		probeCrouch = probeCrouch,
		probeVehicleHorn = probeVehicleHorn,
		probeVehicleExit = probeVehicleExit,
		probeToolReload = probeToolReload,
		scanVehicles = scanVehicles,
	}
end

return M
