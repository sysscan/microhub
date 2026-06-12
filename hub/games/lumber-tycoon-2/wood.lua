local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local Util = opts.util
	local Remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local logModels = workspace:WaitForChild("LogModels", 30)
	local playerModels = workspace:WaitForChild("PlayerModels", 30)
	local lastDragNotify = 0

	local function getBringTarget()
		local root = Util.getRoot(LocalPlayer)
		if not root then
			return nil
		end
		return root.CFrame * CFrame.new(0, 0, -6)
	end

	local function getSellTarget()
		return Util.getLiveSellWoodPosition() or Constants.SELL_WOOD_POSITION
	end

	local function spreadOffset(index: number): CFrame
		local column = index % 4
		local row = math.floor(index / 4)
		return CFrame.new(column * 2.5 - 3.75, 0, row * 2.5)
	end

	local function moveOwnedWoodInFolder(folder: Instance, targetCFrame: CFrame, maxRange: number): boolean
		local root = Util.getRoot(LocalPlayer)
		if not root then
			return false
		end

		local moved = false
		local movedIndex = 0
		local maxRangeSq = maxRange * maxRange
		local origin = root.Position

		for _, child in folder:GetChildren() do
			if not child:IsA("Model") then
				continue
			end
			if not Util.isOwnedBy(LocalPlayer, child) then
				continue
			end
			local section = Util.getWoodSection(child)
			if not section then
				continue
			end
			if Util.distanceSq(origin, section.Position) > maxRangeSq then
				continue
			end
			local destination = targetCFrame * spreadOffset(movedIndex)
			if Util.moveModelWoodTo(child, destination) then
				moved = true
				movedIndex += 1
			end
		end
		return moved
	end

	local function notifyDragIfNeeded(moved: boolean, folder: Instance)
		if not moved or os.clock() - lastDragNotify < 0.45 then
			return
		end
		lastDragNotify = os.clock()
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and Util.isOwnedBy(LocalPlayer, child) then
				Remotes.notifyDragging(child)
				break
			end
		end
	end

	local function bringOwnedLogs()
		if not Config.BringLogs then
			return
		end
		local target = getBringTarget()
		if not target then
			return
		end
		local maxRange = math.clamp(tonumber(Config.BringLogsRange) or 80, 20, 500)
		local moved = moveOwnedWoodInFolder(logModels, target, maxRange)
		notifyDragIfNeeded(moved, logModels)
	end

	local function autoSellWood()
		if not Config.AutoSellWood then
			return
		end
		local sellTarget = getSellTarget()
		if not sellTarget then
			return
		end
		local maxRange = math.clamp(tonumber(Config.SellWoodRange) or 500, 50, 2000)
		local moved = moveOwnedWoodInFolder(logModels, CFrame.new(sellTarget), maxRange)
		notifyDragIfNeeded(moved, logModels)
	end

	local function bringOwnedPlanks()
		if not Config.BringPlanks then
			return
		end
		local target = getBringTarget()
		if not target then
			return
		end
		local maxRange = math.clamp(tonumber(Config.BringPlanksRange) or 120, 20, 500)
		local moved = moveOwnedWoodInFolder(playerModels, target, maxRange)
		notifyDragIfNeeded(moved, playerModels)
	end

	local function bringLogsNow()
		local wasEnabled = Config.BringLogs
		Config.BringLogs = true
		bringOwnedLogs()
		Config.BringLogs = wasEnabled
	end

	local function sellWoodNow()
		local wasEnabled = Config.AutoSellWood
		Config.AutoSellWood = true
		autoSellWood()
		Config.AutoSellWood = wasEnabled
	end

	local function bringPlanksNow()
		local wasEnabled = Config.BringPlanks
		Config.BringPlanks = true
		bringOwnedPlanks()
		Config.BringPlanks = wasEnabled
	end

	return {
		tickWood = function()
			bringOwnedLogs()
			autoSellWood()
			bringOwnedPlanks()
		end,
		bringLogsNow = bringLogsNow,
		sellWoodNow = sellWoodNow,
		bringPlanksNow = bringPlanksNow,
	}
end

return M
