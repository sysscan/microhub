--[[ Fall immunity, damage remote blocks, optional health lock / intangible refresh. ]]

local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local remotes = opts.remotes

	local statusEffectManager = nil
	local healthConn: RBXScriptConnection? = nil
	local remotesHooked = false
	local savedFire = nil

	local function godActive(): boolean
		return Config.GodMode == true
	end

	local function fallProtection(): boolean
		return godActive() or Config.NoFallDamage == true
	end

	local function intangibleActive(): boolean
		return godActive() or Config.IntangibleGod == true
	end

	local function healthLockActive(): boolean
		return godActive() or Config.HealthLock == true
	end

	local function blockTakeDamage(): boolean
		return godActive() or Config.BlockTakeDamage == true
	end

	local function spoofFallFx(): boolean
		return godActive() or Config.SpoofFallFX == true
	end

	local function getStatusEffectManager()
		if statusEffectManager then
			return statusEffectManager
		end
		local sharedModules = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
		local mod = sharedModules and sharedModules:FindFirstChild("StatusEffectManager")
		if not mod then
			return nil
		end
		local ok, result = pcall(require, mod)
		if ok then
			statusEffectManager = result
		end
		return statusEffectManager
	end

	local function getCharacter()
		return LocalPlayer.Character
	end

	local function hasEffect(char: Model, name: string): boolean
		local status = char:FindFirstChild("Status")
		return status ~= nil and status:FindFirstChild(name) ~= nil
	end

	local function applyFallImmunity()
		if not fallProtection() then
			return
		end
		local char = getCharacter()
		if not char or hasEffect(char, "FallImmunity") then
			return
		end
		local sem = getStatusEffectManager()
		if sem and typeof(sem.AddEffect) == "function" then
			pcall(sem.AddEffect, char, {
				Name = "FallImmunity",
			})
		end
	end

	local function refreshIntangible()
		if not intangibleActive() then
			return
		end
		local char = getCharacter()
		if not char then
			return
		end
		local sem = getStatusEffectManager()
		if not sem or typeof(sem.AddEffect) ~= "function" then
			return
		end
		if not hasEffect(char, "Intangible") then
			pcall(sem.AddEffect, char, {
				Name = "Intangible",
				Duration = 8,
			})
		end
	end

	local function clearHealthLock()
		if healthConn then
			pcall(function()
				healthConn:Disconnect()
			end)
			healthConn = nil
		end
	end

	local function bindHealthLock(char: Model)
		clearHealthLock()
		if not healthLockActive() then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		healthConn = hum.HealthChanged:Connect(function()
			if not healthLockActive() then
				return
			end
			if hum.Health > 0 and hum.Health < hum.MaxHealth then
				pcall(function()
					hum.Health = hum.MaxHealth
				end)
			end
		end)
	end

	local function hookRemotes()
		if remotesHooked or not remotes or typeof(remotes.fire) ~= "function" then
			return
		end
		remotesHooked = true
		savedFire = remotes.fire
		remotes.fire = function(name, ...)
			if blockTakeDamage() and name == "TakeDamage" then
				return true
			end
			if spoofFallFx() and name == "FX_Server" then
				local payload = ...
				if type(payload) == "table" and payload.Type == "FallFX" then
					local spoofed = {}
					for k, v in payload do
						spoofed[k] = v
					end
					spoofed.FallDistance = 0
					return savedFire(name, spoofed)
				end
			end
			return savedFire(name, ...)
		end
	end

	local function unhookRemotes()
		if not remotesHooked or not remotes or not savedFire then
			return
		end
		remotes.fire = savedFire
		savedFire = nil
		remotesHooked = false
	end

	local function onCharacterSpawn(char: Model)
		bindHealthLock(char)
		applyFallImmunity()
	end

	local function tickGodmode()
		applyFallImmunity()
		refreshIntangible()
	end

	local function destroy()
		clearHealthLock()
		unhookRemotes()
	end

	return {
		hookRemotes = hookRemotes,
		tickGodmode = tickGodmode,
		onCharacterSpawn = onCharacterSpawn,
		applyFallImmunity = applyFallImmunity,
		destroy = destroy,
	}
end

return M
