local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local getModel = opts.getModel

	local function findPart(char: Model, names: { string }): BasePart?
		for _, name in names do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				return part
			end
		end
		return nil
	end

	local function getRoot(char: Model): BasePart?
		return findPart(char, { "HumanoidRootPart", "Torso", "torso" }) or char.PrimaryPart
	end

	local function getHead(char: Model): BasePart?
		return findPart(char, { "Head", "head" })
	end

	local function getVisualModel(player: Player): Model?
		if player == LocalPlayer then
			return player.Character
		end
		if getModel then
			local ok, model = pcall(getModel, player)
			if ok and model and model:IsA("Model") then
				return model
			end
		end
		return nil
	end

	local function isAlive(char: Model?): (boolean, Humanoid?, BasePart?)
		if not char or not char:IsA("Model") then
			return false
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = getRoot(char)
		if not hum or not root or hum.Health <= 0 then
			return false
		end
		return true, hum, root
	end

	local function inCombatZone(char: Model?): boolean
		return char ~= nil and char.Parent ~= game:GetService("Lighting")
	end

	return {
		getRoot = getRoot,
		getHead = getHead,
		getVisualModel = getVisualModel,
		isAlive = isAlive,
		inCombatZone = inCombatZone,
	}
end

return M
