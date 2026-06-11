local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
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

	local function getPlantFarmPot()
		return getAreaPart("Areas", "area5", "Row1", "Pot1", "Collect")
			or getAreaPart("Areas", "area5", "Row1", "Pot1")
	end

	local function getRuneSensor()
		local runes = workspace:FindFirstChild("Runes")
		local runesModel = runes and runes:FindFirstChild("RUNES")
		return runesModel and runesModel:FindFirstChild("sensor")
	end

	local function findWorld2Part(partName)
		local candidates = {}
		local world2 = workspace:FindFirstChild("World2")
		local world2Area1 = world2 and world2:FindFirstChild("Area1")
		if world2Area1 then
			table.insert(candidates, world2Area1)
		end
		local map = workspace:FindFirstChild("map")
		if map then
			local paths = {
				{ "World2", "Area1" },
				{ "Areas2", "area1" },
				{ "Areas", "area6" },
			}
			for _, path in ipairs(paths) do
				local folder = map
				for _, segment in ipairs(path) do
					folder = folder and folder:FindFirstChild(segment)
				end
				if folder then
					table.insert(candidates, folder)
				end
			end
		end
		for _, folder in ipairs(candidates) do
			local part = folder:FindFirstChild(partName)
			if part then
				return part
			end
		end
		return nil
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

		if Config.AutoUnlockSpaceRunes then
			local world2 = LocalPlayer:FindFirstChild("World2Area1Stats")
			local unlocked = world2 and world2:FindFirstChild("SpaceRunesUnlocked")
			local stars = world2 and world2:FindFirstChild("Stars")
			local unlockCost = (Constants and Constants.SPACE_RUNES_UNLOCK_COST) or 500
			if unlocked and not unlocked.Value and stars and stars.Value >= unlockCost then
				local button = findWorld2Part("SpaceRunesUnlockButton")
				local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if button and root then
					local pos = button:IsA("BasePart") and button.Position or button:GetPivot().Position
					if (root.Position - pos).Magnitude > 12 then
						teleportTo(button)
					end
				end
			end
		end

		local onRuneSensor = false
		if Config.AutoOpenRunes then
			local statsFolder = LocalPlayer:FindFirstChild("Stats")
			local studs = statsFolder and statsFolder:FindFirstChild("Studs")
			local minStuds = tonumber(Config.MinRuneStuds) or 5000
			local sensor = getRuneSensor()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if studs and studs.Value >= minStuds and sensor and root then
				onRuneSensor = true
				if (root.Position - sensor.Position).Magnitude > 8 then
					teleportTo(sensor)
				end
			end
		end
		if not onRuneSensor and Config.AutoAfkStudPlatform then
			local platform = getStudPlatform()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if platform and root then
				local flat = Vector3.new(root.Position.X - platform.Position.X, 0, root.Position.Z - platform.Position.Z)
				if flat.Magnitude > math.max(platform.Size.X, platform.Size.Z) * 0.6 then
					teleportTo(platform)
				end
			end
		end
		if Config.AutoAfkPlantArea then
			local pot = getPlantFarmPot()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if pot and root then
				local pos = pot:IsA("BasePart") and pot.Position or pot:GetPivot().Position
				local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
				if flat.Magnitude > 40 then
					teleportTo(pot)
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
		teleportToPlantFarm = function()
			return teleportTo(getPlantFarmPot())
		end,
		teleportToRuneSensor = function()
			return teleportTo(getRuneSensor())
		end,
		teleportToSpaceRunesUnlock = function()
			return teleportTo(findWorld2Part("SpaceRunesUnlockButton"))
		end,
		teleportToWorld2Stars = teleportToWorld2Stars,
	}
end

return M
