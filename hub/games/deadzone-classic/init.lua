local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local require = shared.__MicroHubRequire

local Config = require("games/deadzone-classic/config.lua")
local Constants = require("games/deadzone-classic/constants.lua")
local UtilLib = require("games/deadzone-classic/util.lua")
local LoopsLib = require("games/deadzone-classic/loops.lua")
local RemotesLib = require("games/deadzone-classic/remotes.lua")
local StatsLib = require("games/deadzone-classic/stats.lua")
local BypassLib = require("games/deadzone-classic/bypass.lua")
local TargetsLib = require("games/deadzone-classic/targets.lua")
local MovementLib = require("games/deadzone-classic/movement.lua")
local CombatLib = require("games/deadzone-classic/combat.lua")
local ESPLib = require("games/deadzone-classic/esp.lua")
local AutomationLib = require("games/deadzone-classic/automation.lua")
local UILibDef = require("games/deadzone-classic/ui.lua")
local BootstrapLib = require("games/deadzone-classic/bootstrap.lua")
local DebuggerLib = require("games/deadzone-classic/debugger.lua")

local genv = typeof(getgenv) == "function" and getgenv() or _G
genv.__DeadzoneClassicConfig = Config

local M = {}

function M.run()
	warn("[DeadzoneClassic] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local canHook = typeof(hookfunction) == "function"
	local connections: { RBXScriptConnection } = {}
	local loops: { thread } = {}
	local loopHelpers = LoopsLib.create(loops)

	local remotes = RemotesLib.create({ replicatedStorage = ReplicatedStorage })

	local bypass = BypassLib.create({
		config = Config,
		replicatedStorage = ReplicatedStorage,
	})
	bypass.waitAndInstall(12)

	local stats = StatsLib.create({ remoteEvents = remotes.events })

	local util = UtilLib.create({
		localPlayer = LocalPlayer,
		getModel = remotes.getModel,
	})

	local targets = TargetsLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		players = Players,
		util = util,
	})

	local movement = MovementLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		util = util,
	})

	local combat = CombatLib.create({
		config = Config,
		replicatedStorage = ReplicatedStorage,
		camera = Camera,
		userInputService = UserInputService,
		targets = targets,
		util = util,
		canDraw = canDraw,
		canHook = canHook,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		camera = Camera,
		targets = targets,
		util = util,
		canDraw = canDraw,
	})

	local automation = AutomationLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		remotes = remotes,
		stats = stats,
		util = util,
	})

	local debugger = DebuggerLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		constants = Constants,
		bypass = bypass,
	})

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		combat = combat,
		movement = movement,
		bypass = bypass,
		debugger = debugger,
	})

	bypass.sync()
	movement.applyWalkSpeed()

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		targets = targets,
		movement = movement,
		combat = combat,
		esp = esp,
		automation = automation,
		connections = connections,
		loopHelpers = loopHelpers,
	})

	movement.ensureSpeedBoost()

	if LocalPlayer.Character then
		movement.onCharacterAdded()
	end
	table.insert(connections, LocalPlayer.CharacterAdded:Connect(movement.onCharacterAdded))

	genv.__DeadzoneClassicUnload = function()
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		for _, threadRef in loops do
			loopHelpers.stop(threadRef)
		end
		table.clear(loops)
		combat.destroy()
		esp.destroy()
		movement.destroy()
		stats.destroy()
		debugger.destroy()
		bypass.uninstall()
	end

	print(
		"[MicroHub] Deadzone Classic",
		Constants.GAME_BUILD,
		"— Drawing:",
		canDraw,
		"— AC hook:",
		bypass.isInstalled(),
		"— client AC off:",
		bypass.isClientNeutralized()
	)
end

return M
