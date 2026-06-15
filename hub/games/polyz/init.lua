--[[ POLYZ — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/polyz/config.lua")
local Constants = require("games/polyz/constants.lua")
local LoopsLib = require("games/polyz/loops.lua")
local RemotesLib = require("games/polyz/remotes.lua")
local UtilLib = require("games/polyz/util.lua")
local TargetsLib = require("games/polyz/targets.lua")
local CombatLib = require("games/polyz/combat.lua")
local ESPLib = require("games/polyz/esp.lua")
local MovementLib = require("games/polyz/movement.lua")
local WeaponLib = require("games/polyz/weapon.lua")
local HooksLib = require("games/polyz/hooks.lua")
local DebugLib = require("games/polyz/debug.lua")
local UILibDef = require("games/polyz/ui.lua")
local BootstrapLib = require("games/polyz/bootstrap.lua")

local M = {}

function M.run()
	warn("[POLYZ] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local connections = {}
	local loops = {}
	local _loopHelpers = LoopsLib.create(loops)

	local util = UtilLib.create({
		localPlayer = LocalPlayer,
	})

	local debug = DebugLib.create({
		config = Config,
	})

	local targets = TargetsLib.create({
		config = Config,
		constants = Constants,
		util = util,
	})

	local remotes = RemotesLib.create({
		replicatedStorage = ReplicatedStorage,
		util = util,
		targets = targets,
		debug = debug,
	})

	local movement = MovementLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		runService = RunService,
		util = util,
	})

	local weapon = WeaponLib.create({
		config = Config,
		constants = Constants,
		util = util,
		localPlayer = LocalPlayer,
	})

	local hooks = HooksLib.create({
		config = Config,
		constants = Constants,
		targets = targets,
		util = util,
		remotes = remotes,
		debug = debug,
	})

	local combat = CombatLib.create({
		config = Config,
		remotes = remotes,
		util = util,
		targets = targets,
		hooks = hooks,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		camera = Camera,
		canDraw = canDraw,
		targets = targets,
	})

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		constants = Constants,
		onChange = function(key)
			if key == "TargetMode" or key == "AimAtHead" or key == "AttackRange" or key == "AimFOV" then
				hooks.invalidateAimCache(true)
			end
		end,
		onToggle = function(key, value)
			if key == "SilentAim" or key == "NoSpread" then
				if value then
					task.spawn(function()
						for _ = 1, 12 do
							if hooks.sync() then
								break
							end
							task.wait(0.25)
						end
					end)
				end
				if key == "SilentAim" then
					hooks.invalidateAimCache(true)
				end
			elseif key == "InstantReload" and value then
				if weapon.installReloadHooks then
					weapon.installReloadHooks()
				end
				if weapon.refillNow then
					weapon.refillNow()
				end
			elseif key == "InfiniteAmmo" and value and weapon.refillNow then
				weapon.refillNow()
			elseif key == "InfiniteGrenades" and value and weapon.refillNow then
				weapon.refillNow()
			elseif key == "AntiAfk" then
				if value then
					movement.startAntiAfk()
				else
					movement.stopAntiAfk()
				end
			end
		end,
	})

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		movement = movement,
		combat = combat,
		weapon = weapon,
		esp = esp,
		connections = connections,
	})

	if (Config.SilentAim or Config.NoSpread) and not hooks.canHook() then
		warn("[POLYZ] Silent Aim and No Spread require hookfunction or hookmetamethod support")
	end

	task.spawn(function()
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
		for _, thread in loops do
			pcall(function()
				task.cancel(thread)
			end)
		end
		table.clear(loops)
		movement.unload()
		combat.unload()
		esp.destroy()
	end

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__POLYZUnload = unload
	genv.__POLYZRemoteLogs = debug.getRecentLogs

	print("[MicroHub] POLYZ", Constants.GAME_BUILD)
end

return M
