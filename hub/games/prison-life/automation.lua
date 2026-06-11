local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local M = {}

function M.create(opts: {
	config: { [string]: any },
	localPlayer: Player,
	teamGuards: Team?,
	teamInmates: Team?,
	teamCriminals: Team?,
	healItems: { [string]: boolean },
	util: { getCharacter: (Player?) -> Model?, isAlive: (Model?) -> (boolean, Humanoid?, BasePart?) },
	getRemotes: () -> Instance?,
	getMeleeRemote: () -> Instance?,
	getEntitiesInRange: (number, string) -> { any },
	selectCombatTarget: (any) -> (Player?, BasePart?),
	checkPoint: ((Vector3, OverlapParams) -> boolean)?,
	getLocalC4: () -> Instance?,
	setLocalC4: (Instance?) -> (),
	gamepasses: { [string]: boolean },
	armorPickups: { Instance },
})
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local TeamInmates = opts.teamInmates
	local TeamCriminals = opts.teamCriminals
	local HEAL_ITEMS = opts.healItems
	local getCharacter = opts.util.getCharacter
	local getRemotes = opts.getRemotes
	local getMeleeRemote = opts.getMeleeRemote
	local getEntitiesInRange = opts.getEntitiesInRange
	local selectCombatTarget = opts.selectCombatTarget
	local getLocalC4 = opts.getLocalC4
	local setLocalC4 = opts.setLocalC4
	local gamepasses = opts.gamepasses
	local armorPickups = opts.armorPickups

	local arrestCooldown = 0
	local detonateTicks = 0
	local arrestCdHolder: Frame? = nil
	local arrestCdFrame: Frame? = nil
	local arrestCdLabel: TextLabel? = nil

	local cheatFlags: { [number]: { [string]: number } } = {}
	local cheatFlagged: { [number]: boolean } = {}

	local cheatOverlap = OverlapParams.new()
	cheatOverlap.CollisionGroup = "Players"
	cheatOverlap.FilterDescendantsInstances = { workspace:FindFirstChild("CarContainer"), workspace:FindFirstChild("Doors") }
	cheatOverlap.FilterType = Enum.RaycastFilterType.Exclude
	local carOverlap = OverlapParams.new()
	carOverlap.FilterDescendantsInstances = { workspace:FindFirstChild("CarContainer") }
	carOverlap.FilterType = Enum.RaycastFilterType.Include
	carOverlap.MaxParts = 1
	local whitelistStates = {
		[Enum.HumanoidStateType.Running] = true,
		[Enum.HumanoidStateType.Jumping] = true,
		[Enum.HumanoidStateType.Freefall] = true,
		[Enum.HumanoidStateType.Landed] = true,
		[Enum.HumanoidStateType.FallingDown] = true,
		[Enum.HumanoidStateType.Climbing] = true,
		[Enum.HumanoidStateType.Seated] = true,
		[Enum.HumanoidStateType.Ragdoll] = true,
		[Enum.HumanoidStateType.Dead] = true,
		[Enum.HumanoidStateType.None] = true,
	}

	local function checkPoint(pos: Vector3, params: OverlapParams): boolean
		for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
			if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0 then
				return false
			end
		end
		return true
	end

	local function flagCheater(player: Player, flagType: string, limit: number)
		if cheatFlagged[player.UserId] then
			return
		end
		if not cheatFlags[player.UserId] then
			cheatFlags[player.UserId] = {}
		end
		local flags = cheatFlags[player.UserId]
		flags[flagType] = (flags[flagType] or 0) + 1
		if flags[flagType] > limit then
			cheatFlagged[player.UserId] = true
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Cheat Detector",
					Text = "This player may be cheating! (" .. flagType .. "): " .. player.Name,
					Duration = 60,
				})
			end)
		end
	end

	local function syncArrestCooldownBar(enabled: boolean)
		if not enabled then
			if arrestCdHolder then
				arrestCdHolder:Destroy()
				arrestCdHolder = nil
				arrestCdFrame = nil
				arrestCdLabel = nil
			end
			return
		end
		if arrestCdHolder then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "MicroHubPL_ArrestCD"
		gui.ResetOnSpawn = false
		gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
		arrestCdHolder = Instance.new("Frame")
		arrestCdHolder.Name = "Holder"
		arrestCdHolder.Visible = false
		arrestCdHolder.BorderSizePixel = 0
		arrestCdHolder.BackgroundTransparency = 0.7
		arrestCdHolder.AnchorPoint = Vector2.new(0.5, 0)
		arrestCdHolder.BackgroundColor3 = Color3.new(1, 1, 1)
		arrestCdHolder.Size = UDim2.new(0.1, 0, 0, 5)
		arrestCdHolder.Position = UDim2.fromScale(0.5, 0.55)
		arrestCdHolder.Parent = gui
		arrestCdFrame = Instance.new("Frame")
		arrestCdFrame.BorderSizePixel = 0
		arrestCdFrame.BackgroundTransparency = 0.3
		arrestCdFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		arrestCdFrame.Size = UDim2.new(1, -2, 1, -2)
		arrestCdFrame.Position = UDim2.fromOffset(1, 1)
		arrestCdFrame.Parent = arrestCdHolder
		arrestCdLabel = Instance.new("TextLabel")
		arrestCdLabel.Size = UDim2.new(1, 0, 0, 14)
		arrestCdLabel.Position = UDim2.fromOffset(0, 10)
		arrestCdLabel.BackgroundTransparency = 1
		arrestCdLabel.TextColor3 = Color3.new(1, 1, 1)
		arrestCdLabel.TextScaled = true
		arrestCdLabel.TextStrokeTransparency = 0
		arrestCdLabel.Font = Enum.Font.Arial
		arrestCdLabel.Parent = arrestCdHolder
	end

	local function updateArrestCooldownBar()
		if not Config.AutoArrestCooldownBar or not arrestCdHolder or not arrestCdFrame or not arrestCdLabel then
			return
		end
		local onCooldown = arrestCooldown > os.clock()
		arrestCdHolder.Visible = onCooldown
		if onCooldown then
			local diff = arrestCooldown - os.clock()
			arrestCdFrame.Size = UDim2.new(math.clamp(diff / 7, 0, 1), -2, 1, -2)
			arrestCdLabel.Text = string.format("%.1fs", diff)
		end
	end

	local function runKillaura()
		if not Config.Killaura then
			return
		end
		local melee = getMeleeRemote()
		if not melee then
			return
		end
		for _, ent in getEntitiesInRange(Config.KillauraRange, "combat") do
			pcall(function()
				melee:FireServer(ent.player, 1, 1)
			end)
		end
	end

	local function runAutoArrest()
		updateArrestCooldownBar()
		if not Config.AutoArrest or os.clock() < arrestCooldown then
			return
		end
		local remotes = getRemotes()
		local arrest = remotes and remotes:FindFirstChild("ArrestPlayer")
		if not arrest then
			return
		end
		if Config.ArrestHandCheck then
			local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
			if not tool or tool.Name ~= "Handcuffs" then
				return
			end
		end
		for _, ent in getEntitiesInRange(Config.AutoArrestRange, "arrest") do
			local player = ent.player
			local char = ent.char
			if char:GetAttribute("Arrested") then
				continue
			end
			if player.Team == TeamInmates and not Config.ArrestInmates then
				continue
			end
			if player.Team == TeamCriminals and not Config.ArrestCriminals then
				continue
			end
			if player.Team == TeamInmates and char:GetAttribute("Hostile") and not char:GetAttribute("Tased") then
				continue
			end
			local ok, arrested = pcall(function()
				return arrest:InvokeServer(player, 1)
			end)
			if ok and arrested then
				arrestCooldown = os.clock() + 7
				pcall(function()
					StarterGui:SetCore("SendNotification", {
						Title = "Auto Arrest",
						Text = "Arrested " .. player.Name,
						Duration = 5,
					})
				end)
				break
			end
		end
	end

	local function runAutoHeal()
		if not Config.AutoHeal then
			return
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health > 85 then
			return
		end
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		local remotes = getRemotes()
		local eat = remotes and remotes:FindFirstChild("EatFood")
		if not backpack or not eat then
			return
		end
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") and HEAL_ITEMS[tool.Name] then
				if (os.clock() - (tool:GetAttribute("Client_LastConsumedAt") or 0)) < 3 then
					continue
				end
				local equipped = char:FindFirstChildWhichIsA("Tool")
				if equipped then
					equipped.Parent = backpack
				end
				tool.Parent = char
				tool:SetAttribute("Quantity", (tool:GetAttribute("Quantity") or 1) - 1)
				tool:SetAttribute("Client_LastConsumedAt", os.clock())
				pcall(function()
					StarterGui:SetCore("SendNotification", {
						Title = "Auto Heal",
						Text = "Quantity: " .. tostring(tool:GetAttribute("Quantity")),
						Duration = 3,
					})
				end)
				pcall(function()
					eat:FireServer()
				end)
				tool.Parent = backpack
				if equipped then
					equipped.Parent = char
				end
				break
			end
		end
	end

	local function runAutoArmor()
		if not Config.AutoArmor then
			return
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.MaxHealth > 100 then
			return
		end
		local remotes = getRemotes()
		local interact = remotes and remotes:FindFirstChild("InteractWithItem")
		if not interact then
			return
		end
		for _, vest in armorPickups do
			if not vest.Parent or (vest:GetPivot().Position - root.Position).Magnitude >= 10 then
				continue
			end
			if vest.Name == "Light Vest" and gamepasses[if LocalPlayer.Team == TeamCriminals then "Mafia" else "Riot Police"] then
				continue
			end
			local required = vest:GetAttribute("RequiredGamepass")
			if required and not gamepasses[required] then
				continue
			end
			local part = vest:FindFirstChildWhichIsA("BasePart", true)
			if part then
				pcall(function()
					interact:InvokeServer(part)
				end)
			end
		end
	end

	local function runAutoDetonate()
		local localC4 = getLocalC4()
		if not Config.AutoDetonate or not localC4 or not localC4.Parent then
			return
		end
		local remotes = getRemotes()
		local activate = remotes and remotes:FindFirstChild("C4") and remotes.C4:FindFirstChild("ActivateC4")
		if not activate then
			return
		end
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if not root or not backpack then
			return
		end
		local c4Tool = backpack:FindFirstChild("C4 Explosive")
		if not c4Tool then
			return
		end
		local c4Pos = if localC4:IsA("BasePart") then localC4.Position else localC4:GetPivot().Position
		local _, targetPart = selectCombatTarget({
			origin = c4Pos,
			range = 25,
			rangePosition = 25,
			attackCheck = false,
			wallcheck = false,
			wallbang = nil,
			part = "HumanoidRootPart",
			mode = "Position",
		})
		if not targetPart then
			detonateTicks = 0
			return
		end
		local rayParams = RaycastParams.new()
		rayParams.CollisionGroup = "ClientBullet"
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { targetPart.Parent, char, localC4 }
		local blocked = workspace:Raycast(c4Pos, targetPart.Position - c4Pos, rayParams)
		if Config.AutoDetonateSafe and not blocked then
			local rootDiff = root.Position - c4Pos
			blocked = not (workspace:Raycast(c4Pos, rootDiff, rayParams) or rootDiff.Magnitude > 40)
		end
		if blocked then
			detonateTicks = 0
			return
		end
		detonateTicks += 1
		if detonateTicks <= 3 then
			return
		end
		detonateTicks = 0
		local equipped = char:FindFirstChildWhichIsA("Tool")
		if equipped then
			equipped.Parent = backpack
		end
		c4Tool.Parent = char
		pcall(function()
			activate:InvokeServer()
		end)
		c4Tool.Parent = backpack
		if equipped then
			equipped.Parent = char
		end
	end

	local function runAntiRiotShield()
		if not Config.AntiRiotShield then
			return
		end
		for _, player in Players:GetPlayers() do
			local char = getCharacter(player)
			local shield = char and char:FindFirstChild("RiotShieldPart")
			if shield and shield:IsA("BasePart") then
				shield.CanQuery = false
			end
		end
	end

	local function runCheatDetector()
		if not Config.CheatDetector then
			return
		end
		for _, player in Players:GetPlayers() do
			if player == LocalPlayer then
				continue
			end
			local char = getCharacter(player)
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local head = char and char:FindFirstChild("Head")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not hum or not head or not root or hum.Health <= 0 then
				continue
			end
			if head:IsA("BasePart") and not checkPoint(head.Position, cheatOverlap) then
				flagCheater(player, "phase/noclip", 20)
			end
			if not whitelistStates[hum:GetState()] then
				flagCheater(player, "invalid state " .. hum:GetState().Name, 1)
			end
			if not hum.SeatPart then
				local velo = root.AssemblyLinearVelocity
				if (velo * Vector3.new(1, 0, 1)).Magnitude > 26 and #workspace:GetPartBoundsInRadius(root.Position, 10, carOverlap) <= 0 then
					flagCheater(player, "speed", 20)
				end
				if velo.Y > 50 then
					flagCheater(player, "highjump", 20)
				end
			end
		end
	end

	local function runAll()
		runKillaura()
		runAutoArrest()
		runAutoHeal()
		runAutoArmor()
		runAutoDetonate()
		runAntiRiotShield()
		runCheatDetector()
	end

	local function clearCheatState()
		table.clear(cheatFlags)
		table.clear(cheatFlagged)
	end

	return {
		runAll = runAll,
		syncArrestCooldownBar = syncArrestCooldownBar,
		clearCheatState = clearCheatState,
		flagCheater = flagCheater,
	}
end

return M
