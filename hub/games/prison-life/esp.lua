local require = shared.__MicroHubRequire
local PlayerESP = require("lib/esp/player-v2")

local M = {}

function M.create(opts: {
	config: { [string]: any },
	camera: Camera,
	localPlayer: Player,
	canDraw: boolean?,
	dimColor: Color3?,
	teams: {
		getRelation: (Player, Model) -> string,
		relationColor: (string) -> Color3,
		statusSuffix: (Model) -> string,
	},
	util: {
		getCharacter: (Player?) -> Model?,
		isAlive: (Model?) -> (boolean, Humanoid?, BasePart?),
	},
})
	local teams = opts.teams
	local util = opts.util

	return PlayerESP.create({
		config = opts.config,
		camera = opts.camera,
		localPlayer = opts.localPlayer,
		canDraw = opts.canDraw,
		dimColor = opts.dimColor,
		getCharacter = util.getCharacter,
		isAlive = util.isAlive,
		getAccent = function(player: Player, char: Model): Color3
			return teams.relationColor(teams.getRelation(player, char))
		end,
		getNameSuffix = teams.statusSuffix,
		shouldSkip = function(player: Player, char: Model): boolean
			local relation = teams.getRelation(player, char)
			return relation == "Ally" and not opts.config.ESPAllies
		end,
	})
end

return M
