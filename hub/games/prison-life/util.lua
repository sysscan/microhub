local M = {}

function M.getCharacter(player: Player?): Model?
	return player and player.Character
end

function M.isAlive(char: Model?): (boolean, Humanoid?, BasePart?)
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if hum and root and hum.Health > 0 then
		return true, hum, root
	end
	return false, hum, root
end

return M
