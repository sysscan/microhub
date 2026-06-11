--[[ Stud Incremental — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire

local Config = require("games/stud-incremental/config.lua")
local Constants = require("games/stud-incremental/constants.lua")
local LoopsLib = require("games/stud-incremental/loops.lua")
local RemotesLib = require("games/stud-incremental/remotes.lua")
local StatsLib = require("games/stud-incremental/stats.lua")
local AutomationLib = require("games/stud-incremental/automation.lua")
local MovementLib = require("games/stud-incremental/movement.lua")
local UILibDef = require("games/stud-incremental/ui.lua")
local BootstrapLib = require("games/stud-incremental/bootstrap.lua")

local M = {}

function M.run()
	warn("[StudIncremental] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local connections = {}
	local loops = {}
	local loopHelpers = LoopsLib.create(loops)

	local remotes = RemotesLib.create({
		replicatedStorage = ReplicatedStorage,
	})

	local stats = StatsLib.create({
		localPlayer = LocalPlayer,
		replicatedStorage = ReplicatedStorage,
	})

	local movement = MovementLib.create({
		config = Config,
		localPlayer = LocalPlayer,
	})

	local automation = AutomationLib.create({
		config = Config,
		constants = Constants,
		remotes = remotes,
		stats = stats,
		localPlayer = LocalPlayer,
	})

	local function redeemNow()
		local genv = typeof(getgenv) == "function" and getgenv() or _G
		local code = genv.__MicroHubStudCode or Config.RedeemCodeText
		if type(code) == "string" and code ~= "" then
			remotes.redeemCode(code)
		end
	end

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		movement = movement,
		redeemNow = redeemNow,
	})

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	genv.__MicroHubStudRedeem = redeemNow

	BootstrapLib.create({
		config = Config,
		runService = RunService,
		automation = automation,
		movement = movement,
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

	local genvUnload = typeof(getgenv) == "function" and getgenv() or _G
	genvUnload.__StudIncrementalUnload = unload

	print(
		"[MicroHub] Stud Incremental",
		Constants.GAME_BUILD,
		"— set shared code: getgenv().__MicroHubStudCode = 'CODE'"
	)
end

return M
