local RunService = game:GetService("RunService")

local M = {}

local frameId = 0
local cacheFrame = -1
local cache = {}

RunService.Heartbeat:Connect(function()
	frameId += 1
end)

function M.isMonsterModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	if model:FindFirstChild("Enemy", true) then
		return true
	end
	if model:GetAttribute("ClientEntity") then
		return true
	end
	return false
end

function M.getRoot(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("RootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

function M.getHumanoid(model)
	if not model then
		return nil
	end
	return model:FindFirstChildOfClass("Humanoid")
		or model:FindFirstChild("Humanoid", true)
end

function M.isAlive(model)
	local humanoid = M.getHumanoid(model)
	if humanoid then
		return humanoid.Health > 0
	end
	return M.getRoot(model) ~= nil
end

function M.rebuildCache()
	table.clear(cache)

	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return cache
	end

	local seen = {}

	local function tryAdd(model)
		if seen[model] or not M.isMonsterModel(model) or not M.isAlive(model) then
			return
		end
		seen[model] = true
		table.insert(cache, model)
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			tryAdd(child)
		end
	end

	for _, model in folder:GetDescendants() do
		if not model:IsA("Model") or seen[model] then
			continue
		end
		if not M.isMonsterModel(model) or not M.isAlive(model) then
			continue
		end

		local parent = model.Parent
		local nested = false
		while parent and parent ~= folder do
			if parent:IsA("Model") and M.isMonsterModel(parent) then
				nested = true
				break
			end
			parent = parent.Parent
		end
		if not nested then
			tryAdd(model)
		end
	end

	return cache
end

function M.collect()
	if cacheFrame == frameId then
		return cache
	end
	cacheFrame = frameId
	return M.rebuildCache()
end

function M.invalidateCache()
	cacheFrame = -1
end

return M
