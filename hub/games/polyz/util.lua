local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer

	local cachedCharacter = LocalPlayer.Character
	local cachedHumanoid = cachedCharacter and cachedCharacter:FindFirstChildOfClass("Humanoid")
	local cachedRoot = cachedCharacter and cachedCharacter:FindFirstChild("HumanoidRootPart")
	local cachedVariables = LocalPlayer:FindFirstChild("Variables")
	local cachedPlayerData = LocalPlayer:FindFirstChild("PlayerData")
	local cachedCameraController = cachedCharacter and cachedCharacter:FindFirstChild("CameraController")

	local equippedSlot = cachedVariables and cachedVariables:GetAttribute("Equipped_Slot")
	local equippedGunName: string? = nil

	local function refreshEquippedGun()
		equippedGunName = nil
		if not (cachedVariables and cachedPlayerData) then
			return
		end
		local slot = cachedVariables:GetAttribute("Equipped_Slot")
		if type(slot) ~= "string" or slot == "" then
			return
		end
		equippedSlot = slot
		local equipped = cachedPlayerData:FindFirstChild("equipped_" .. string.lower(slot))
		if equipped and equipped.Value ~= "None" and equipped.Value ~= "" then
			equippedGunName = equipped.Value
		end
	end

	refreshEquippedGun()

	local function bindCharacter(character: Model?)
		cachedCharacter = character
		cachedHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		cachedRoot = character and character:FindFirstChild("HumanoidRootPart")
		cachedCameraController = character and character:FindFirstChild("CameraController")
	end

	if cachedVariables then
		cachedVariables:GetAttributeChangedSignal("Equipped_Slot"):Connect(function()
			refreshEquippedGun()
		end)
	end

	if cachedPlayerData then
		for _, slotName in { "equipped_primary", "equipped_secondary" } do
			local value = cachedPlayerData:FindFirstChild(slotName)
			if value then
				value:GetPropertyChangedSignal("Value"):Connect(refreshEquippedGun)
			end
		end
	end

	LocalPlayer.CharacterAdded:Connect(function(character)
		bindCharacter(character)
	end)

	LocalPlayer.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end)

	local function getCharacter()
		return cachedCharacter
	end

	local function getHumanoid()
		if cachedCharacter and cachedCharacter.Parent and cachedHumanoid and cachedHumanoid.Parent then
			return cachedHumanoid
		end
		bindCharacter(LocalPlayer.Character)
		return cachedHumanoid
	end

	local function getRoot()
		if cachedCharacter and cachedCharacter.Parent and cachedRoot and cachedRoot.Parent then
			return cachedRoot
		end
		bindCharacter(LocalPlayer.Character)
		return cachedRoot
	end

	local function isAlive()
		local humanoid = getHumanoid()
		return humanoid ~= nil and humanoid.Health > 0
	end

	local function getVariables()
		if cachedVariables and cachedVariables.Parent then
			return cachedVariables
		end
		cachedVariables = LocalPlayer:FindFirstChild("Variables")
		return cachedVariables
	end

	local function getPlayerData()
		if cachedPlayerData and cachedPlayerData.Parent then
			return cachedPlayerData
		end
		cachedPlayerData = LocalPlayer:FindFirstChild("PlayerData")
		return cachedPlayerData
	end

	local function getEquippedGunName()
		if equippedGunName then
			return equippedGunName
		end
		refreshEquippedGun()
		return equippedGunName
	end

	local function getCameraController()
		if cachedCameraController and cachedCameraController.Parent then
			return cachedCameraController
		end
		local character = getCharacter()
		cachedCameraController = character and character:FindFirstChild("CameraController")
		return cachedCameraController
	end

	return {
		getCharacter = getCharacter,
		getHumanoid = getHumanoid,
		getRoot = getRoot,
		isAlive = isAlive,
		getVariables = getVariables,
		getPlayerData = getPlayerData,
		getEquippedGunName = getEquippedGunName,
		getCameraController = getCameraController,
	}
end

return M
