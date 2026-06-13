local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage

	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
	local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
	local bindableFunctions = ReplicatedStorage:WaitForChild("BindableFunctions")

	local getModel = bindableFunctions:WaitForChild("GetModel")
	local fetchLocalInventory = bindableFunctions:WaitForChild("FetchLocalInventory")

	local function invoke(name: string, ...)
		local remote = remoteFunctions:FindFirstChild(name)
		if not remote or not remote:IsA("RemoteFunction") then
			return false, nil
		end
		local results = { pcall(remote.InvokeServer, remote, ...) }
		local ok = table.remove(results, 1)
		if not ok then
			return false, nil
		end
		if #results == 0 then
			return true, nil
		end
		if #results == 1 then
			return true, results[1]
		end
		return true, results
	end

	return {
		events = remoteEvents,
		getModel = function(player: Player)
			return getModel:Invoke(player)
		end,
		fetchInventory = function()
			return fetchLocalInventory:Invoke()
		end,
		getNearestItem = function(take: boolean, itemModel: Model)
			return invoke("GetNearestItem", take, itemModel)
		end,
		teleportToggle = function()
			return invoke("Teleport")
		end,
		heal = function(special)
			return invoke("Heal", special)
		end,
		eat = function(special)
			return invoke("Eat", special)
		end,
		drink = function(special)
			return invoke("Drink", special)
		end,
	}
end

return M
