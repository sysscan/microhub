local M = {}

function M.create(opts)
	local Config = opts.config
	local Util = opts.util
	local Remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local logModels = workspace:WaitForChild("LogModels", 30)
	local lastDragNotify = 0

	local function getWoodSection(model: Model): BasePart?
		local section = model:FindFirstChild("WoodSection", true)
		if section and section:IsA("BasePart") then
			return section
		end
		return nil
	end

	local function bringOwnedLogs()
		if not Config.BringLogs then
			return
		end

		local root = Util.getRoot(LocalPlayer)
		if not root then
			return
		end

		local target = root.CFrame * CFrame.new(0, 0, -6)
		local maxRange = math.clamp(tonumber(Config.BringLogsRange) or 80, 20, 500)
		local moved = false

		for _, child in logModels:GetChildren() do
			if not child:IsA("Model") then
				continue
			end
			if not Util.isOwnedBy(LocalPlayer, child) then
				continue
			end
			local section = getWoodSection(child)
			if not section then
				continue
			end
			if Util.distance(root.Position, section.Position) > maxRange then
				continue
			end
			pcall(function()
				section.CFrame = target
			end)
			moved = true
		end

		if moved and os.clock() - lastDragNotify > 0.45 then
			lastDragNotify = os.clock()
			for _, child in logModels:GetChildren() do
				if child:IsA("Model") and Util.isOwnedBy(LocalPlayer, child) then
					Remotes.notifyDragging(child)
					break
				end
			end
		end
	end

	local function bringLogsNow()
		local wasEnabled = Config.BringLogs
		Config.BringLogs = true
		bringOwnedLogs()
		Config.BringLogs = wasEnabled
	end

	return {
		tickWood = bringOwnedLogs,
		bringLogsNow = bringLogsNow,
	}
end

return M
