--[[ Shrek In the Backrooms — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/shrek-backrooms/config.lua")
local Constants = require("games/shrek-backrooms/constants.lua")
local LoopsLib = require("games/shrek-backrooms/loops.lua")
local RemotesLib = require("games/shrek-backrooms/remotes.lua")
local MovementLib = require("games/shrek-backrooms/movement.lua")
local TeleportLib = require("games/shrek-backrooms/teleport.lua")
local AutomationLib = require("games/shrek-backrooms/automation.lua")
local ShopLib = require("games/shrek-backrooms/shop.lua")
local ExtrasLib = require("games/shrek-backrooms/extras.lua")
local CombatLib = require("games/shrek-backrooms/combat.lua")
local ESPLib = require("games/shrek-backrooms/esp.lua")
local UILibDef = require("games/shrek-backrooms/ui.lua")
local BootstrapLib = require("games/shrek-backrooms/bootstrap.lua")

local M = {}

function M.run()
	warn("[ShrekBackrooms] build", Constants.GAME_BUILD)

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
	})

	local movement = MovementLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		runService = RunService,
	})

	local teleport = TeleportLib.create({
		localPlayer = LocalPlayer,
		remotes = remotes,
		config = Config,
	})

	local automation = AutomationLib.create({
		config = Config,
		constants = Constants,
		remotes = remotes,
		movement = movement,
	})

	local shop = ShopLib.create({
		config = Config,
		constants = Constants,
		remotes = remotes,
		localPlayer = LocalPlayer,
	})

	local extras = ExtrasLib.create({
		config = Config,
		remotes = remotes,
		localPlayer = LocalPlayer,
	})

	local combat = CombatLib.create({
		config = Config,
		remotes = remotes,
		localPlayer = LocalPlayer,
		movement = movement,
		camera = Camera,
	})

	local esp = ESPLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		camera = Camera,
		canDraw = canDraw,
	})

	local function redeemNow()
		automation.redeemNow()
	end

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		constants = Constants,
		teleport = teleport,
		automation = automation,
		shop = shop,
		extras = extras,
		combat = combat,
		remotes = remotes,
		redeemNow = redeemNow,
	})

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__MicroHubShrekRedeem = redeemNow

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		automation = automation,
		shop = shop,
		extras = extras,
		movement = movement,
		combat = combat,
		esp = esp,
		teleport = teleport,
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
		movement.unload()
		esp.destroy()
	end

	genv.__ShrekBackroomsUnload = unload

	print(
		"[MicroHub] Shrek Backrooms",
		Constants.GAME_BUILD,
		"— set code: getgenv().__MicroHubShrekCode = 'CODE'"
	)
end

return M
