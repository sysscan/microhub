local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local ReplicatedFirst = opts.replicatedFirst

	local cachedCharacter = LocalPlayer.Character
	local cachedHumanoid = cachedCharacter and cachedCharacter:FindFirstChildOfClass("Humanoid")
	local cachedRoot = cachedCharacter and cachedCharacter:FindFirstChild("HumanoidRootPart")
	local cachedHead = cachedCharacter and cachedCharacter:FindFirstChild("Head")

	local function bindCharacter(character)
		cachedCharacter = character
		cachedHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		cachedRoot = character and character:FindFirstChild("HumanoidRootPart")
		cachedHead = character and character:FindFirstChild("Head")
	end

	LocalPlayer.CharacterAdded:Connect(bindCharacter)
	LocalPlayer.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end)

	local function getCharacter()
		if cachedCharacter and cachedCharacter.Parent then
			return cachedCharacter
		end
		bindCharacter(LocalPlayer.Character)
		return cachedCharacter
	end

	local function getHumanoid()
		if cachedHumanoid and cachedHumanoid.Parent then
			return cachedHumanoid
		end
		bindCharacter(LocalPlayer.Character)
		return cachedHumanoid
	end

	local function getRoot()
		if cachedRoot and cachedRoot.Parent then
			return cachedRoot
		end
		bindCharacter(LocalPlayer.Character)
		return cachedRoot
	end

	local function getHead()
		if cachedHead and cachedHead.Parent then
			return cachedHead
		end
		bindCharacter(LocalPlayer.Character)
		return cachedHead
	end

	local function isAlive()
		local humanoid = getHumanoid()
		return humanoid ~= nil and humanoid.Health > 0
	end

	local function getPlayerFolder()
		return ReplicatedFirst:FindFirstChild(tostring(LocalPlayer.UserId))
	end

	local function isSpawned()
		local folder = getPlayerFolder()
		local values = folder and folder:FindFirstChild("Values")
		local spawned = values and values:FindFirstChild("Spawned")
		return spawned and spawned:IsA("BoolValue") and spawned.Value == true
	end

	local function getAliveFolder()
		local folder = getPlayerFolder()
		return folder and folder:FindFirstChild("Alive")
	end

	local function getEquippedTool()
		local character = getCharacter()
		if not character then
			return nil
		end
		return character:FindFirstChildOfClass("Tool")
	end

	local function findAimPart(character, preferHead)
		if not character then
			return nil
		end
		local parts = preferHead and { "SmallHead", "Head", "SmallTorso", "Torso", "HumanoidRootPart" }
			or { "SmallTorso", "SmallHead", "Torso", "HumanoidRootPart", "Head" }
		for _, name in parts do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				return part
			end
		end
		return nil
	end

	return {
		getCharacter = getCharacter,
		getHumanoid = getHumanoid,
		getRoot = getRoot,
		getHead = getHead,
		isAlive = isAlive,
		getPlayerFolder = getPlayerFolder,
		isSpawned = isSpawned,
		getAliveFolder = getAliveFolder,
		getEquippedTool = getEquippedTool,
		findAimPart = findAimPart,
	}
end

return M
