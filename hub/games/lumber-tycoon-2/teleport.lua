local Players = game:GetService("Players")

local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local Config = opts.config
	local Constants = opts.constants
	local Util = opts.util

	local function teleportTo(position: Vector3?): boolean
		local root = Util.getRoot(LocalPlayer)
		if not root or not position then
			return false
		end
		return pcall(function()
			root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
		end)
	end

	local function teleportNamed(name: string?): boolean
		if not name or name == "" then
			return false
		end
		local position = Constants.WAYPOINTS[name]
		if not position then
			warn("[LT2] unknown teleport:", name)
			return false
		end
		return teleportTo(position)
	end

	local function teleportConfigured()
		if Config.TeleportLocation == "My Plot" then
			return teleportToMyPlot()
		end
		return teleportNamed(Config.TeleportLocation)
	end

	local function teleportToMyPlot()
		local position = Util.getOwnedPropertyPosition(LocalPlayer)
		if not position then
			warn("[LT2] no owned plot found")
			return false
		end
		return teleportTo(position)
	end

	local function teleportToSellWood()
		local position = Util.getLiveSellWoodPosition() or Constants.SELL_WOOD_POSITION
		return teleportTo(position)
	end

	local function teleportNearestPlayer(): boolean
		local root = Util.getRoot(LocalPlayer)
		if not root then
			return false
		end
		local nearestPlayer = nil
		local nearestDist = math.huge
		for _, player in Players:GetPlayers() do
			if player ~= LocalPlayer and Util.isAlive(player) then
				local targetRoot = Util.getRoot(player)
				if targetRoot then
					local dist = Util.distance(root.Position, targetRoot.Position)
					if dist < nearestDist then
						nearestDist = dist
						nearestPlayer = player
					end
				end
			end
		end
		if not nearestPlayer then
			return false
		end
		local targetRoot = Util.getRoot(nearestPlayer)
		if not targetRoot then
			return false
		end
		return pcall(function()
			root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
		end)
	end

	return {
		teleportTo = teleportTo,
		teleportNamed = teleportNamed,
		teleportConfigured = teleportConfigured,
		teleportNearestPlayer = teleportNearestPlayer,
		teleportToMyPlot = teleportToMyPlot,
		teleportToSellWood = teleportToSellWood,
	}
end

return M
