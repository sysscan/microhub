local M = {}

function M.create(opts: {
	config: { [string]: any },
	localPlayer: Player,
	teamInmates: Team?,
	teamNeutral: Team?,
})
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local TeamInmates = opts.teamInmates
	local TeamNeutral = opts.teamNeutral

	local function sameTeam(a: Player, b: Player): boolean
		return a.Team ~= nil and b.Team ~= nil and a.Team == b.Team
	end

	local function getRelation(player: Player, char: Model): string
		if player == LocalPlayer then
			return "Ally"
		end
		if sameTeam(player, LocalPlayer) then
			return "Ally"
		end
		if player.Team == TeamNeutral then
			return "Neutral"
		end
		if player.Team == TeamInmates and (char:GetAttribute("Hostile") or char:GetAttribute("Trespassing")) then
			return "Hostile"
		end
		return "Enemy"
	end

	local function relationColor(relation: string): Color3
		if relation == "Ally" then
			return Config.ESPAllyColor
		end
		if relation == "Neutral" then
			return Config.ESPNeutralColor
		end
		if relation == "Hostile" then
			return Config.ESPHostileColor
		end
		return Config.ESPEnemyColor
	end

	local function statusSuffix(char: Model): string
		if not Config.ESPStatusTags then
			return ""
		end
		if char:GetAttribute("Arrested") then
			return " [Arrested]"
		end
		if char:GetAttribute("Tased") then
			return " [Tased]"
		end
		if char:GetAttribute("Hostile") then
			return " [Hostile]"
		end
		if char:GetAttribute("Trespassing") then
			return " [Trespassing]"
		end
		return ""
	end

	return {
		sameTeam = sameTeam,
		getRelation = getRelation,
		relationColor = relationColor,
		statusSuffix = statusSuffix,
	}
end

return M
