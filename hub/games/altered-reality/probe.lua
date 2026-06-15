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
	local services = opts.services
	local util = opts.util
	local vehicles = opts.vehicles
	local remotes = opts.remotes

	local logs = table.create(64)
	local loggerInstalled = false
	local hookedFire = {}
	local hookedInvoke = {}

	local function log(message)
		local line = string.format("[%.2f] %s", tick(), message)
		table.insert(logs, 1, line)
		if #logs > 120 then
			table.remove(logs)
		end
		if Config.RemoteProbeLog then
			warn("[AR Probe]", message)
		end
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
				log(remote.Name .. ":FireServer(" .. table.concat(parts, ", ") .. ")")
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
				log(remote.Name .. ":InvokeServer(" .. table.concat(parts, ", ") .. ")")
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

	return {
		log = log,
		getLogs = getLogs,
		clearLogs = clearLogs,
		dumpLogs = dumpLogs,
		listRemotes = listRemotes,
		logPlayerState = logPlayerState,
		installRemoteLogger = installRemoteLogger,
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
