local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local services = opts.services

	local function getHumanoid()
		local character = LocalPlayer.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function teleportToZone(zoneId)
		local ZonesServiceClient = services.getZonesService()
		if not ZonesServiceClient then
			return false
		end
		return pcall(function()
			ZonesServiceClient:teleportToZone(tonumber(zoneId) or 1)
		end)
	end

	local function teleportToCurrentZone()
		local ZonesServiceClient = services.getZonesService()
		if not ZonesServiceClient then
			return false
		end
		return teleportToZone(ZonesServiceClient:getZone())
	end

	local function teleportToMaxZone()
		local ZonesServiceClient = services.getZonesService()
		if not ZonesServiceClient then
			return false
		end
		return teleportToZone(ZonesServiceClient:getMaxZone())
	end

	local function teleportToConfiguredZone()
		return teleportToZone(Config.TeleportZone or 1)
	end

	local function tickMovement()
		local humanoid = getHumanoid()
		if not humanoid then
			return
		end

		if Config.SpeedBoost then
			local speed = math.clamp(tonumber(Config.WalkSpeed) or 32, 16, Constants.MAX_SAFE_WALKSPEED)
			humanoid.WalkSpeed = speed
		end

		if Config.JumpBoost then
			local jump = math.clamp(tonumber(Config.JumpPower) or 50, 16, Constants.MAX_SAFE_JUMP)
			humanoid.JumpPower = jump
			humanoid.UseJumpPower = true
		end
	end

	return {
		teleportToZone = teleportToZone,
		teleportToCurrentZone = teleportToCurrentZone,
		teleportToMaxZone = teleportToMaxZone,
		teleportToConfiguredZone = teleportToConfiguredZone,
		tickMovement = tickMovement,
	}
end

return M
