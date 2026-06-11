local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local Players = opts.players

	local GREY_TEAM = Constants.GREY_TEAM
	local wallsFolder = workspace:FindFirstChild("Walls")

	local function refreshWallsFolder()
		if not wallsFolder or not wallsFolder.Parent then
			wallsFolder = workspace:FindFirstChild("Walls")
		end
	end

	local function normTeam(value: any): any
		if value == nil then
			return nil
		end
		return tonumber(value) or value
	end

	local function teamsEqual(a: any, b: any): boolean
		a, b = normTeam(a), normTeam(b)
		return a ~= nil and b ~= nil and a == b
	end

	local function getGameMode(): string
		local info = workspace:FindFirstChild("GameInfo")
		local mode = info and info:FindFirstChild("Mode")
		return if mode and mode:IsA("StringValue") then mode.Value else ""
	end

	local function findPlayer(name: string): Player?
		local child = Players:FindFirstChild(name)
		if child and child:IsA("Player") then
			return child
		end
		for _, p in Players:GetPlayers() do
			if p.Name == name then
				return p
			end
		end
		return nil
	end

	local function getLocalTeam(): any
		local id = LocalPlayer:GetAttribute("Team")
		if id == nil then
			local record = Players:FindFirstChild(LocalPlayer.Name)
			id = record and record:GetAttribute("Team")
		end
		return if id == nil then nil else normTeam(id)
	end

	local function hasTeamPlay(): boolean
		if getLocalTeam() == nil or LocalPlayer.TeamColor == GREY_TEAM then
			return false
		end
		local mode = getGameMode()
		return mode ~= "VOTE" and mode ~= "END"
	end

	local function teamColor(rel: string): Color3
		if rel == "Enemy" then
			return Config.ESPEnemyColor
		end
		if rel == "Ally" then
			return Config.ESPAllyColor
		end
		return Config.ESPNeutralColor
	end

	local function getTeamFor(name: string, char: Model?): any
		local rec = Players:FindFirstChild(name)
		local id = rec and rec:GetAttribute("Team")
		if id == nil then
			local p = findPlayer(name)
			id = p and p:GetAttribute("Team")
		end
		if id == nil and char then
			id = char:GetAttribute("Team")
		end
		return if id == nil then nil else normTeam(id)
	end

	local function relation(name: string, char: Model?): string
		if name == LocalPlayer.Name then
			return "Ally"
		end
		if name == "Skinwalker" or not hasTeamPlay() then
			return "Enemy"
		end
		local pt = getTeamFor(name, char)
		return if pt ~= nil and teamsEqual(getLocalTeam(), pt) then "Ally" else "Enemy"
	end

	local function displayName(name: string): string
		local player = findPlayer(name)
		return if player then player.DisplayName else name
	end

	local function isAllySpawnShielded(name: string): boolean
		if not hasTeamPlay() or not teamsEqual(getLocalTeam(), getTeamFor(name)) then
			return false
		end
		refreshWallsFolder()
		return wallsFolder ~= nil and wallsFolder:FindFirstChild(name .. "Forcefield") ~= nil
	end

	local function isCombatModel(model: Instance?): (boolean, Humanoid?, BasePart?)
		if not model or not model:IsA("Model") or model == LocalPlayer.Character or model.Name == "ViewModel" then
			return false
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then
			return false
		end
		return true, hum, root
	end

	local function isKnownCombatant(name: string): boolean
		if name == "Skinwalker" then
			return getGameMode() == "BOSS"
		end
		if name == LocalPlayer.Name then
			return false
		end
		return Players:FindFirstChild(name) ~= nil or findPlayer(name) ~= nil
	end

	local function getSpawned(): { [string]: Model }
		local spawned = {}
		for _, record in Players:GetChildren() do
			if record.Name == LocalPlayer.Name then
				continue
			end
			local char = workspace:FindFirstChild(record.Name)
			if not char or not char:IsA("Model") then
				continue
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				spawned[record.Name] = char
			end
		end
		return spawned
	end

	local function collectTargets(): { [Model]: string }
		local t: { [Model]: string } = {}
		local function add(name: string?, char: Instance?)
			if not name or name == LocalPlayer.Name or not char or not char:IsA("Model") or t[char] then
				return
			end
			if name == "Skinwalker" or isKnownCombatant(name) then
				t[char] = name
			end
		end
		for name, char in getSpawned() do
			add(name, char)
		end
		for _, rec in Players:GetChildren() do
			add(rec.Name, workspace:FindFirstChild(rec.Name))
		end
		for _, p in Players:GetPlayers() do
			if p ~= LocalPlayer then
				add(p.Name, workspace:FindFirstChild(p.Name))
				add(p.Name, p.Character)
			end
		end
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and isKnownCombatant(child.Name) then
				add(child.Name, child)
			end
		end
		if getGameMode() == "BOSS" then
			add("Skinwalker", workspace:FindFirstChild("Skinwalker"))
		end
		return t
	end

	return {
		normTeam = normTeam,
		teamsEqual = teamsEqual,
		getGameMode = getGameMode,
		findPlayer = findPlayer,
		getLocalTeam = getLocalTeam,
		hasTeamPlay = hasTeamPlay,
		teamColor = teamColor,
		getTeamFor = getTeamFor,
		relation = relation,
		displayName = displayName,
		isAllySpawnShielded = isAllySpawnShielded,
		isCombatModel = isCombatModel,
		isKnownCombatant = isKnownCombatant,
		getSpawned = getSpawned,
		collectTargets = collectTargets,
	}
end

return M
