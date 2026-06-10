--[[
	Tha Bronx 3 — full port of GetRioToday/16472538603-ThaBronx3
	https://github.com/GetRioToday/16472538603-ThaBronx3

	Verify AC bypass: LocalPlayer:GetAttribute("LastACPos") should stay nil.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local World = workspace:FindFirstChild("World") or workspace

local Config = {
	MovementBypass = true,
	SpeedBoost = false,
	JumpBoost = false,
	InstantEquip = false,
	InstantPrompts = false,
	NoFallRagdoll = false,
	StudioFarm = false,
	ShowHUD = true,
	WalkSpeed = 32,
	JumpPower = 60,
}

local BOOST_WALK_SPEED = Config.WalkSpeed
local BOOST_JUMP_POWER = Config.JumpPower

local koolAidFarmRunning = false
local ltkDupeRunning = false

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

-- ---------------------------------------------------------------------------
-- Utilities (repo scripts expect Rio / Utility / Thread / Actions globals)
-- ---------------------------------------------------------------------------

local function notify(text, title, duration)
	title = title or "Tha Bronx 3"
	duration = duration or 5
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration,
		})
	end)
	warn("[ThaBronx3]", title, "-", text)
end

local function sleep(seconds)
	task.wait(seconds)
end

local function findPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function waitForPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, 20)
	end
	return current
end

local function getCharacter()
	return LocalPlayer.Character
end

local function getHumanoid()
	local character = getCharacter()
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
	local character = getCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(where)
	local root = getRootPart()
	if not root then
		return false
	end

	local target
	if typeof(where) == "Vector3" then
		target = CFrame.new(where)
	elseif typeof(where) == "CFrame" then
		target = where
	elseif typeof(where) == "Instance" then
		if where:IsA("BasePart") then
			target = where.CFrame
		elseif where:IsA("Model") then
			target = where:GetPivot()
		elseif where:IsA("ProximityPrompt") then
			local parent = where.Parent
			if parent and parent:IsA("BasePart") then
				target = parent.CFrame
			end
		end
	end

	if not target then
		return false
	end

	root.CFrame = target + Vector3.new(0, 3, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function firePrompt(prompt, holdTime)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if typeof(fireproximityprompt) == "function" then
		fireproximityprompt(prompt, holdTime or 0)
		return
	end
	prompt:InputHoldBegin()
	task.wait(0)
	prompt:InputHoldEnd()
end

local function findItem(name)
	local character = getCharacter()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if character then
		local tool = character:FindFirstChild(name)
		if tool then
			return tool
		end
	end
	if backpack then
		return backpack:FindFirstChild(name)
	end
	return nil
end

local function getStoredFolder()
	return LocalPlayer:FindFirstChild("stored")
		or LocalPlayer:FindFirstChild("Stored")
		or findPath(LocalPlayer, "PlayerData", "stored")
end

local function readNumberValue(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local value = parent:FindFirstChild(name)
		if value and value:IsA("ValueBase") and typeof(value.Value) == "number" then
			return value.Value
		end
	end
	return nil
end

local function getMoney()
	local stored = getStoredFolder()
	local cash = readNumberValue(stored, { "Cash", "Money", "Wallet", "Clean" })
	if cash ~= nil then
		return cash
	end
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	cash = readNumberValue(leaderstats, { "Cash", "Money", "Wallet" })
	return cash or 0
end

local function getBankMoney()
	local stored = getStoredFolder()
	return readNumberValue(stored, { "Bank", "BankMoney", "BankCash", "Savings" }) or 0
end

local function getGameRemotes()
	return ReplicatedStorage:FindFirstChild("GameRemotes")
		or ReplicatedStorage:FindFirstChild("Remotes")
		or ReplicatedStorage:FindFirstChild("RemoteEvents")
end

local function invokeRemote(remoteName, ...)
	local remotes = getGameRemotes()
	if not remotes then
		return false
	end
	local remote = remotes:FindFirstChild(remoteName, true)
	if not remote then
		return false
	end
	if remote:IsA("RemoteFunction") then
		local ok = pcall(remote.InvokeServer, remote, ...)
		return ok
	end
	if remote:IsA("RemoteEvent") then
		local ok = pcall(remote.FireServer, remote, ...)
		return ok
	end
	return false
end

local function withdrawCash(amount)
	local remotes = getGameRemotes()
	if remotes then
		for _, remote in ipairs(remotes:GetDescendants()) do
			if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
				local lower = remote.Name:lower()
				if lower:find("withdraw") or lower:find("bank") then
					local ok = pcall(function()
						if remote:IsA("RemoteFunction") then
							remote:InvokeServer(amount)
						else
							remote:FireServer("Withdraw", amount)
							remote:FireServer(amount)
						end
					end)
					if ok then
						return true
					end
				end
			end
		end
	end
	return invokeRemote("BankRemote", "Withdraw", amount)
		or invokeRemote("WithdrawCash", amount)
		or invokeRemote("ATMRemote", "Withdraw", amount)
end

local function getSharedStorage()
	return ReplicatedStorage:FindFirstChild("SharedStorage")
		or findPath(ReplicatedStorage, "Shared", "Storage")
		or ReplicatedStorage
end

local function readLastAcStatus()
	local value = LocalPlayer:GetAttribute("LastACPos")
	if value == nil then
		return "excluded"
	end
	if typeof(value) == "Vector3" then
		return "tracked"
	end
	return "unknown"
end

-- ---------------------------------------------------------------------------
-- Movement bypass (Movement Disabler.luau)
-- ---------------------------------------------------------------------------

local bypassSession = {
	preConn = nil,
	postConn = nil,
	rootPart = nil,
	character = nil,
}

local function releaseRootPart(rootPart)
	if rootPart and rootPart.Parent then
		rootPart.Anchored = false
	end
end

local function teardownMovementBypass()
	if bypassSession.preConn then
		bypassSession.preConn:Disconnect()
		bypassSession.preConn = nil
	end
	if bypassSession.postConn then
		bypassSession.postConn:Disconnect()
		bypassSession.postConn = nil
	end
	releaseRootPart(bypassSession.rootPart)
	bypassSession.rootPart = nil
	bypassSession.character = nil
end

local function rootIsLive(rootPart, character)
	return rootPart
		and rootPart.Parent
		and character
		and character.Parent
		and rootPart.Parent == character
		and character == LocalPlayer.Character
end

local function applyMovementBypass(character)
	if not Config.MovementBypass then
		return
	end

	teardownMovementBypass()

	local rootPart = character:WaitForChild("HumanoidRootPart", 15)
	if not rootPart then
		warn("[ThaBronx3] HumanoidRootPart not found — bypass skipped")
		return
	end

	bypassSession.character = character
	bypassSession.rootPart = rootPart

	bypassSession.preConn = RunService.PreSimulation:Connect(function()
		local root = bypassSession.rootPart
		local char = bypassSession.character
		if not rootIsLive(root, char) then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			return
		end
		if root.Anchored then
			root.Anchored = false
		end
	end)

	bypassSession.postConn = RunService.PostSimulation:Connect(function()
		local root = bypassSession.rootPart
		local char = bypassSession.character
		if not rootIsLive(root, char) then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			releaseRootPart(root)
			return
		end
		if not root.Anchored then
			root.Anchored = true
		end
	end)
end

local function refreshMovementBypass()
	if not Config.MovementBypass then
		teardownMovementBypass()
		return
	end
	local character = LocalPlayer.Character
	if character then
		applyMovementBypass(character)
	end
end

-- ---------------------------------------------------------------------------
-- Instant prompts (InstantPrompts.luau)
-- ---------------------------------------------------------------------------

local promptCache = {}
local promptAddedConn = nil

local function restorePrompt(prompt)
	local original = promptCache[prompt]
	if original ~= nil and prompt.Parent then
		prompt.HoldDuration = original
	end
	promptCache[prompt] = nil
end

local function cachePrompt(prompt)
	if promptCache[prompt] ~= nil then
		return
	end
	promptCache[prompt] = prompt.HoldDuration
	prompt.Destroying:Once(function()
		promptCache[prompt] = nil
	end)
end

local function setPromptState(enabled)
	for prompt, original in pairs(promptCache) do
		if prompt.Parent then
			prompt.HoldDuration = enabled and 0 or original
		else
			promptCache[prompt] = nil
		end
	end
	if enabled then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				cachePrompt(descendant)
				descendant.HoldDuration = 0
			end
		end
	end
end

local function teardownInstantPrompts()
	if promptAddedConn then
		promptAddedConn:Disconnect()
		promptAddedConn = nil
	end
	for prompt in pairs(promptCache) do
		restorePrompt(prompt)
	end
	table.clear(promptCache)
end

local function applyInstantPrompts()
	teardownInstantPrompts()
	if not Config.InstantPrompts then
		return
	end
	setPromptState(true)
	promptAddedConn = workspace.DescendantAdded:Connect(function(descendant)
		if not Config.InstantPrompts or not descendant:IsA("ProximityPrompt") then
			return
		end
		cachePrompt(descendant)
		descendant.HoldDuration = 0
	end)
end

-- ---------------------------------------------------------------------------
-- No fall ragdoll (No Ragdoll.lua)
-- ---------------------------------------------------------------------------

local ragdollChildConn = nil

local function teardownNoFallRagdoll()
	if ragdollChildConn then
		ragdollChildConn:Disconnect()
		ragdollChildConn = nil
	end
end

local function removeFallDamageRagdoll(character)
	local ragdoll = character:FindFirstChild("FallDamageRagdoll")
	if ragdoll then
		ragdoll:Destroy()
	end
end

local function applyNoFallRagdoll(character)
	if not Config.NoFallRagdoll then
		teardownNoFallRagdoll()
		return
	end
	character = character or LocalPlayer.Character
	if not character then
		return
	end
	teardownNoFallRagdoll()
	removeFallDamageRagdoll(character)
	ragdollChildConn = character.ChildAdded:Connect(function(child)
		if Config.NoFallRagdoll and child.Name == "FallDamageRagdoll" then
			child:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Instant equip (InstantEquip.lua / GunSettings)
-- ---------------------------------------------------------------------------

local equipCache = {}
local equipBackpackConn = nil
local equipCharacterConn = nil
local EQUIP_SETTING_NAMES = { "EquipTime", "EquipSpeed", "equipTime", "EquipDelay" }

local function isLikelyGun(tool)
	if not tool:IsA("Tool") then
		return false
	end
	if tool:FindFirstChild("Handle") == nil then
		return false
	end
	return tool:GetAttribute("Gun") == true
		or tool:FindFirstChild("Settings") ~= nil
		or tool:FindFirstChild("GunSettings") ~= nil
		or tool:FindFirstChild("Ammo") ~= nil
		or tool:FindFirstChild("Mag") ~= nil
		or string.find(tool.Name:lower(), "gun") ~= nil
end

local function rememberEquipValue(tool, object, value)
	if not equipCache[tool] then
		equipCache[tool] = {}
	end
	if equipCache[tool][object] == nil then
		equipCache[tool][object] = value
	end
end

local function restoreEquipTool(tool)
	local saved = equipCache[tool]
	if not saved then
		return
	end
	for object, value in pairs(saved) do
		if typeof(object) == "Instance" and object.Parent then
			if object:IsA("ValueBase") then
				object.Value = value
			end
		elseif typeof(object) == "string" and tool.Parent then
			tool:SetAttribute(object, value)
		end
	end
	equipCache[tool] = nil
end

local function modifyGunTool(tool, enabled)
	if not isLikelyGun(tool) then
		return
	end

	for _, name in ipairs(EQUIP_SETTING_NAMES) do
		local attr = tool:GetAttribute(name)
		if typeof(attr) == "number" then
			if enabled then
				rememberEquipValue(tool, name, attr)
				tool:SetAttribute(name, 0)
			elseif equipCache[tool] and equipCache[tool][name] ~= nil then
				tool:SetAttribute(name, equipCache[tool][name])
			end
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if table.find(EQUIP_SETTING_NAMES, descendant.Name) then
			if descendant:IsA("ValueBase") and typeof(descendant.Value) == "number" then
				if enabled then
					rememberEquipValue(tool, descendant, descendant.Value)
					descendant.Value = 0
				elseif equipCache[tool] and equipCache[tool][descendant] ~= nil then
					descendant.Value = equipCache[tool][descendant]
				end
			end
		end
	end

	local settingsModule = tool:FindFirstChild("Settings") or tool:FindFirstChild("GunSettings")
	if settingsModule and settingsModule:IsA("ModuleScript") then
		local ok, settings = pcall(require, settingsModule)
		if ok and typeof(settings) == "table" then
			for _, key in ipairs(EQUIP_SETTING_NAMES) do
				if typeof(settings[key]) == "number" then
					if enabled then
						rememberEquipValue(tool, "module:" .. key, settings[key])
						settings[key] = 0
					elseif equipCache[tool] and equipCache[tool]["module:" .. key] ~= nil then
						settings[key] = equipCache[tool]["module:" .. key]
					end
				end
			end
		end
	end

	if not enabled then
		restoreEquipTool(tool)
	end
end

local function scanInstantEquip(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			modifyGunTool(child, Config.InstantEquip)
		end
	end
end

local function teardownInstantEquip()
	if equipBackpackConn then
		equipBackpackConn:Disconnect()
		equipBackpackConn = nil
	end
	if equipCharacterConn then
		equipCharacterConn:Disconnect()
		equipCharacterConn = nil
	end

	for tool in pairs(equipCache) do
		if typeof(tool) == "Instance" and tool:IsA("Tool") then
			restoreEquipTool(tool)
		end
	end
	table.clear(equipCache)
end

local function onGunAdded(child)
	if Config.InstantEquip and child:IsA("Tool") then
		modifyGunTool(child, true)
	end
end

local function bindInstantEquipCharacter(character)
	if equipCharacterConn then
		equipCharacterConn:Disconnect()
		equipCharacterConn = nil
	end
	if not Config.InstantEquip or not character then
		return
	end
	scanInstantEquip(character)
	equipCharacterConn = character.ChildAdded:Connect(onGunAdded)
end

local function applyInstantEquip()
	teardownInstantEquip()
	if not Config.InstantEquip then
		return
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	scanInstantEquip(backpack)
	scanInstantEquip(getCharacter())

	if backpack then
		equipBackpackConn = backpack.ChildAdded:Connect(onGunAdded)
	end
	bindInstantEquipCharacter(getCharacter())
end

-- ---------------------------------------------------------------------------
-- Studio farm (StudioFarm.luau)
-- ---------------------------------------------------------------------------

local studioThreads = {}

local function stopStudioFarmThreads()
	for _, thread in ipairs(studioThreads) do
		task.cancel(thread)
	end
	table.clear(studioThreads)
end

local function getStudioFarmData()
	local container = waitForPath(World, "StudioPay", "Money")
	if not container then
		return nil
	end

	local stacks = {}
	local prompts = {}
	local found = false
	for index = 1, 3 do
		local model = container:FindFirstChild("StudioPay" .. index)
		if model then
			stacks[index] = model
			prompts[index] = model:FindFirstChild("Prompt", true)
			if prompts[index] then
				found = true
			end
		end
	end

	if not found then
		return nil
	end
	return stacks, prompts
end

local function studioStealLoop(index, prompt, model)
	while Config.StudioFarm do
		if prompt and prompt.Parent and prompt.Enabled then
			teleportTo(model)
			firePrompt(prompt)
			RunService.Heartbeat:Wait()
		else
			if not prompt or not prompt.Parent then
				break
			end
			local changed = false
			local conn = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				changed = true
			end)
			while Config.StudioFarm and not changed and not prompt.Enabled do
				RunService.Heartbeat:Wait()
			end
			conn:Disconnect()
		end
	end
end

local function applyStudioFarm()
	stopStudioFarmThreads()
	if not Config.StudioFarm then
		return
	end

	local stacks, prompts = getStudioFarmData()
	if not stacks then
		notify("StudioPay/Money not found — is the studio loaded?", "Studio Farm", 6)
		Config.StudioFarm = false
		return
	end

	for index, prompt in pairs(prompts) do
		if prompt then
			table.insert(studioThreads, task.spawn(studioStealLoop, index, prompt, stacks[index]))
		end
	end
end

-- ---------------------------------------------------------------------------
-- Infinite money — full kool-aid farm (InfiniteMoney.lua)
-- ---------------------------------------------------------------------------

local KOOL_AID_ITEMS = {
	"Ice-Fruit Bag",
	"Ice-Fruit Cupz",
	"FijiWater",
	"FreshWater",
}

local function exoticStockAvailable()
	local stockRoot = findPath(getSharedStorage(), "ExoticStock")
	if not stockRoot then
		return false
	end
	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		local stock = stockRoot:FindFirstChild(itemName)
		if not stock or not stock:IsA("ValueBase") or stock.Value == 0 then
			return false
		end
	end
	return true
end

local function buyKoolAidSupplies()
	if not exoticStockAvailable() then
		return false
	end
	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		if not invokeRemote("ExoticShopRemote", itemName) then
			return false
		end
		sleep(1.25)
	end
	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		if not findItem(itemName) then
			return false
		end
	end
	return true
end

local function getAvailableCookingPot()
	local pots = World:FindFirstChild("CookingPots")
	if not pots then
		return nil
	end
	for _, pot in ipairs(pots:GetChildren()) do
		if pot:IsA("Model") then
			local ownerTag = findPath(pot, "Owner")
			local progress = findPath(pot, "CookPart", "Steam", "LoadUI")
			if ownerTag and progress and not ownerTag.Value and not progress.Enabled then
				return pot
			end
		end
	end
	return nil
end

local function runKoolAidFarm()
	if koolAidFarmRunning then
		return
	end
	koolAidFarmRunning = true

	local ok, err = pcall(function()
		if getMoney() < 2750 then
			if getBankMoney() >= 2750 then
				withdrawCash(2750)
				sleep(0.5)
			else
				notify("You need at least $2,750 to buy Kool-Aid supplies.", "Insufficient Funds", 5)
				return
			end
		end

		if not buyKoolAidSupplies() then
			notify("Exotic stock unavailable or shop remote failed. Try another server.", "Server Hop Required", 10)
			return
		end

		local cookingPot = getAvailableCookingPot()
		if not cookingPot then
			notify("No free cooking pot found. Try another server.", "Server Hop Required", 10)
			return
		end

		local cookPart = cookingPot:WaitForChild("CookPart", 10)
		local cookPrompt = cookPart and cookPart:FindFirstChildOfClass("ProximityPrompt")
		local cookProgress = findPath(cookPart, "Steam", "LoadUI")
		local sellPart = World:FindFirstChild("IceFruit Sell")
		local sellPrompt = sellPart and sellPart:FindFirstChildOfClass("ProximityPrompt", true)

		if not cookPart or not cookPrompt or not cookProgress or not sellPart or not sellPrompt then
			notify("Cook or sell prompts missing — game layout may have changed.", "Kool-Aid Farm", 8)
			return
		end

		local fijiWater = findItem("FijiWater")
		local freshWater = findItem("FreshWater")
		local iceFruitBag = findItem("Ice-Fruit Bag")
		local iceFruitCupz = findItem("Ice-Fruit Cupz")
		local humanoid = getHumanoid()

		if not fijiWater or not freshWater or not iceFruitBag or not iceFruitCupz or not humanoid then
			notify("Missing supplies after purchase.", "Kool-Aid Farm", 5)
			return
		end

		local cookOrder = { fijiWater, freshWater, iceFruitBag }

		teleportTo(cookPart.Position)
		sleep(0.25)
		firePrompt(cookPrompt)
		sleep(0.25)

		for _, tool in ipairs(cookOrder) do
			humanoid:EquipTool(tool)
			sleep(0.5)
			firePrompt(cookPrompt)
			local start = tick()
			while tick() - start < 5 and tool.Parent do
				RunService.Heartbeat:Wait()
			end
		end

		while cookProgress.Enabled do
			local start = tick()
			local finished = false
			local conn = cookProgress:GetPropertyChangedSignal("Enabled"):Connect(function()
				finished = true
			end)
			while not finished and tick() - start < 2.035 do
				RunService.Heartbeat:Wait()
			end
			conn:Disconnect()
			if not cookProgress.Enabled then
				break
			end
		end

		teleportTo(cookPart.Position)
		sleep(0.25)
		humanoid:EquipTool(iceFruitCupz)
		sleep(0.1)
		firePrompt(cookPrompt)
		sleep(1)

		teleportTo(sellPart.Position)
		sleep(0.25)
		for _ = 1, 2000 do
			firePrompt(sellPrompt)
		end

		notify("Kool-Aid farm cycle finished. Wash filthy money and repeat.", "Infinite Money", 8)
	end)

	if not ok then
		notify(tostring(err), "Kool-Aid Farm Error", 8)
	end

	koolAidFarmRunning = false
end

-- ---------------------------------------------------------------------------
-- Infinite money — LTK Hub raw dupe (InfiniteMoney-LTK Hub.lua)
-- ---------------------------------------------------------------------------

local function restorePlayerGui(enabled)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	local names = { "Hunger", "HealthGui", "Run", "SleepGui", "MoneyGui", "NewMoneyGui" }
	for _, name in ipairs(names) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("LayerCollector") then
			gui.Enabled = enabled
		elseif gui then
			gui.Enabled = enabled
		end
	end
	pcall(function()
		game:GetService("CoreGui").RobloxGui.Backpack.Visible = enabled
	end)
end

local function runLtkMoneyDupe()
	if ltkDupeRunning then
		return
	end
	ltkDupeRunning = true

	local ok, err = pcall(function()
		local sellPart = World:FindFirstChild("IceFruit Sell")
		local sellPrompt = sellPart and sellPart:FindFirstChildOfClass("ProximityPrompt", true)
		if not sellPart or not sellPrompt then
			notify("IceFruit Sell prompt not found.", "LTK Money Dupe", 6)
			return
		end

		local root = getRootPart()
		if not root then
			return
		end

		local oldPos = root.CFrame
		teleportTo(sellPart)

		for _ = 1, 999 do
			firePrompt(sellPrompt)
		end

		sleep(4.5)

		local stored = getStoredFolder()
		local filthy = stored and stored:FindFirstChild("FilthyStack")
		local maxMoney = LocalPlayer:GetAttribute("MaxMoney")

		if filthy and maxMoney and filthy.Value >= maxMoney then
			restorePlayerGui(true)
			root.CFrame = oldPos
			notify("Money dupe completed — wash filthy money and repeat.", "LTK Money Dupe", 10)
		else
			notify("Dupe may not have capped. Check FilthyStack vs MaxMoney.", "LTK Money Dupe", 8)
		end
	end)

	if not ok then
		notify(tostring(err), "LTK Dupe Error", 8)
	end

	ltkDupeRunning = false
end

-- ---------------------------------------------------------------------------
-- Movement boosts
-- ---------------------------------------------------------------------------

local function applyMovementBoosts()
	if not Config.SpeedBoost and not Config.JumpBoost then
		return
	end
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if Config.SpeedBoost then
		humanoid.WalkSpeed = BOOST_WALK_SPEED
	end
	if Config.JumpBoost then
		if humanoid.UseJumpPower then
			humanoid.JumpPower = BOOST_JUMP_POWER
		else
			humanoid.JumpHeight = BOOST_JUMP_POWER / 2
		end
	end
end

local function bindCharacter(character)
	if not character then
		return
	end
	if Config.MovementBypass then
		applyMovementBypass(character)
	else
		teardownMovementBypass()
	end
	if Config.NoFallRagdoll then
		applyNoFallRagdoll(character)
	end
	if Config.InstantEquip then
		bindInstantEquipCharacter(character)
	end
	applyMovementBoosts()
end

local function onCharacterRemoving(_character)
	if bypassSession.character == _character then
		teardownMovementBypass()
	end
	teardownNoFallRagdoll()
	if equipCharacterConn then
		equipCharacterConn:Disconnect()
		equipCharacterConn = nil
	end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

local HubUI = UILib.create({
	title = "THA BRONX 3",
	config = Config,
	sections = {
		{
			title = "MOVEMENT",
			toggles = {
				{ key = "MovementBypass", label = "AC Bypass", hud = "AC Bypass" },
				{ key = "SpeedBoost", label = "Speed", hud = "Speed" },
				{ key = "JumpBoost", label = "Jump", hud = "Jump" },
			},
		},
		{
			title = "COMBAT",
			toggles = {
				{ key = "InstantEquip", label = "Inst Equip", hud = "Inst Equip" },
			},
		},
		{
			title = "AUTOFARM",
			toggles = {
				{ key = "StudioFarm", label = "Studio Farm", hud = "Studio Farm" },
			},
		},
		{
			title = "UTILITIES",
			toggles = {
				{ key = "InstantPrompts", label = "Inst Prompts", hud = "Inst Prompts" },
				{ key = "NoFallRagdoll", label = "No Fall Rag", hud = "No Fall Rag" },
				{ key = "ShowHUD", label = "Module HUD", hud = nil },
			},
		},
	},
	footer = {
		items = {
			{
				type = "slider",
				key = "WalkSpeed",
				label = "Walk Speed",
				step = 2,
				min = 16,
				max = 120,
				onChange = function(value)
					BOOST_WALK_SPEED = value
				end,
			},
			{
				type = "slider",
				key = "JumpPower",
				label = "Jump Power",
				step = 5,
				min = 50,
				max = 200,
				onChange = function(value)
					BOOST_JUMP_POWER = value
				end,
			},
			{
				type = "button",
				id = "koolAidFarm",
				label = "Kool-Aid Farm",
				getLabel = function()
					return koolAidFarmRunning and "Kool-Aid Farm (running...)" or "Kool-Aid Farm"
				end,
				canClick = function()
					return not koolAidFarmRunning
				end,
				onClick = function()
					task.spawn(runKoolAidFarm)
				end,
			},
			{
				type = "button",
				id = "ltkDupe",
				label = "LTK Money Dupe",
				getLabel = function()
					return ltkDupeRunning and "LTK Dupe (running...)" or "LTK Money Dupe"
				end,
				canClick = function()
					return not ltkDupeRunning
				end,
				onClick = function()
					task.spawn(runLtkMoneyDupe)
				end,
			},
			{
				type = "hint",
				text = "LastACPos nil = bypass active",
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "MovementBypass" then
			refreshMovementBypass()
		elseif key == "InstantPrompts" then
			applyInstantPrompts()
		elseif key == "NoFallRagdoll" then
			if value then
				applyNoFallRagdoll(LocalPlayer.Character)
			else
				teardownNoFallRagdoll()
			end
		elseif key == "InstantEquip" then
			applyInstantEquip()
		elseif key == "StudioFarm" then
			applyStudioFarm()
		end
	end,
})

LocalPlayer.CharacterAdded:Connect(bindCharacter)
LocalPlayer.CharacterRemoving:Connect(onCharacterRemoving)

if LocalPlayer.Character then
	task.defer(bindCharacter, LocalPlayer.Character)
end

applyInstantPrompts()

RunService.Heartbeat:Connect(function()
	applyMovementBoosts()
end)

print("[MicroHub] Tha Bronx 3 loaded — LastACPos:", readLastAcStatus())
