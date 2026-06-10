--[[
	Gunfight Arena — placeIds 15514727567, 14518422161
	Characters: workspace[Name]. Teams: Players child GetAttribute("Team").
	Modes: team TDM/KOTH, FFA (GUN etc.), BOSS (Skinwalker), VOTE/END lobby.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "6-all-modes"
warn("[GunfightArena] build", GAME_BUILD)

local Config = {
	ESP = true,
	ESPAllies = true,
	ESPSnaplines = true,
	ShowHUD = true,
	ESPEnemyColor = Color3.fromRGB(255, 72, 88),
	ESPAllyColor = Color3.fromRGB(72, 168, 255),
	ESPNeutralColor = Color3.fromRGB(255, 210, 96),
}

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local esp = {}
local wallsFolder = workspace:FindFirstChild("Walls")
local espNeedsHide = false
local getSpawnedFn = nil
local GREY_TEAM = BrickColor.new("Medium stone grey")

do
	local ok, net = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Network"))()
	end)
	if ok and typeof(net) == "table" and typeof(net.GetSpawned) == "function" then
		getSpawnedFn = net.GetSpawned
	end
end

local WHITE = Color3.fromRGB(245, 247, 250)
local DIM = Color3.fromRGB(168, 174, 184)
local BAR_BG = Color3.fromRGB(18, 20, 26)

local CORNER_OFFSETS = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

local function getGameMode()
	local info = workspace:FindFirstChild("GameInfo")
	local mode = info and info:FindFirstChild("Mode")
	if mode and mode:IsA("StringValue") then
		return mode.Value
	end
	return ""
end

local function normTeam(value)
	if value == nil then
		return nil
	end
	return tonumber(value) or value
end

local function teamsEqual(a, b)
	a, b = normTeam(a), normTeam(b)
	if a == nil or b == nil then
		return false
	end
	return a == b
end

local function getLocalTeam()
	local id = LocalPlayer:GetAttribute("Team")
	if id == nil and LocalPlayer.Team then
		id = LocalPlayer.Team.Name
	end
	if id == nil then
		local record = Players:FindFirstChild(LocalPlayer.Name)
		if record then
			id = record:GetAttribute("Team")
		end
	end
	return normTeam(id)
end

local function hasTeamPlay()
	if getLocalTeam() == nil then
		return false
	end
	if LocalPlayer.TeamColor == GREY_TEAM then
		return false
	end
	local mode = getGameMode()
	if mode == "VOTE" or mode == "END" then
		return false
	end
	return true
end

local function teamColor(rel)
	if rel == "Enemy" then
		return Config.ESPEnemyColor
	elseif rel == "Ally" then
		return Config.ESPAllyColor
	end
	return Config.ESPNeutralColor
end

local function getTeamFor(name, char)
	local record = Players:FindFirstChild(name)
	if record then
		local id = record:GetAttribute("Team")
		if id ~= nil then
			return normTeam(id)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == name then
			local id = player:GetAttribute("Team")
			if id == nil and player.Team then
				id = player.Team.Name
			end
			if id ~= nil then
				return normTeam(id)
			end
		end
	end
	if char then
		return normTeam(char:GetAttribute("Team"))
	end
	return nil
end

local function relation(name, char)
	if name == LocalPlayer.Name then
		return "Ally"
	end
	if name == "Skinwalker" then
		return "Enemy"
	end

	local localTeam = getLocalTeam()
	local pt = getTeamFor(name, char)

	if hasTeamPlay() then
		if pt == nil then
			return "Enemy"
		end
		return teamsEqual(localTeam, pt) and "Ally" or "Enemy"
	end

	return "Enemy"
end

local function displayName(name)
	local record = Players:FindFirstChild(name)
	if record and record:IsA("Player") then
		return record.DisplayName
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == name then
			return player.DisplayName
		end
	end
	return name
end

local function isAllySpawnShielded(name)
	if not hasTeamPlay() then
		return false
	end
	if not teamsEqual(getLocalTeam(), getTeamFor(name)) then
		return false
	end
	if not wallsFolder then
		wallsFolder = workspace:FindFirstChild("Walls")
	end
	return wallsFolder and wallsFolder:FindFirstChild(name .. "Forcefield") ~= nil
end

local function isCombatModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	if model == LocalPlayer.Character then
		return false
	end
	if model.Name == "ViewModel" then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return hum and root and hum.Health > 0, hum, root
end

local function isKnownCombatant(name)
	if name == "Skinwalker" then
		return getGameMode() == "BOSS"
	end
	if name == LocalPlayer.Name then
		return false
	end
	if Players:FindFirstChild(name) then
		return true
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == name then
			return true
		end
	end
	return false
end

local function collectTargets()
	local targets = {}

	local function add(name, char)
		if not name or name == LocalPlayer.Name then
			return
		end
		if not char or not char:IsA("Model") then
			return
		end
		if targets[char] then
			return
		end
		if name == "Skinwalker" or isKnownCombatant(name) then
			targets[char] = name
		end
	end

	if getSpawnedFn then
		for name, char in pairs(getSpawnedFn()) do
			add(name, char)
		end
	end

	for _, record in ipairs(Players:GetChildren()) do
		add(record.Name, workspace:FindFirstChild(record.Name))
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			add(player.Name, workspace:FindFirstChild(player.Name))
			if player.Character then
				add(player.Name, player.Character)
			end
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and isKnownCombatant(child.Name) then
			add(child.Name, child)
		end
	end

	if getGameMode() == "BOSS" then
		add("Skinwalker", workspace:FindFirstChild("Skinwalker"))
	end

	return targets
end

local function box2d(char, root)
	local head = char:FindFirstChild("Head")
	if head and root then
		local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0))
		local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))
		if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
			local height = math.max(12, bot.Y - top.Y)
			local width = height * 0.52
			return top.X - width * 0.5, top.Y, width, height
		end
	end

	if root then
		local pos, on = Camera:WorldToViewportPoint(root.Position)
		if on and pos.Z > 0 then
			local height = 56
			local width = height * 0.52
			return pos.X - width * 0.5, pos.Y - height * 0.5, width, height
		end
	end

	local cf, size = char:GetBoundingBox()
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local ok = false
	for i = 1, 8 do
		local o = CORNER_OFFSETS[i]
		local p, on = Camera:WorldToViewportPoint((cf * CFrame.new(hx * o.X, hy * o.Y, hz * o.Z)).Position)
		if on and p.Z > 0 then
			ok = true
			minX = math.min(minX, p.X)
			minY = math.min(minY, p.Y)
			maxX = math.max(maxX, p.X)
			maxY = math.max(maxY, p.Y)
		end
	end
	if not ok then
		return
	end
	return minX, minY, maxX - minX, maxY - minY
end

local function mk(kind, props)
	local d = Drawing.new(kind)
	for k, v in props do
		d[k] = v
	end
	d.Visible = false
	return d
end

local function setVisible(entry, visible)
	entry.box.Visible = visible
	entry.name.Visible = visible
	entry.hpBg.Visible = visible
	entry.hpFill.Visible = visible
	entry.dist.Visible = visible
	entry.line.Visible = visible and Config.ESPSnaplines
end

local function hideAll()
	for _, entry in pairs(esp) do
		setVisible(entry, false)
	end
end

local function destroyEntry(entry)
	entry.box:Remove()
	entry.name:Remove()
	entry.hpBg:Remove()
	entry.hpFill:Remove()
	entry.dist:Remove()
	entry.line:Remove()
end

local function ensure(char)
	local entry = esp[char]
	if entry then
		return entry
	end
	entry = {
		box = mk("Square", { Filled = false, Thickness = 1, Transparency = 0.12 }),
		name = mk("Text", { Size = 12, Center = true, Outline = true }),
		hpBg = mk("Square", { Filled = true, Thickness = 0 }),
		hpFill = mk("Square", { Filled = true, Thickness = 0 }),
		dist = mk("Text", { Size = 11, Center = true, Outline = true, Transparency = 0.18 }),
		line = mk("Line", { Thickness = 1, Transparency = 0.45 }),
	}
	esp[char] = entry
	return entry
end

local function drawTarget(name, char, hum, root, camPos, snapFrom)
	local rel = relation(name, char)
	if rel == "Ally" and not Config.ESPAllies then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local x, y, w, h = box2d(char, root)
	if not x then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local entry = ensure(char)
	local accent = teamColor(rel)
	local cx = x + w * 0.5
	local bottom = y + h
	local hp = hum.Health
	local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
	local ratio = math.clamp(hp / maxHp, 0, 1)
	local barW = math.max(34, w)
	local barH = 2
	local barX = cx - barW * 0.5
	local barY = bottom + 5

	entry.box.Position = Vector2.new(x, y)
	entry.box.Size = Vector2.new(w, h)
	entry.box.Color = accent
	entry.box.Visible = true

	entry.name.Position = Vector2.new(cx, y - 15)
	entry.name.Text = displayName(name)
	entry.name.Color = WHITE
	entry.name.Visible = true

	entry.hpBg.Position = Vector2.new(barX, barY)
	entry.hpBg.Size = Vector2.new(barW, barH)
	entry.hpBg.Color = BAR_BG
	entry.hpBg.Visible = true

	entry.hpFill.Position = Vector2.new(barX, barY)
	entry.hpFill.Size = Vector2.new(barW * ratio, barH)
	entry.hpFill.Color = Color3.fromRGB(255 - ratio * 200, 70 + ratio * 185, 72)
	entry.hpFill.Visible = true

	entry.dist.Position = Vector2.new(cx, barY + 5)
	entry.dist.Text = string.format("%dm", math.floor((root.Position - camPos).Magnitude))
	entry.dist.Color = DIM
	entry.dist.Visible = true

	if Config.ESPSnaplines then
		entry.line.From = snapFrom
		entry.line.To = Vector2.new(cx, bottom)
		entry.line.Color = accent
		entry.line.Visible = true
	else
		entry.line.Visible = false
	end
end

local function updateESP()
	if not canDraw then
		return
	end
	if not Config.ESP then
		if espNeedsHide then
			hideAll()
			espNeedsHide = false
		end
		return
	end
	espNeedsHide = true

	if not wallsFolder or not wallsFolder.Parent then
		wallsFolder = workspace:FindFirstChild("Walls")
	end

	local camPos = Camera.CFrame.Position
	local snapFrom = Config.ESPSnaplines and Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y) or nil
	local seen = {}

	for char, name in pairs(collectTargets()) do
		local alive, hum, root = isCombatModel(char)
		if alive and not isAllySpawnShielded(name) then
			seen[char] = true
			drawTarget(name, char, hum, root, camPos, snapFrom)
		end
	end

	for char, entry in pairs(esp) do
		if not seen[char] or not char.Parent then
			destroyEntry(entry)
			esp[char] = nil
		end
	end
end

UILib.create({
	title = "GUNFIGHT ARENA",
	config = Config,
	pages = {
		{
			label = "Visual",
			sections = {
				{
					title = "ESP",
					items = {
						{ type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
						{ type = "toggle", key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
						{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
						{ type = "label", text = "ESP colors — tap swatch" },
						{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
						{ type = "color", key = "ESPAllyColor", label = "Ally" },
						{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
})

RunService.RenderStepped:Connect(updateESP)

print("[MicroHub] Gunfight Arena", GAME_BUILD, "— Drawing:", canDraw, "GetSpawned:", getSpawnedFn ~= nil)
