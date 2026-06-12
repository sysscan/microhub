local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage

	local interaction = ReplicatedStorage:WaitForChild("Interaction", 30)
	local remotes = {
		remoteProxy = interaction:WaitForChild("RemoteProxy"),
		clientIsDragging = interaction:WaitForChild("ClientIsDragging"),
		clientInteracted = interaction:WaitForChild("ClientInteracted"),
		testPing = ReplicatedStorage:WaitForChild("TestPing"),
	}

	local ping = 0.2

	local function refreshPing()
		local start = tick()
		local ok = pcall(function()
			remotes.testPing:InvokeServer()
		end)
		if ok then
			ping = math.clamp((tick() - start) / 2, 0.05, 0.5)
		end
		return ping
	end

	local function fireChop(cutEvent: Instance, payload: { [string]: any })
		return pcall(function()
			remotes.remoteProxy:FireServer(cutEvent, payload)
		end)
	end

	local function notifyDragging(itemRoot: Instance)
		return pcall(function()
			remotes.clientIsDragging:FireServer(itemRoot)
		end)
	end

	return {
		fireChop = fireChop,
		notifyDragging = notifyDragging,
		refreshPing = refreshPing,
		getPing = function()
			return ping
		end,
	}
end

return M
