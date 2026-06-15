local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local ReplicatedFirst = opts.replicatedFirst

	local cachedCharacter = LocalPlayer.Character
	local cachedHumanoid = cachedCharacter and cachedCharacter:FindFirstChildWhichIsA("Humanoid", true)
	local cachedRoot = cachedCharacter
		and (
			cachedCharacter:FindFirstChild("SmallTorso", true)
			or cachedCharacter:FindFirstChild("HumanoidRootPart", true)
			or cachedCharacter:FindFirstChild("Torso", true)
		)
	local cachedHead = cachedCharacter
		and (cachedCharacter:FindFirstChild("SmallHead", true) or cachedCharacter:FindFirstChild("Head", true))

	local function bindCharacter(character)
		cachedCharacter = character
		cachedHumanoid = character and character:FindFirstChildWhichIsA("Humanoid", true)
		cachedRoot = character
			and (
				character:FindFirstChild("SmallTorso", true)
				or character:FindFirstChild("HumanoidRootPart", true)
				or character:FindFirstChild("Torso", true)
			)
		cachedHead = character
			and (character:FindFirstChild("SmallHead", true) or character:FindFirstChild("Head", true))
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

	local function getCharacterRoot(character)
		if not character then
			return nil
		end
		return character:FindFirstChild("SmallTorso", true)
			or character:FindFirstChild("HumanoidRootPart", true)
			or character:FindFirstChild("Torso", true)
	end

	local function getCharacterHead(character)
		if not character then
			return nil
		end
		return character:FindFirstChild("SmallHead", true) or character:FindFirstChild("Head", true)
	end

	local function getPlayerCharacter(player)
		if not player then
			return nil
		end
		local char = player.Character
		if char and char.Parent and getCharacterRoot(char) then
			return char
		end
		local byName = workspace:FindFirstChild(player.Name)
		if byName and byName:IsA("Model") and getCharacterRoot(byName) then
			return byName
		end
		local playersRoot = workspace:FindFirstChild("Players")
		if playersRoot then
			local inFolder = playersRoot:FindFirstChild(player.Name)
				or playersRoot:FindFirstChild(tostring(player.UserId))
			if inFolder and inFolder:IsA("Model") and getCharacterRoot(inFolder) then
				return inFolder
			end
		end
		return char
	end

	local function getPlayerAliveCFrame(player)
		local folder = ReplicatedFirst:FindFirstChild(tostring(player.UserId))
		local alive = folder and folder:FindFirstChild("Alive")
		local cf = alive and alive:FindFirstChild("CFrame")
		if cf and cf:IsA("CFrameValue") then
			return cf.Value
		end
		return nil
	end

	local function isPlayerSpawnedAlive(player)
		local folder = ReplicatedFirst:FindFirstChild(tostring(player.UserId))
		local values = folder and folder:FindFirstChild("Values")
		local spawned = values and values:FindFirstChild("Spawned")
		local alive = values and values:FindFirstChild("Alive")
		if spawned and spawned:IsA("BoolValue") and not spawned.Value then
			return false
		end
		if alive and alive:IsA("BoolValue") and not alive.Value then
			return false
		end
		local health = getReplicatedHealth(player)
		if health ~= nil then
			return health > 0
		end
		return true
	end

	local function getReplicatedHealth(player)
		local folder = ReplicatedFirst:FindFirstChild(tostring(player.UserId))
		local alive = folder and folder:FindFirstChild("Alive")
		local health = alive and alive:FindFirstChild("Health")
		if health and health:IsA("NumberValue") then
			return health.Value
		end
		return nil
	end

	local function isCharacterAlive(character, player)
		if not character or not character.Parent then
			return false
		end
		if player and not isPlayerSpawnedAlive(player) then
			return false
		end
		local root = getCharacterRoot(character)
		if not root then
			return false
		end
		local humanoid = character:FindFirstChildWhichIsA("Humanoid", true)
		local health
		if humanoid then
			health = humanoid.Health
		end
		if player then
			local replicatedHealth = getReplicatedHealth(player)
			if replicatedHealth ~= nil then
				health = replicatedHealth
			end
		end
		if health == nil then
			return false
		end
		if health <= 0 then
			return false
		end
		if not humanoid then
			humanoid = {
				Health = health,
				MaxHealth = 100,
			}
		end
		return true, humanoid, root
	end

	local function getHealthRatio(player, character, humanoid)
		local health = humanoid.Health
		local replicatedHealth = player and getReplicatedHealth(player)
		if replicatedHealth ~= nil then
			health = replicatedHealth
		end
		return health / math.max(humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100, 1)
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
			local part = character:FindFirstChild(name, true)
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
		getCharacterRoot = getCharacterRoot,
		getCharacterHead = getCharacterHead,
		getPlayerCharacter = getPlayerCharacter,
		getPlayerAliveCFrame = getPlayerAliveCFrame,
		isPlayerSpawnedAlive = isPlayerSpawnedAlive,
		getReplicatedHealth = getReplicatedHealth,
		isCharacterAlive = isCharacterAlive,
		getHealthRatio = getHealthRatio,
		isAlive = isAlive,
		getPlayerFolder = getPlayerFolder,
		isSpawned = isSpawned,
		getAliveFolder = getAliveFolder,
		getEquippedTool = getEquippedTool,
		findAimPart = findAimPart,
	}
end

return M
