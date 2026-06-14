local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local movement = opts.movement
	local combat = opts.combat
	local weapon = opts.weapon
	local esp = opts.esp
	local connections = opts.connections

	if not Config or not RunService or not movement or not combat or not weapon or not esp or not connections then
		error("[POLYZ] bootstrap.create missing required opts", 0)
	end

	local function anyMovementEnabled()
		return Config.Fly
			or Config.NoClip
			or Config.SpeedBoost
			or Config.AlwaysSprint
			or Config.JumpBoost
			or Config.FullBright
			or Config.InfiniteStamina
			or Config.NoRecoil
			or (Config.CameraFOV and tonumber(Config.CameraFOV) ~= 80)
	end

	local function anyWeaponEnabled()
		return Config.InfiniteAmmo or Config.AutoReload
	end

	local function anyEspEnabled()
		return Config.EnemyESP
			or Config.EnemyESPBoxes
			or Config.ESPSnaplines
			or Config.PlayerESP
			or Config.ShowEnemyHealth
			or (Config.ShowAimFOV and (Config.AimAssist or Config.AutoShoot))
	end

	table.insert(connections, RunService.Heartbeat:Connect(function()
		if anyMovementEnabled() then
			movement.tickMovement()
		end
		if anyWeaponEnabled() then
			weapon.tickWeapon()
		elseif Config.SilentAim and weapon.stabilizeCameraRecoil then
			weapon.stabilizeCameraRecoil()
		end
		if Config.AutoShoot then
			combat.tickCombat()
		end
	end))

	table.insert(connections, RunService.RenderStepped:Connect(function()
		if anyEspEnabled() then
			esp.tick()
		end
	end))

	if Config.AntiAfk then
		movement.startAntiAfk()
	end
end

return M
