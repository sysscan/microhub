local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer

	local function getHumanoid()
		local character = LocalPlayer.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function teleportTo(part)
		if not part then
			return false
		end
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end
		local target = part:IsA("BasePart") and part.CFrame or part:GetPivot()
		root.CFrame = target + Vector3.new(0, 3, 0)
		return true
	end

	local function getStudPlatform()
		local map = workspace:FindFirstChild("map")
		local areas = map and map:FindFirstChild("Areas")
		local area1 = areas and areas:FindFirstChild("area1")
		return area1 and area1:FindFirstChild("platform_detection")
	end

	local function getBlockSensor()
		local map = workspace:FindFirstChild("map")
		local areas = map and map:FindFirstChild("Areas")
		local area3 = areas and areas:FindFirstChild("area3")
		local blocks = area3 and area3:FindFirstChild("Blocks")
		local button = blocks and blocks:FindFirstChild("BlockBtn")
		return button and button:FindFirstChild("Sensor")
	end

	local function applySpeed()
		local humanoid = getHumanoid()
		if not humanoid then
			return
		end
		if Config.SpeedBoost then
			humanoid.WalkSpeed = tonumber(Config.WalkSpeed) or 32
		end
	end

	local function tickMovement()
		applySpeed()
	end

	return {
		applySpeed = applySpeed,
		tickMovement = tickMovement,
		teleportToStudPlatform = function()
			return teleportTo(getStudPlatform())
		end,
		teleportToBlockButton = function()
			return teleportTo(getBlockSensor())
		end,
	}
end

return M
