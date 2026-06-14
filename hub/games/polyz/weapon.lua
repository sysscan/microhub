local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local util = opts.util
	local LocalPlayer = opts.localPlayer

	if not Config or not Constants or not util or not LocalPlayer then
		error("[POLYZ] weapon.create missing required opts", 0)
	end

	local GunVariables: any = nil
	local magCapCache: { [string]: number } = {}
	local lastWeaponTick = 0
	local lastPrimaryMag = -1
	local lastSecondaryMag = -1
	local lastPrimaryAmmo = -1
	local lastSecondaryAmmo = -1

	local function getGunVariables()
		if GunVariables then
			return GunVariables
		end
		local ok, module = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("GunVariables"))
		end)
		if ok then
			GunVariables = module
		end
		return GunVariables
	end

	local function getMagCap(_slot: string, gunName: string)
		local cached = magCapCache[gunName]
		if cached then
			return cached
		end

		local vars = getGunVariables()
		local magSize = 30
		if vars and vars[gunName] then
			magSize = vars[gunName].mag_size or 30
		end

		local petInventory = LocalPlayer:FindFirstChild("PetInventory")
		local magBonus = petInventory and (petInventory:GetAttribute("MAG") or 0) or 0
		local cap = math.max(1, math.ceil(magSize * (1 + magBonus)))
		magCapCache[gunName] = cap
		return cap
	end

	local function getReserveCap(magCap: number, bandoiler: boolean)
		return if bandoiler then magCap * 16 else magCap * 10
	end

	local function refillSlot(variables, slot: string, force: boolean?)
		local playerData = util.getPlayerData()
		if not playerData then
			return
		end

		local equipped = playerData:FindFirstChild("equipped_" .. string.lower(slot))
		if not equipped or equipped.Value == "None" or equipped.Value == "" then
			return
		end

		local magCap = getMagCap(slot, equipped.Value)
		local reserveCap = getReserveCap(magCap, variables:GetAttribute("Bandoiler_Perk") == true)
		local magKey = slot .. "_Mag"
		local ammoKey = slot .. "_Ammo"
		local currentMag = variables:GetAttribute(magKey) or 0
		local currentAmmo = variables:GetAttribute(ammoKey) or 0

		if not force and currentMag >= magCap and currentAmmo >= reserveCap then
			return
		end

		if currentMag < magCap then
			variables:SetAttribute(magKey, magCap)
		end
		if currentAmmo < reserveCap then
			variables:SetAttribute(ammoKey, reserveCap)
		end
	end

	local function tickWeapon()
		if not (Config.InfiniteAmmo or Config.AutoReload) then
			return
		end

		local now = os.clock()
		if now - lastWeaponTick < Constants.WEAPON_TICK_INTERVAL then
			return
		end
		lastWeaponTick = now

		local variables = util.getVariables()
		if not variables then
			return
		end

		if Config.InfiniteAmmo then
			refillSlot(variables, "Primary", false)
			refillSlot(variables, "Secondary", false)

			local slot = variables:GetAttribute("Equipped_Slot")
			if type(slot) == "string" and slot ~= "" then
				local playerData = util.getPlayerData()
				local equipped = playerData and playerData:FindFirstChild("equipped_" .. string.lower(slot))
				if equipped and equipped.Value ~= "None" and equipped.Value ~= "" then
					local magCap = getMagCap(slot, equipped.Value)
					local magKey = slot .. "_Mag"
					local currentMag = variables:GetAttribute(magKey) or 0
					if currentMag < magCap then
						variables:SetAttribute(magKey, magCap)
					end
				end
			end
			return
		end

		local primaryMag = variables:GetAttribute("Primary_Mag") or 0
		local primaryAmmo = variables:GetAttribute("Primary_Ammo") or 0
		local secondaryMag = variables:GetAttribute("Secondary_Mag") or 0
		local secondaryAmmo = variables:GetAttribute("Secondary_Ammo") or 0

		if primaryMag == lastPrimaryMag and primaryAmmo == lastPrimaryAmmo and secondaryMag == lastSecondaryMag and secondaryAmmo == lastSecondaryAmmo then
			return
		end

		lastPrimaryMag = primaryMag
		lastPrimaryAmmo = primaryAmmo
		lastSecondaryMag = secondaryMag
		lastSecondaryAmmo = secondaryAmmo

		if primaryMag <= 0 and primaryAmmo > 0 then
			refillSlot(variables, "Primary", true)
		end
		if secondaryMag <= 0 and secondaryAmmo > 0 then
			refillSlot(variables, "Secondary", true)
		end
	end

	return {
		tickWeapon = tickWeapon,
	}
end

return M
