local HttpService = game:GetService("HttpService")

local M = {}

local function shuffle(list, seed)
	local rng = Random.new(seed)
	for index = #list, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		list[index], list[swapIndex] = list[swapIndex], list[index]
	end
	return list
end

function M.scramble(userId, payload)
	local encoded = HttpService:JSONEncode(payload)
	local bytes = { string.byte(encoded, 1, #encoded) }
	local seed = math.floor(userId * 0.8642)
	local order = table.create(#bytes)
	for index = 1, #bytes do
		order[index] = index
	end
	shuffle(order, seed)
	local out = table.create(#bytes)
	for index = 1, #bytes do
		out[index] = string.char(bytes[order[index]])
	end
	return table.concat(out)
end

function M.create(opts)
	local services = opts.services
	local weapon = opts.weapon
	local LocalPlayer = opts.localPlayer

	local function getRemote(name)
		return services.getRemote(name)
	end

	local function fireTool(payload)
		local remote = getRemote("Tool_RE")
		if not remote then
			return false, "Tool_RE missing"
		end
		local ok, err = pcall(function()
			remote:FireServer(M.scramble(LocalPlayer.UserId, payload))
		end)
		return ok, err
	end

	local function fireGunSound()
		local remote = getRemote("Tool_URE")
		if not remote then
			return
		end
		pcall(function()
			remote:FireServer(M.scramble(LocalPlayer.UserId, { Sound = "Shoot" }))
		end)
	end

	local function fireGun(hits, tool, options)
		if typeof(hits) ~= "table" or #hits == 0 then
			return false, "no hits"
		end
		if tool and not weapon.consumeAmmo(tool) then
			return false, "no ammo"
		end
		if options and options.legit then
			fireGunSound()
		end
		local ok, err = fireTool({
			Fire = { tick(), hits },
		})
		return ok, err
	end

	local function reloadGun()
		return fireTool({ Reload = true })
	end

	local function pickupLoot(lootId)
		local remote = getRemote("PickupLoot")
		if not remote then
			return false, "PickupLoot missing"
		end
		local ok, err = pcall(function()
			remote:FireServer("Pickup", lootId)
		end)
		return ok, err
	end

	local function spawnCharacter()
		local remote = getRemote("Spawn")
		if not remote then
			return false, "Spawn missing"
		end
		local ok, err = pcall(function()
			remote:FireServer()
		end)
		return ok, err
	end

	return {
		scramble = M.scramble,
		fireTool = fireTool,
		fireGun = fireGun,
		reloadGun = reloadGun,
		pickupLoot = pickupLoot,
		spawnCharacter = spawnCharacter,
	}
end

return M
