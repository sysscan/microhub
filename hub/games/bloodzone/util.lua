local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer

	local function charactersFolder(): Folder?
		local folder = workspace:FindFirstChild("Characters")
		return if folder and folder:IsA("Folder") then folder else nil
	end

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
		return findPart(char, { "HumanoidRootPart", "Torso" }) or char.PrimaryPart
	end

	local function getHead(char: Model): BasePart?
		return findPart(char, { "Head" })
	end

	local function getCharacter(player: Player?): Model?
		if not player then
			return nil
		end

		local folder = charactersFolder()
		if folder then
			local model = folder:FindFirstChild(player.Name)
			if model and model:IsA("Model") then
				return model
			end
		end

		return player.Character
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

	local function isProtected(char: Model): boolean
		if char:GetAttribute("Immune") or char:GetAttribute("InSafeZone") then
			return true
		end
		if char:GetAttribute("Safe") then
			return true
		end
		return false
	end

	local function inCombatZone(char: Model?): boolean
		if not char or not char.Parent then
			return false
		end

		local folder = charactersFolder()
		if folder and char.Parent ~= folder then
			return false
		end

		return not isProtected(char)
	end

	return {
		charactersFolder = charactersFolder,
		getRoot = getRoot,
		getHead = getHead,
		getCharacter = getCharacter,
		isAlive = isAlive,
		isProtected = isProtected,
		inCombatZone = inCombatZone,
	}
end

return M
