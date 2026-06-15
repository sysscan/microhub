local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage
	local ReplicatedFirst = opts.replicatedFirst
	local LocalPlayer = opts.localPlayer

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 20)
	local valuesFolder = ReplicatedFirst:WaitForChild("Values", 20)
	local eventsFolder = ReplicatedFirst:WaitForChild("Events", 20)
	local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 20)

	local gunData
	local ammoIdentifiers
	local convertAmmoIdentifiers
	local getCurrentInventory
	local depleteAmmoInInv

	local okGun, loadedGun = pcall(function()
		return require(modulesFolder:WaitForChild("GunData"))
	end)
	if okGun then
		gunData = loadedGun
	end

	local okAmmo, loadedAmmo = pcall(function()
		return require(modulesFolder:WaitForChild("AmmoIdentifiers"))
	end)
	if okAmmo then
		ammoIdentifiers = loadedAmmo
	end

	local okConvert, loadedConvert = pcall(function()
		return require(modulesFolder:WaitForChild("ConvertAmmoIdentifiers"))
	end)
	if okConvert then
		convertAmmoIdentifiers = loadedConvert
	end

	if eventsFolder then
		local inventoryEvent = eventsFolder:FindFirstChild("GetCurrentInventory")
		if inventoryEvent and inventoryEvent:IsA("BindableFunction") then
			getCurrentInventory = inventoryEvent
		end
		local depleteEvent = eventsFolder:FindFirstChild("DepleteAmmoInInv")
		if depleteEvent and depleteEvent:IsA("BindableEvent") then
			depleteAmmoInInv = depleteEvent
		end
	end

	local function getRemote(name)
		return remotesFolder and remotesFolder:FindFirstChild(name)
	end

	local function getValue(name)
		return valuesFolder and valuesFolder:FindFirstChild(name)
	end

	local function getInventory()
		if not getCurrentInventory then
			return nil
		end
		local invokeOk, inventory = pcall(function()
			return getCurrentInventory:Invoke()
		end)
		if invokeOk then
			return inventory
		end
		return nil
	end

	local function getAmmoSlotForGun(gunName, inventory)
		if not ammoIdentifiers or not convertAmmoIdentifiers or not inventory or not inventory.Spaces then
			return nil
		end
		local ammoTypes = ammoIdentifiers[gunName]
		if not ammoTypes then
			return nil
		end
		local allowed = convertAmmoIdentifiers(ammoTypes)
		local bestSlot
		local bestAmount = 0
		for slot, item in pairs(inventory.Spaces) do
			if typeof(item) == "table" and item.Amount and item.Amount > 0 and table.find(allowed, item.Name) then
				if item.Amount > bestAmount then
					bestAmount = item.Amount
					bestSlot = slot
				end
			end
		end
		return bestSlot
	end

	local function consumeAmmoForGun(gunName)
		local inventory = getInventory()
		if not inventory then
			return false
		end
		local slot = getAmmoSlotForGun(gunName, inventory)
		if not slot then
			return false
		end
		local item = inventory.Spaces[slot]
		if not item or item.Amount <= 0 then
			return false
		end
		item.Amount -= 1
		if depleteAmmoInInv then
			pcall(function()
				depleteAmmoInInv:Fire(slot)
			end)
		end
		return true
	end

	local function waitForPlayerFolder(timeout)
		local deadline = tick() + (timeout or 15)
		local key = tostring(LocalPlayer.UserId)
		while tick() < deadline do
			local folder = ReplicatedFirst:FindFirstChild(key)
			if folder then
				return folder
			end
			task.wait(0.25)
		end
		return nil
	end

	return {
		remotesFolder = remotesFolder,
		valuesFolder = valuesFolder,
		eventsFolder = eventsFolder,
		modulesFolder = modulesFolder,
		gunData = gunData,
		getRemote = getRemote,
		getValue = getValue,
		getInventory = getInventory,
		getAmmoSlotForGun = getAmmoSlotForGun,
		consumeAmmoForGun = consumeAmmoForGun,
		waitForPlayerFolder = waitForPlayerFolder,
	}
end

return M
