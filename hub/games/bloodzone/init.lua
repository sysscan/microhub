local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local require = shared.__MicroHubRequire

local Config = require("games/bloodzone/config.lua")
local Constants = require("games/bloodzone/constants.lua")
local UtilLib = require("games/bloodzone/util.lua")
local LoopsLib = require("games/bloodzone/loops.lua")
local BypassLib = require("games/bloodzone/bypass.lua")
local TargetsLib = require("games/bloodzone/targets.lua")
local MovementLib = require("games/bloodzone/movement.lua")
local CombatLib = require("games/bloodzone/combat.lua")
local ESPLib = require("games/bloodzone/esp.lua")
local UILibDef = require("games/bloodzone/ui.lua")
local BootstrapLib = require("games/bloodzone/bootstrap.lua")

local genv = typeof(getgenv) == "function" and getgenv() or _G
genv.__BloodzoneConfig = Config

local M = {}

function M.run()
	warn("[Bloodzone] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local connections: { RBXScriptConnection } = {}
	local loops: { thread } = {}
	local loopHelpers = LoopsLib.create(loops)

	local bypass = BypassLib.create({
		config = Config,
		replicatedStorage = ReplicatedStorage,
	})

	local installed = bypass.waitAndInstall(12)
	local diag = bypass.getDiagnostics(true)
	if installed then
		warn(
			"[Bloodzone] AC bypass ready — report hook:",
			diag.reportHookInstalled,
			"module stub:",
			diag.moduleStubbed,
			"connections:",
			diag.disabledCount
		)
	else
		warn(
			"[Bloodzone] AC bypass incomplete — hook:",
			diag.canHook,
			"inspect:",
			diag.canInspectConnections,
			"active AC:",
			diag.activeAcConnections
		)
	end

	local util = UtilLib.create({ localPlayer = LocalPlayer })

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
		localPlayer = LocalPlayer,
		camera = Camera,
		userInputService = UserInputService,
		targets = targets,
		util = util,
		canDraw = canDraw,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		camera = Camera,
		localPlayer = LocalPlayer,
		util = util,
		canDraw = canDraw,
	})

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		combat = combat,
		movement = movement,
		bypass = bypass,
	})

	bypass.sync()
	movement.applyWalkSpeed()
	movement.ensureSpeedBoost()
	combat.installCursorHook()

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		targets = targets,
		movement = movement,
		combat = combat,
		esp = esp,
	})

	if LocalPlayer.Character then
		movement.onCharacterAdded()
	end
	table.insert(connections, LocalPlayer.CharacterAdded:Connect(movement.onCharacterAdded))

	genv.__BloodzoneBypass = bypass
	genv.__BloodzoneUnload = function()
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
		bypass.uninstall()
		genv.__BloodzoneBypass = nil
		genv.__BloodzoneConfig = nil
		genv.__BloodzoneUnload = nil
	end

	print(
		"[MicroHub] Bloodzone",
		Constants.GAME_BUILD,
		"— Drawing:",
		canDraw,
		"— AC:",
		bypass.isInstalled()
	)
end

return M
