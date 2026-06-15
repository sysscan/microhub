--[[ Altered Reality — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/altered-reality/config.lua")
local Constants = require("games/altered-reality/constants.lua")
local ServicesLib = require("games/altered-reality/services.lua")
local UtilLib = require("games/altered-reality/util.lua")
local WeaponLib = require("games/altered-reality/weapon.lua")
local RemotesLib = require("games/altered-reality/remotes.lua")
local TargetsLib = require("games/altered-reality/targets.lua")
local HooksLib = require("games/altered-reality/hooks.lua")
local VehiclesLib = require("games/altered-reality/vehicles.lua")
local ProbeLib = require("games/altered-reality/probe.lua")
local MovementLib = require("games/altered-reality/movement.lua")
local CombatLib = require("games/altered-reality/combat.lua")
local LootLib = require("games/altered-reality/loot.lua")
local ESPLib = require("games/altered-reality/esp.lua")
local AutomationLib = require("games/altered-reality/automation.lua")
local UILibDef = require("games/altered-reality/ui.lua")
local BootstrapLib = require("games/altered-reality/bootstrap.lua")

local M = {}

function M.run()
	warn("[Altered Reality] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local connections = {}

	local services = ServicesLib.create({
		replicatedStorage = ReplicatedStorage,
		replicatedFirst = ReplicatedFirst,
		localPlayer = LocalPlayer,
	})

	local util = UtilLib.create({
		localPlayer = LocalPlayer,
		replicatedFirst = ReplicatedFirst,
	})

	local weapon = WeaponLib.create({
		config = Config,
		constants = Constants,
		services = services,
		util = util,
	})

	local remotes = RemotesLib.create({
		services = services,
		weapon = weapon,
		localPlayer = LocalPlayer,
	})

	local targets = TargetsLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		util = util,
	})

	local hooks = HooksLib.create({
		config = Config,
		constants = Constants,
		targets = targets,
		util = util,
		services = services,
	})

	local vehicles = VehiclesLib.create({
		config = Config,
		constants = Constants,
		util = util,
	})

	local movement = MovementLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		runService = RunService,
		services = services,
		util = util,
		vehicles = vehicles,
	})

	local probe = ProbeLib.create({
		config = Config,
		constants = Constants,
		services = services,
		util = util,
		vehicles = vehicles,
		remotes = remotes,
	})

	local combat = CombatLib.create({
		config = Config,
		services = services,
		remotes = remotes,
		targets = targets,
		util = util,
		weapon = weapon,
		hooks = hooks,
	})

	local loot = LootLib.create({
		config = Config,
		constants = Constants,
		services = services,
		util = util,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		camera = Camera,
		localPlayer = LocalPlayer,
		canDraw = canDraw,
		loot = loot,
	})

	local automation = AutomationLib.create({
		config = Config,
		constants = Constants,
		services = services,
		util = util,
		remotes = remotes,
		loot = loot,
	})

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		constants = Constants,
		remotes = remotes,
		automation = automation,
		vehicles = vehicles,
		probe = probe,
		onToggle = function(key, value)
			if probe and Config.ProbeAutoLog then
				probe.logToggle(key, value)
			end
			if key == "AntiAfk" then
				if value then
					movement.startAntiAfk()
				else
					movement.stopAntiAfk()
				end
			elseif key == "RemoteProbeLog" and value and probe then
				probe.installRemoteLogger()
			elseif key == "ProbeAutoLog" and value and probe then
				probe.startAutoMonitor({
					connections = connections,
					runService = RunService,
					localPlayer = LocalPlayer,
				})
			elseif key == "SilentAim" or key == "AimAtHead" or key == "AttackRange" or key == "AimFOV" then
				if key == "SilentAim" and value then
					task.spawn(function()
						for _ = 1, 12 do
							if hooks.sync() then
								break
							end
							task.wait(0.25)
						end
					end)
				end
				hooks.invalidateAimCache()
			end
		end,
	})

	BootstrapLib.create({
		config = Config,
		constants = Constants,
		runService = RunService,
		movement = movement,
		combat = combat,
		esp = esp,
		automation = automation,
		connections = connections,
	})

	task.spawn(function()
		services.waitForPlayerFolder(20)
	end)

	if Config.AntiAfk then
		movement.startAntiAfk()
	end

	if Config.SilentAim and not hooks.canHook() then
		warn("[Altered Reality] Silent Aim requires hookfunction or hookmetamethod support")
	end

	if Config.ProbeAutoLog then
		probe.startAutoMonitor({
			connections = connections,
			runService = RunService,
			localPlayer = LocalPlayer,
		})
	end

	task.spawn(function()
		if not Config.SilentAim then
			return
		end
		for _ = 1, 24 do
			if hooks.sync() then
				break
			end
			task.wait(0.25)
		end
	end)

	local function unload()
		for _, connection in connections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(connections)
		movement.unload()
		hooks.remove()
		esp.destroy()
	end

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__AlteredRealityUnload = unload

	print("[MicroHub] Altered Reality", Constants.GAME_BUILD)
end

return M
