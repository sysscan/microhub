local M = {}

function M.create(opts)
	local Config = opts.config
	local remotes = opts.remotes
	local movement = opts.movement
	local targets = opts.targets

	local lastAttack = 0
	local lastFlash = 0
	local lastGrip = 0
	local attacking = false
	local attackReleaseThread: thread? = nil
	local blocking = false

	local function cancelAttack()
		if attackReleaseThread then
			pcall(task.cancel, attackReleaseThread)
			attackReleaseThread = nil
		end
		if attacking then
			remotes.lightAttack(false, false)
			attacking = false
		end
	end

	local function setBlock(active: boolean)
		if blocking == active then
			return
		end
		blocking = active
		remotes.block(active)
	end

	local function faceTarget(target: Model)
		local root = movement.getRoot()
		local mobRoot = target:FindFirstChild("HumanoidRootPart")
		if not root or not mobRoot or not mobRoot:IsA("BasePart") then
			return
		end
		root.CFrame = CFrame.new(root.Position, Vector3.new(mobRoot.Position.X, root.Position.Y, mobRoot.Position.Z))
	end

	local function doAttack()
		local now = os.clock()
		local interval = tonumber(Config.AttackInterval) or 0.55
		if now - lastAttack < interval or attacking then
			return
		end
		lastAttack = now
		attacking = true

		local sprinting = Config.SpeedBoost == true
		remotes.lightAttack(true, sprinting)

		if attackReleaseThread then
			pcall(task.cancel, attackReleaseThread)
		end
		attackReleaseThread = task.delay(0.12, function()
			attackReleaseThread = nil
			if attacking then
				remotes.lightAttack(false, sprinting)
				attacking = false
			end
		end)
	end

	local function wantsCombat(): boolean
		return Config.AutoAttack
			or Config.AutoFarm
			or Config.AutoFlashStep
			or Config.AutoGrip
			or Config.AutoBlock
	end

	local function tickCombat(opts: { farmOnly: boolean? }?)
		if not wantsCombat() then
			if blocking then
				setBlock(false)
			end
			return
		end

		local farmOnly = opts and opts.farmOnly == true
		if Config.AutoFarm and not farmOnly then
			return
		end
		if not Config.AutoFarm and farmOnly then
			return
		end

		local range = tonumber(Config.FarmRange) or 400
		local filter = if Config.FarmBossesOnly then { bossesOnly = true } else nil
		local target, dist = targets.nearestHostile(range, filter)

		if target and dist and (Config.AutoAttack or Config.AutoFarm) then
			faceTarget(target)
			doAttack()
		end

		if Config.AutoFlashStep and target then
			local now = os.clock()
			if now - lastFlash > 1.2 then
				lastFlash = now
				remotes.flashStep()
			end
		end

		if Config.AutoGrip and target then
			local hum = target:FindFirstChildOfClass("Humanoid")
			local now = os.clock()
			if hum and hum.Health > 0 and hum.Health < 15 and now - lastGrip > 1.5 then
				lastGrip = now
				remotes.grip(target)
			end
		end

		if Config.AutoBlock then
			setBlock(target ~= nil and dist ~= nil and dist < 20)
		elseif blocking then
			setBlock(false)
		end
	end

	local function destroy()
		cancelAttack()
		setBlock(false)
	end

	return {
		nearestEnemy = function(maxRange)
			local filter = if Config.FarmBossesOnly then { bossesOnly = true } else nil
			return targets.nearestHostile(maxRange or tonumber(Config.FarmRange) or 400, filter)
		end,
		tickCombat = tickCombat,
		destroy = destroy,
	}
end

return M
