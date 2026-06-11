--[[ Prison Life — module assembly + lifecycle ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")

local require = shared.__MicroHubRequire

local Config = require("games/prison-life/config.lua")
local Constants = require("games/prison-life/constants.lua")
local Util = require("games/prison-life/util.lua")
local LoopsLib = require("games/prison-life/loops.lua")
local RemotesLib = require("games/prison-life/remotes.lua")
local TeamsLib = require("games/prison-life/teams.lua")
local CombatLib = require("games/prison-life/combat.lua")
local MovementLib = require("games/prison-life/movement.lua")
local PickupLib = require("games/prison-life/pickup.lua")
local AutomationLib = require("games/prison-life/automation.lua")
local VisualsLib = require("games/prison-life/visuals.lua")
local ESPLib = require("games/prison-life/esp.lua")
local C4ESPLib = require("games/prison-life/c4-esp.lua")
local UILibDef = require("games/prison-life/ui.lua")
local UIHandlersLib = require("games/prison-life/ui-handlers.lua")
local BootstrapLib = require("games/prison-life/bootstrap.lua")

local M = {}

function M.run()
	warn("[PrisonLife] build", Constants.GAME_BUILD)

	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera

	local TeamGuards = Teams:FindFirstChild("Guards")
	local TeamInmates = Teams:FindFirstChild("Inmates")
	local TeamCriminals = Teams:FindFirstChild("Criminals")
	local TeamNeutral = Teams:FindFirstChild("Neutral")

	local UILib = shared.__MicroHubUILib
	if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
		error("MicroHub UI library not loaded — run hub/loader.lua", 0)
	end

	local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local canHook = typeof(hookfunction) == "function"
		and typeof(getconnections) == "function"
		and typeof(debug) == "table"
		and typeof(debug.getupvalue) == "function"
	local canDebug = canHook and typeof(debug.setstack) == "function" and typeof(debug.setconstant) == "function"

	local connections: { RBXScriptConnection } = {}
	local loops: { thread } = {}
	local loopHelpers = LoopsLib.create(loops)
	local spawnTimes: { [Model]: number } = {}
	local localC4: Instance? = nil
	local armorPickups: { Instance } = {}
	local gamepasses: { [string]: boolean } = {}
	local animWhitelist: { [string]: boolean } = {}

	local teams = TeamsLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		teamInmates = TeamInmates,
		teamNeutral = TeamNeutral,
	})

	local remotes = RemotesLib.create({
		replicatedStorage = ReplicatedStorage,
		teams = Teams,
		localPlayer = LocalPlayer,
		teamColor = Constants.TEAM_COLOR,
	})

	local combat = CombatLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		camera = Camera,
		util = Util,
		teams = teams,
		teamGuards = TeamGuards,
		teamInmates = TeamInmates,
		spawnTimes = spawnTimes,
		canHook = canHook,
		canDebug = canDebug,
		canDraw = canDraw,
		gunPriority = Constants.GUN_PRIORITY,
	})

	local movement = MovementLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		camera = Camera,
		maxSafeWalkspeed = Constants.MAX_SAFE_WALKSPEED,
		maxSafeJump = Constants.MAX_SAFE_JUMP,
		canHook = canHook,
		connections = connections,
		loopStart = loopHelpers.start,
	})

	local pickup = PickupLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		teamGuards = TeamGuards,
		teamCriminals = TeamCriminals,
		getRemotes = remotes.getRemotes,
	})

	local automation = AutomationLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		teamGuards = TeamGuards,
		teamInmates = TeamInmates,
		teamCriminals = TeamCriminals,
		healItems = Constants.HEAL_ITEMS,
		util = Util,
		getRemotes = remotes.getRemotes,
		getMeleeRemote = remotes.getMeleeRemote,
		getEntitiesInRange = combat.getEntitiesInRange,
		selectCombatTarget = combat.selectCombatTarget,
		getLocalC4 = function()
			return localC4
		end,
		setLocalC4 = function(value)
			localC4 = value
		end,
		gamepasses = gamepasses,
		armorPickups = armorPickups,
	})

	local visuals = VisualsLib.create({
		config = Config,
		localPlayer = LocalPlayer,
		camera = Camera,
		util = Util,
		combat = combat,
		canDraw = canDraw,
		canDebug = canDebug,
		defaultHitSounds = Constants.DEFAULT_HIT_SOUNDS,
		connections = connections,
		animWhitelist = animWhitelist,
		flagCheater = automation.flagCheater,
	})

	local playerESP = ESPLib.create({
		config = Config,
		camera = Camera,
		localPlayer = LocalPlayer,
		canDraw = canDraw,
		dimColor = Color3.fromRGB(148, 156, 168),
		teams = teams,
		util = Util,
	})

	local c4ESP = C4ESPLib.create({
		config = Config,
		collectionService = CollectionService,
	})

	local modules = {
		movement = movement,
		combat = combat,
		pickup = pickup,
		automation = automation,
		visuals = visuals,
		playerESP = playerESP,
		c4ESP = c4ESP,
	}

	local uiHandlers = UIHandlersLib.create({
		config = Config,
		movement = movement,
		combat = combat,
		automation = automation,
		c4ESP = c4ESP,
		visuals = visuals,
		pickup = pickup,
	})

	local genv = if typeof(getgenv) == "function" then getgenv() else _G
	genv.__PrisonLifeUnload = function()
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		for _, threadRef in loops do
			loopHelpers.stop(threadRef)
		end
		table.clear(loops)
		combat.removeGunHooks()
		movement.setNoJumpCooldown(false)
		movement.setDisabler(false)
		movement.setAntiTaze(false)
		movement.applyFullBright()
		movement.runVehicleWallbang()
		movement.syncKillPlane()
		movement.stopVehicleFly()
		combat.unloadTracerHooks()
		combat.destroySilentAimCircle()
		visuals.destroy()
		automation.clearCheatState()
		playerESP.destroy()
		c4ESP.destroy()
		pickup.clearSeen()
		automation.syncArrestCooldownBar(false)
		table.clear(spawnTimes)
		table.clear(armorPickups)
		localC4 = nil
	end

	UILib.create(UILibDef.build({
		config = Config,
		pickupWeaponOptions = Constants.PICKUP_WEAPON_OPTIONS,
		requestTeamChange = remotes.requestTeamChange,
		giveGiverWeapon = pickup.giveGiverWeapon,
		onToggle = uiHandlers.onToggle,
		onChange = uiHandlers.onChange,
	}))

	BootstrapLib.start({
		config = Config,
		constants = Constants,
		localPlayer = LocalPlayer,
		teamCriminals = TeamCriminals,
		connections = connections,
		loopHelpers = loopHelpers,
		spawnTimes = spawnTimes,
		localC4 = {
			get = function()
				return localC4
			end,
			set = function(value)
				localC4 = value
			end,
		},
		armorPickups = armorPickups,
		gamepasses = gamepasses,
		animWhitelist = animWhitelist,
		canDraw = canDraw,
		canHook = canHook,
		modules = modules,
	})
end

return M
