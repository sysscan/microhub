local CollectionService = game:GetService("CollectionService")

local M = {}

function M.create(opts: {
	config: { [string]: any },
	localPlayer: Player,
	teamGuards: Team?,
	teamCriminals: Team?,
	getRemotes: () -> Instance?,
})
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local TeamGuards = opts.teamGuards
	local TeamCriminals = opts.teamCriminals
	local getRemotes = opts.getRemotes

	local sortedPickups = {
		Guard = { [1] = "MP5", [2] = "Remington 870" },
		Prisoner = { [1] = "MP5", [2] = "Remington 870" },
		Criminal = { [1] = "AK-47", [2] = "Remington 870" },
	}
	local pickupSeen: { [Instance]: boolean } = {}
	local pickupItems: { { any } } = {}

	local function rebuildSortedPickups()
		sortedPickups.Guard = { [1] = Config.GuardPickup1, [2] = Config.GuardPickup2 }
		sortedPickups.Prisoner = { [1] = Config.PrisonerPickup1, [2] = Config.PrisonerPickup2 }
		sortedPickups.Criminal = { [1] = Config.CriminalPickup1, [2] = Config.CriminalPickup2 }
	end

	local function getGiverPosition(giver: Instance): Vector3?
		if giver:IsA("BasePart") then
			return giver.Position
		end
		if giver:IsA("Model") then
			return giver:GetPivot().Position
		end
		local part = giver:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position
	end

	local function revealGiver(giver: Instance)
		for _, part in giver:GetDescendants() do
			if part:IsA("BasePart") then
				local original = part:GetAttribute("OriginalTransparency")
				if original ~= nil then
					part.Transparency = original
				elseif part.Transparency >= 1 then
					part.Transparency = 0
				end
			end
		end
	end

	local function findWeaponGiver(weaponName: string): Instance?
		local items = workspace:FindFirstChild("Prison_ITEMS")
		local giverFolder = items and items:FindFirstChild("giver")
		local named = giverFolder and giverFolder:FindFirstChild(weaponName)
		if named then
			return named
		end
		for _, tag in { "Giver", "TouchGiver" } do
			for _, giver in CollectionService:GetTagged(tag) do
				if giver.Name == weaponName or giver:GetAttribute("ToolName") == weaponName then
					return giver
				end
			end
		end
		return nil
	end

	local function teleportNearGiver(giver: Instance)
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local pos = getGiverPosition(giver)
		if root and pos then
			root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
		end
	end

	local function requestGiverWeapon(giver: Instance): boolean
		local remotes = getRemotes()
		local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
		if giverPressed then
			return pcall(function()
				giverPressed:FireServer(giver)
			end)
		end
		local pickup = giver:FindFirstChild("ITEMPICKUP", true)
		local remote = workspace:FindFirstChild("Remote")
		local handler = remote and remote:FindFirstChild("ItemHandler")
		if pickup and handler then
			return pcall(function()
				handler:InvokeServer(pickup)
			end)
		end
		return false
	end

	local function giveGiverWeapon(weaponName: string)
		task.spawn(function()
			local giver = findWeaponGiver(weaponName)
			if not giver then
				warn("[PrisonLife] giver not found:", weaponName)
				return
			end
			revealGiver(giver)
			teleportNearGiver(giver)
			task.wait(0.05)
			if not requestGiverWeapon(giver) then
				warn("[PrisonLife] failed to request weapon:", weaponName)
			end
		end)
	end

	local function registerPickup(obj: Instance, touchGiver: boolean)
		if pickupSeen[obj] then
			return
		end
		if not obj:IsA("Model") or obj.Name == "Model" or not obj:GetAttribute("ToolName") then
			return
		end
		pickupSeen[obj] = true
		table.insert(pickupItems, { obj, touchGiver or obj.Name == "TouchGiver" })
	end

	local function unregisterPickup(obj: Instance)
		if not pickupSeen[obj] then
			return
		end
		pickupSeen[obj] = nil
		for i, entry in pickupItems do
			if entry[1] == obj then
				table.remove(pickupItems, i)
				break
			end
		end
	end

	local function refreshPickupIndex()
		for _, tag in { "Giver", "TouchGiver" } do
			for _, giver in CollectionService:GetTagged(tag) do
				registerPickup(giver, tag == "TouchGiver")
			end
		end
		for _, obj in workspace:GetChildren() do
			if obj:IsA("Model") and obj:GetAttribute("ToolName") then
				registerPickup(obj, obj.Name == "TouchGiver")
			end
		end
	end

	local function runAutoPickup()
		if not Config.AutoPickup then
			return
		end
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		local remotes = getRemotes()
		local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
		if not root or not backpack or not giverPressed then
			return
		end
		for _, entry in pickupItems do
			local model = entry[1]
			if not model.Parent then
				continue
			end
			local pos = getGiverPosition(model)
			if not pos or (pos - root.Position).Magnitude > 12 then
				continue
			end
			local toolName = model:GetAttribute("ToolName") or model.Name
			if typeof(toolName) ~= "string" or backpack:FindFirstChild(toolName) then
				continue
			end
			if entry[2] then
				local teamKey = if LocalPlayer.Team == TeamGuards
					then "Guard"
					elseif LocalPlayer.Team == TeamCriminals then "Criminal"
					else "Prisoner"
				local wanted = sortedPickups[teamKey]
				local skip = false
				local indices = {}
				for idx in wanted do
					table.insert(indices, idx)
				end
				table.sort(indices)
				for _, idx in indices do
					local itemName = wanted[idx]
					if not backpack:FindFirstChild(itemName) then
						if toolName ~= itemName then
							skip = true
						end
						break
					end
				end
				if skip then
					continue
				end
			end
			revealGiver(model)
			pcall(function()
				giverPressed:FireServer(model)
			end)
		end
	end

	local function clearSeen()
		table.clear(pickupSeen)
	end

	return {
		rebuildSortedPickups = rebuildSortedPickups,
		giveGiverWeapon = giveGiverWeapon,
		registerPickup = registerPickup,
		unregisterPickup = unregisterPickup,
		refreshPickupIndex = refreshPickupIndex,
		runAutoPickup = runAutoPickup,
		clearSeen = clearSeen,
	}
end

return M
