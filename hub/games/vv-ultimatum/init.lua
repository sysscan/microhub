--[[ VV ULTIMATUM — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/vv-ultimatum/config.lua")
local Constants = require("games/vv-ultimatum/constants.lua")
local LoopsLib = require("games/vv-ultimatum/loops.lua")
local RemotesLib = require("games/vv-ultimatum/remotes.lua")
local PlayerDataLib = require("games/vv-ultimatum/player-data.lua")
local TargetsLib = require("games/vv-ultimatum/targets.lua")
local MovementLib = require("games/vv-ultimatum/movement.lua")
local CombatLib = require("games/vv-ultimatum/combat.lua")
local AutomationLib = require("games/vv-ultimatum/automation.lua")
local TeleportLib = require("games/vv-ultimatum/teleport.lua")
local ESPLib = require("games/vv-ultimatum/esp.lua")
local UILibDef = require("games/vv-ultimatum/ui.lua")
local BootstrapLib = require("games/vv-ultimatum/bootstrap.lua")
local Safety = require("games/vv-ultimatum/safety.lua")
local DebuggerLib = require("games/vv-ultimatum/debugger.lua")

local M = {}

function M.run()
	Safety.safeCall("init", function()
		M._run()
	end)
end

function M._run()
	warn("[VVUltimatum] build", Constants.GAME_BUILD)

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

	local remotes = RemotesLib.create({
		replicatedStorage = ReplicatedStorage,
	})

	local debugger = DebuggerLib.create({
		config = Config,
	})
	debugger.hookRemotes(remotes)
	debugger.start(LocalPlayer)

	local playerData = PlayerDataLib.create({
		replicatedStorage = ReplicatedStorage,
		localPlayer = LocalPlayer,
	})

	local targets = TargetsLib.create({
		players = Players,
		localPlayer = LocalPlayer,
	})

	task.spawn(function()
		playerData.waitForProfile(90)
	end)

	local movement = MovementLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		debugger = debugger,
	})

	local combat = CombatLib.create({
		config = Config,
		remotes = remotes,
		movement = movement,
		targets = targets,
	})

	local automation = AutomationLib.create({
		config = Config,
		constants = Constants,
		remotes = remotes,
		playerData = playerData,
		movement = movement,
		combat = combat,
	})

	local teleport = TeleportLib.create({
		config = Config,
		constants = Constants,
		remotes = remotes,
		playerData = playerData,
		debugger = debugger,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		camera = Camera,
		localPlayer = LocalPlayer,
		playerData = playerData,
		targets = targets,
		canDraw = canDraw,
	})

	UILibDef.create({
		config = Config,
		constants = Constants,
		uiLib = UILib,
		teleport = teleport,
		playerData = playerData,
		debugger = debugger,
		movement = movement,
		combat = combat,
	})

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		esp = esp,
		combat = combat,
		automation = automation,
		movement = movement,
		connections = connections,
		loopHelpers = loopHelpers,
	})

	table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
		movement.onCharacterAdded()
	end))

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
		combat.destroy()
		esp.destroy()
		movement.destroy()
		debugger.destroy()
	end

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__VVUltimatumUnload = unload
	genv.__VVUltimatumDebug = debugger

	print("[MicroHub] VV Ultimatum", Constants.GAME_BUILD, "— Drawing:", canDraw)
end

return M
