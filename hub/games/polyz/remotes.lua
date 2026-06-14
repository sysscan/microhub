local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage
	local folder = ReplicatedStorage:WaitForChild("Remotes", 15)

	local function get(name)
		if not folder then
			return nil
		end
		return folder:FindFirstChild(name)
	end

	local function shootEnemy(enemyModel, hitPart, hitPosition, pierceCount, gunName)
		local remote = get("ShootEnemy")
		if not remote then
			return false
		end
		local ok = pcall(function()
			remote:FireServer(enemyModel, hitPart, hitPosition, pierceCount or 0, gunName)
		end)
		return ok
	end

	return {
		folder = folder,
		get = get,
		shootEnemy = shootEnemy,
	}
end

return M
