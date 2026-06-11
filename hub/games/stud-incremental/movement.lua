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

	local function getAreaPart(...)
		local current = workspace:FindFirstChild("map")
		for _, name in ipairs({ ... }) do
			if not current then
				return nil
			end
			current = current:FindFirstChild(name)
		end
		return current
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
		if Config.AutoAfkStudPlatform then
			local platform = getStudPlatform()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if platform and root then
				local flat = Vector3.new(root.Position.X - platform.Position.X, 0, root.Position.Z - platform.Position.Z)
				if flat.Magnitude > math.max(platform.Size.X, platform.Size.Z) * 0.6 then
					teleportTo(platform)
				end
			end
		end
	end

	local function teleportToWorld2Stars()
		return teleportTo(getAreaPart("Areas2", "area1", "3DStarSpawn") or workspace:FindFirstChild("3DStarSpawn"))
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
		teleportToWorld2Stars = teleportToWorld2Stars,
	}
end

return M
