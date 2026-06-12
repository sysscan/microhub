local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local automation = opts.automation
	local shop = opts.shop
	local extras = opts.extras
	local movement = opts.movement
	local combat = opts.combat
	local esp = opts.esp
	local teleport = opts.teleport
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	local lastLevelRefresh = 0

	local function needsCombatTick()
		return Config.AutoAttack or Config.AutoEquipBest or (Config.AimAssist and Config.ShowAimFOV)
	end

	local function needsEspTick()
		return Config.ESP
			or Config.ESPSnaplines
			or Config.MonsterESP
			or Config.MonsterESPBoxes
			or Config.SearchESP
			or Config.CoinESP
			or Config.MysteryBoxESP
			or (Config.ShowAimFOV and (Config.AimAssist or Config.AutoAttack))
	end

	table.insert(connections, RunService.Heartbeat:Connect(function()
		movement.tickMovement()
		if needsCombatTick() then
			combat.tickCombat()
		end
		if needsEspTick() then
			esp.tick()
		end
	end))

	loopHelpers.start(function()
		while true do
			automation.tickAutomation()
			shop.tickShop()
			extras.tickExtras()

			local now = os.clock()
			if now - lastLevelRefresh >= 60 then
				lastLevelRefresh = now
				task.spawn(teleport.refreshLevels)
			end

			task.wait(tonumber(Config.TickInterval) or 0.2)
		end
	end)

	if Config.AntiAfk then
		movement.startAntiAfk()
	end

	task.defer(teleport.refreshLevels)
end

return M
