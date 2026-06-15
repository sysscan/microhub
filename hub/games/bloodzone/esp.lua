local require = shared.__MicroHubRequire
local PlayerESP = require("lib/esp/player-v2.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local util = opts.util

	return PlayerESP.create({
		config = Config,
		camera = opts.camera,
		localPlayer = opts.localPlayer,
		canDraw = opts.canDraw,
		dimColor = Constants.DIM,
		getCharacter = util.getCharacter,
		isAlive = util.isAlive,
		getAccent = function(_player: Player, _char: Model): Color3
			return Config.ESPPlayerColor
		end,
		getNameSuffix = function(char: Model): string
			if util.isProtected(char) then
				return " [safe]"
			end
			return ""
		end,
		shouldSkip = function(_player: Player, char: Model): boolean
			if not util.inCombatZone(char) then
				return true
			end
			if Config.AimSkipSafe and util.isProtected(char) then
				return true
			end
			return false
		end,
		getMaxDist = function(): number
			return tonumber(Config.ESPMaxDistance) or 1200
		end,
	})
end

return M
