--[[ Lumber Tycoon 2 — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/lumber-tycoon-2/config.lua")
local Constants = require("games/lumber-tycoon-2/constants.lua")
local Util = require("games/lumber-tycoon-2/util.lua")
local LoopsLib = require("games/lumber-tycoon-2/loops.lua")
local RemotesLib = require("games/lumber-tycoon-2/remotes.lua")
local MovementLib = require("games/lumber-tycoon-2/movement.lua")
local TeleportLib = require("games/lumber-tycoon-2/teleport.lua")
local ChopLib = require("games/lumber-tycoon-2/chop.lua")
local WoodLib = require("games/lumber-tycoon-2/wood.lua")
local ExtrasLib = require("games/lumber-tycoon-2/extras.lua")
local ESPLib = require("games/lumber-tycoon-2/esp.lua")
local UILibDef = require("games/lumber-tycoon-2/ui.lua")
local BootstrapLib = require("games/lumber-tycoon-2/bootstrap.lua")

local M = {}

function M.run()
	warn("[LumberTycoon2] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local connections = {}
	local loops = {}
	local loopHelpers = LoopsLib.create(loops)

	local remotes = RemotesLib.create({
		replicatedStorage = ReplicatedStorage,
		localPlayer = LocalPlayer,
	})

	local movement = MovementLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		runService = RunService,
	})

	local teleport = TeleportLib.create({
		localPlayer = LocalPlayer,
		config = Config,
		constants = Constants,
		util = Util,
	})

	local chop = ChopLib.create({
		config = Config,
		constants = Constants,
		util = Util,
		remotes = remotes,
		localPlayer = LocalPlayer,
	})

	local wood = WoodLib.create({
		config = Config,
		constants = Constants,
		util = Util,
		remotes = remotes,
		localPlayer = LocalPlayer,
	})

	local extras = ExtrasLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		remotes = remotes,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		camera = Camera,
		util = Util,
		canDraw = canDraw,
	})

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		constants = Constants,
		teleport = teleport,
		wood = wood,
		chop = chop,
		extras = extras,
		remotes = remotes,
	})

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		movement = movement,
		chop = chop,
		wood = wood,
		esp = esp,
		extras = extras,
		remotes = remotes,
		connections = connections,
		loopHelpers = loopHelpers,
	})

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
		movement.stopAntiAfk()
		movement.unload()
		extras.unload()
		esp.destroy()
		local genv = typeof(getgenv) == "function" and getgenv() or _G
		genv.__LumberTycoon2Unload = nil
	end

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__LumberTycoon2Unload = unload

	print("[MicroHub] Lumber Tycoon 2", Constants.GAME_BUILD, "loaded")
end

return M
