local TeleportService = game:GetService("TeleportService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local playerData = opts.playerData
	local debugger = opts.debugger
	local LocalPlayer = opts.localPlayer

	local hopping = false

	local function dbg(tag, detail)
		if debugger then
			debugger.log(tag, detail)
		end
	end

	local function debugPrint(...)
		if Config.DebugLivePrint then
			print("[VVUltimatum]", ...)
		end
	end

	local function resolvePlaceId(placeName: string): number?
		local placeIds = playerData.getPlaceIds()
		if placeIds and placeIds.IDs and placeIds.IDs[placeName] then
			return placeIds.IDs[placeName]
		end
		return Constants.PLACE_IDS[placeName]
	end

	local function normalizeServers(servers): { { key: string, value: any } }
		local list: { { key: string, value: any } } = {}
		if type(servers) ~= "table" then
			return list
		end

		for key, entry in servers do
			if type(entry) == "table" then
				local jobId = entry.key or key
				local value = entry.value or entry
				if type(jobId) == "string" and type(value) == "table" then
					table.insert(list, { key = jobId, value = value })
				end
			end
		end

		if #list == 0 then
			for _, entry in ipairs(servers) do
				if type(entry) == "table" and type(entry.key) == "string" then
					table.insert(list, entry)
				end
			end
		end

		table.sort(list, function(a, b)
			local pa = tonumber(a.value.PCount) or 0
			local pb = tonumber(b.value.PCount) or 0
			return pa < pb
		end)

		return list
	end

	local function joinServer(jobId: string, targetPlaceId: number?): boolean
		if type(jobId) ~= "string" or jobId == "" or jobId == game.JobId then
			return false
		end
		dbg("world_join_attempt", { jobId = jobId, targetPlaceId = targetPlaceId })
		return remotes.finishLoading(jobId, true) == true
	end

	local function teleportViaServerCode(placeId: number): boolean
		local placeIds = playerData.getPlaceIds()
		if not placeIds or not placeIds.ServerCodes then
			return false
		end
		local code = placeIds.ServerCodes[placeId]
		if type(code) ~= "string" or code == "" then
			return false
		end
		debugPrint("teleport via server code", placeId)
		return remotes.teleportToServer({
			PlaceId = placeId,
			ReserveServerCode = code,
		}) == true
	end

	local function teleportViaService(placeId: number): boolean
		if not placeId or placeId == game.PlaceId then
			return false
		end
		debugPrint("teleport via TeleportService", placeId)
		local ok = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { LocalPlayer })
		return ok
	end

	local function teleportToPlace(placeName)
		if hopping then
			return false
		end
		if type(placeName) ~= "string" or placeName == "" then
			placeName = Config.TeleportPlace
		end

		local targetPlaceId = resolvePlaceId(placeName)
		if not targetPlaceId then
			debugPrint("unknown place", placeName)
			return false
		end

		hopping = true
		dbg("world_teleport_start", { place = placeName, placeId = targetPlaceId })

		local function finish(result: boolean): boolean
			dbg("world_teleport_finish", { place = placeName, ok = result })
			hopping = false
			return result
		end

		playerData.waitForProfile(20)

		if targetPlaceId == game.PlaceId then
			local ok, servers = remotes.getServerList({
				TargetPlace = placeName,
				AllowRaidServers = false,
			})
			if ok and type(servers) == "table" then
				for _, entry in normalizeServers(servers) do
					local value = entry.value
					if value.PlaceId == nil or value.PlaceId == targetPlaceId then
						if joinServer(entry.key, targetPlaceId) then
							return finish(true)
						end
					end
				end
			end
			debugPrint("already on place; no joinable servers for hop")
			return finish(false)
		end

		local ok, servers = remotes.getServerList({
			TargetPlace = placeName,
			AllowRaidServers = false,
		})

		if ok and type(servers) == "table" then
			for _, entry in normalizeServers(servers) do
				local value = entry.value
				if value.PlaceId == nil or value.PlaceId == targetPlaceId then
					if joinServer(entry.key, targetPlaceId) then
						return finish(true)
					end
				end
			end
		end

		if teleportViaServerCode(targetPlaceId) then
			return finish(true)
		end

		if remotes.teleportToServer({ PlaceId = targetPlaceId }) then
			return finish(true)
		end

		if teleportViaService(targetPlaceId) then
			return finish(true)
		end

		debugPrint("no joinable servers for", placeName)
		return finish(false)
	end

	local function serverHop()
		if hopping then
			return false
		end

		local placeName = nil
		local placeIds = playerData.getPlaceIds()
		if placeIds and typeof(placeIds.GetPlaceInfo) == "function" then
			local ok, info = pcall(placeIds.GetPlaceInfo, placeIds)
			if ok and info then
				placeName = info.PlaceName
			end
		end
		if not placeName then
			for name, id in Constants.PLACE_IDS do
				if id == game.PlaceId then
					placeName = name
					break
				end
			end
		end
		if not placeName then
			return false
		end
		return teleportToPlace(placeName)
	end

	local function teleportToPlayer(username)
		if type(username) ~= "string" or username == "" then
			return false
		end
		local ok, result = remotes.teleportToPlayer(username)
		if ok == true or result == true then
			return true
		end
		return false
	end

	return {
		teleportToPlace = teleportToPlace,
		serverHop = serverHop,
		teleportToPlayer = teleportToPlayer,
	}
end

return M
