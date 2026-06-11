--[[
	Gunfight Arena — module assembly + lifecycle
	Characters: workspace[Name]. Teams: Players child GetAttribute("Team").
	Modes: team TDM/KOTH, FFA (GUN etc.), BOSS (Skinwalker), VOTE/END lobby.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local require = shared.__MicroHubRequire

local Config = require("games/gunfight-arena/config.lua")
local Constants = require("games/gunfight-arena/constants.lua")
local TeamsLib = require("games/gunfight-arena/teams.lua")
local CombatLib = require("games/gunfight-arena/combat.lua")
local ESPLib = require("games/gunfight-arena/esp.lua")
local UILibDef = require("games/gunfight-arena/ui.lua")
local BootstrapLib = require("games/gunfight-arena/bootstrap.lua")

local M = {}

function M.run()
	warn("[GunfightArena] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera

	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"

	local teams = TeamsLib.create({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		players = Players,
	})

	local combat = CombatLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		camera = Camera,
		userInputService = UserInputService,
		teams = teams,
		canDraw = canDraw,
	})

	local esp = ESPLib.create({
		config = Config,
		constants = Constants,
		camera = Camera,
		teams = teams,
		canDraw = canDraw,
	})

	UILibDef.create({
		config = Config,
		uiLib = UILib,
		combat = combat,
	})

	BootstrapLib.create({
		runService = RunService,
		esp = esp,
		combat = combat,
	})

	print("[MicroHub] Gunfight Arena", Constants.GAME_BUILD, "— Drawing:", canDraw)
end

return M
