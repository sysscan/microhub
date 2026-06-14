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
	local reloadHookedScript: LocalScript? = nil
	local oldReloadFn: any = nil

	local function wrapHook(fn)
		if typeof(newcclosure) == "function" then
			return newcclosure(fn)
		end
		return fn
	end

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

	local function getTargetMag(variables, slot: string, gunName: string)
		local base = getMagCap(slot, gunName)
		if variables:GetAttribute("DoubleMag_Perk") == true then
			return base * 2
		end
		return base
	end

	local function getReserveCap(magCap: number, bandoiler: boolean)
		return if bandoiler then magCap * 16 else magCap * 10
	end

	local function getReloadLoadingLabel()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local hud = playerGui and playerGui:FindFirstChild("HUD")
		local ammoFrame = hud and hud:FindFirstChild("AmmoFrame")
		local equipped = ammoFrame and ammoFrame:FindFirstChild("Equipped")
		return equipped and equipped:FindFirstChild("Loading")
	end

	local function hideReloadUi()
		local loading = getReloadLoadingLabel()
		if loading and loading:IsA("GuiObject") then
			loading.Visible = false
		end
	end

	-- Matches PlayerControls.reload ammo transfer (without v39 lock or animation wait).
	local function transferReloadAmmo(variables)
		if (variables:GetAttribute("Health") or 0) <= 0 then
			return false
		end

		local slot = variables:GetAttribute("Equipped_Slot")
		if type(slot) ~= "string" or slot == "" then
			return false
		end

		local playerData = util.getPlayerData()
		if not playerData then
			return false
		end

		local equipped = playerData:FindFirstChild("equipped_" .. string.lower(slot))
		if not equipped or equipped.Value == "None" or equipped.Value == "" then
			return false
		end

		local targetMag = getTargetMag(variables, slot, equipped.Value)
		local magKey = slot .. "_Mag"
		local ammoKey = slot .. "_Ammo"
		local currentMag = variables:GetAttribute(magKey) or 0
		local reserve = variables:GetAttribute(ammoKey) or 0

		if currentMag >= targetMag or reserve <= 0 then
			return false
		end

		local needed = targetMag - currentMag
		if reserve >= needed then
			variables:SetAttribute(ammoKey, reserve - needed)
			variables:SetAttribute(magKey, targetMag)
		else
			variables:SetAttribute(magKey, currentMag + reserve)
			variables:SetAttribute(ammoKey, 0)
		end

		return true
	end

	local function hookPlayerControlsReload(character: Model?)
		if not character or typeof(getsenv) ~= "function" or typeof(hookfunction) ~= "function" then
			return false
		end

		local controls = character:FindFirstChild("PlayerControls")
		if not controls or not controls:IsA("LocalScript") then
			return false
		end

		if reloadHookedScript == controls and typeof(oldReloadFn) == "function" then
			return true
		end

		local ok, env = pcall(getsenv, controls)
		if not ok or typeof(env) ~= "table" then
			return false
		end

		local reloadFn = rawget(env, "reload")
		if typeof(reloadFn) ~= "function" then
			return false
		end

		oldReloadFn = hookfunction(
			reloadFn,
			wrapHook(function()
				if not Config.InstantReload then
					return oldReloadFn()
				end

				local variables = util.getVariables()
				if variables then
					transferReloadAmmo(variables)
				end
				hideReloadUi()
			end)
		)

		if typeof(oldReloadFn) ~= "function" then
			oldReloadFn = nil
			return false
		end

		reloadHookedScript = controls
		return true
	end

	local function installReloadHooks()
		if not Config.InstantReload then
			return
		end

		local character = util.getCharacter() or LocalPlayer.Character
		if character then
			hookPlayerControlsReload(character)
		end
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

	local function applyInfiniteAmmo(variables)
		refillSlot(variables, "Primary", false)
		refillSlot(variables, "Secondary", false)

		local slot = variables:GetAttribute("Equipped_Slot")
		if type(slot) ~= "string" or slot == "" then
			return
		end

		local playerData = util.getPlayerData()
		local equipped = playerData and playerData:FindFirstChild("equipped_" .. string.lower(slot))
		if not equipped or equipped.Value == "None" or equipped.Value == "" then
			return
		end

		local magCap = getMagCap(slot, equipped.Value)
		local magKey = slot .. "_Mag"
		local currentMag = variables:GetAttribute(magKey) or 0
		if currentMag < magCap then
			variables:SetAttribute(magKey, magCap)
		end
	end

	local function stabilizeCameraRecoil()
		local controller = util.getCameraController()
		if not controller then
			return
		end
		if typeof(controller:GetAttribute("recoil_offset")) ~= "Vector3" then
			controller:SetAttribute("recoil_offset", Vector3.new(0, 0, 0))
		end
	end

	local function tickInstantReload()
		if not Config.InstantReload then
			return
		end

		hideReloadUi()

		local variables = util.getVariables()
		if not variables then
			return
		end

		local loading = getReloadLoadingLabel()
		if loading and loading:IsA("GuiObject") and loading.Visible then
			transferReloadAmmo(variables)
			hideReloadUi()
			return
		end

		-- Top up before mag hits 0 so PlayerControls never enters reload lock (v39).
		local slot = variables:GetAttribute("Equipped_Slot")
		if type(slot) ~= "string" or slot == "" then
			return
		end

		local playerData = util.getPlayerData()
		local equipped = playerData and playerData:FindFirstChild("equipped_" .. string.lower(slot))
		if not equipped or equipped.Value == "None" or equipped.Value == "" then
			return
		end

		local magKey = slot .. "_Mag"
		local currentMag = variables:GetAttribute(magKey) or 0
		if currentMag <= 0 then
			transferReloadAmmo(variables)
		end
	end

	local function tickWeapon()
		stabilizeCameraRecoil()
		tickInstantReload()

		if not (Config.InfiniteAmmo or Config.AutoReload) then
			return
		end

		local variables = util.getVariables()
		if not variables then
			return
		end

		if Config.InfiniteAmmo then
			-- Refill every heartbeat so fast / silent-aim fire never hits 0 mag
			-- and triggers PlayerControls reload lock (v39).
			applyInfiniteAmmo(variables)
			return
		end

		local now = os.clock()
		if now - lastWeaponTick < Constants.WEAPON_TICK_INTERVAL then
			return
		end
		lastWeaponTick = now

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

	local function refillNow()
		stabilizeCameraRecoil()
		if Config.InstantReload then
			local variables = util.getVariables()
			if variables then
				transferReloadAmmo(variables)
				hideReloadUi()
			end
		end
		if not Config.InfiniteAmmo then
			return
		end
		local variables = util.getVariables()
		if variables then
			applyInfiniteAmmo(variables)
		end
	end

	LocalPlayer.CharacterAdded:Connect(function(_character)
		reloadHookedScript = nil
		task.defer(function()
			installReloadHooks()
		end)
	end)
	if LocalPlayer.Character and Config.InstantReload then
		task.defer(function()
			installReloadHooks()
		end)
	end

	return {
		tickWeapon = tickWeapon,
		refillNow = refillNow,
		stabilizeCameraRecoil = stabilizeCameraRecoil,
		installReloadHooks = installReloadHooks,
		transferReloadAmmo = transferReloadAmmo,
	}
end

return M
