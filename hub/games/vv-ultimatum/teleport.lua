local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local playerData = opts.playerData

	local hopping = false

	local function joinServer(jobId: string): boolean
		if type(jobId) ~= "string" or jobId == "" or jobId == game.JobId then
			return false
		end
		return remotes.finishLoading(jobId, true) == true
	end

	local function teleportToPlace(placeName)
		if hopping then
			return false
		end
		if type(placeName) ~= "string" or placeName == "" then
			placeName = Config.TeleportPlace
		end

		hopping = true

		local function finish(result: boolean): boolean
			hopping = false
			return result
		end

		local ok, servers = remotes.getServerList({
			TargetPlace = placeName,
			AllowRaidServers = false,
		})

		if ok and type(servers) == "table" then
			for _, entry in servers do
				if type(entry) == "table" and joinServer(entry.key) then
					return finish(true)
				end
			end
		end

		local placeId = Constants.PLACE_IDS[placeName]
		if placeId and remotes.teleportToServer({ PlaceId = placeId }) then
			return finish(true)
		end

		warn("[VV Ultimatum] No joinable servers for", placeName)
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
		return remotes.teleportToPlayer(username)
	end

	return {
		teleportToPlace = teleportToPlace,
		serverHop = serverHop,
		teleportToPlayer = teleportToPlayer,
	}
end

return M
