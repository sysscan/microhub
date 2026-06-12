--[[ Slime RNG — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/slime-rng/config.lua")
local Constants = require("games/slime-rng/constants.lua")
local LoopsLib = require("games/slime-rng/loops.lua")
local ServicesLib = require("games/slime-rng/services.lua")
local AutomationLib = require("games/slime-rng/automation.lua")
local ExtrasLib = require("games/slime-rng/extras.lua")
local CombatLib = require("games/slime-rng/combat.lua")
local MovementLib = require("games/slime-rng/movement.lua")
local UILibDef = require("games/slime-rng/ui.lua")
local BootstrapLib = require("games/slime-rng/bootstrap.lua")

local M = {}

function M.run()
	warn("[SlimeRNG] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local connections = {}
	local loops = {}
	local loopHelpers = LoopsLib.create(loops)

	local services = ServicesLib.create({
		replicatedStorage = ReplicatedStorage,
	})

	task.spawn(function()
		if not services.waitReady() then
			warn("[SlimeRNG] game services did not initialize in time")
		end
	end)

	local movement = MovementLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		services = services,
	})

	local extras = ExtrasLib.create({
		config = Config,
		services = services,
	})

	local combat = CombatLib.create({
		config = Config,
		services = services,
		localPlayer = LocalPlayer,
	})

	local automation = AutomationLib.create({
		config = Config,
		services = services,
		extras = extras,
	})

	local function redeemNow()
		automation.redeemNow()
	end

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		movement = movement,
		redeemNow = redeemNow,
	})

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__MicroHubSlimeRedeem = redeemNow

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		automation = automation,
		movement = movement,
		combat = combat,
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
	end

	genv.__SlimeRNGUnload = unload

	print(
		"[MicroHub] Slime RNG",
		Constants.GAME_BUILD,
		"— set shared code: getgenv().__MicroHubSlimeCode = 'CODE'"
	)
end

return M
