local M = {}

function M.create(opts)
	local remoteEvents = opts.remoteEvents

	local blood = 100
	local hunger = 0
	local thirst = 0

	local function onBlood(value: number)
		blood = tonumber(value) or blood
	end

	local function onHunger(value: number)
		hunger = tonumber(value) or hunger
	end

	local function onThirst(value: number)
		thirst = tonumber(value) or thirst
	end

	local connections: { RBXScriptConnection } = {}

	local function bind()
		local bloodRemote = remoteEvents:FindFirstChild("UpdateBlood")
		local hungerRemote = remoteEvents:FindFirstChild("UpdateHunger")
		local thirstRemote = remoteEvents:FindFirstChild("UpdateThirst")

		if bloodRemote then
			table.insert(connections, bloodRemote.OnClientEvent:Connect(onBlood))
		end
		if hungerRemote then
			table.insert(connections, hungerRemote.OnClientEvent:Connect(onHunger))
		end
		if thirstRemote then
			table.insert(connections, thirstRemote.OnClientEvent:Connect(onThirst))
		end
	end

	local function destroy()
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
	end

	bind()

	return {
		getBlood = function()
			return blood
		end,
		getHunger = function()
			return hunger
		end,
		getThirst = function()
			return thirst
		end,
		destroy = destroy,
	}
end

return M
