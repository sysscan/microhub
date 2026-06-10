--[[
	Gunfight Arena — placeIds 15514727567, 14518422161
	Characters: workspace[Name]. Teams: Players child GetAttribute("Team").
	Modes: team TDM/KOTH, FFA (GUN etc.), BOSS (Skinwalker), VOTE/END lobby.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "9-aimbot"
warn("[GunfightArena] build", GAME_BUILD)

local Config = {
	Aimbot = false,
	AimTeamCheck = true,
	AimHold = true,
	AimFOV = 120,
	AimSmooth = 35,
	AimPart = "Head",
	AimFOVCircle = false,
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
local GREY_TEAM = BrickColor.new("Medium stone grey")
local aimFovSq = Config.AimFOV * Config.AimFOV
local aimTarget = nil
local aimFovCircle = nil

local function setAimFOV(value)
	Config.AimFOV = math.clamp(math.floor(value), 20, 500)
	aimFovSq = Config.AimFOV * Config.AimFOV
end


-- Mirror ReplicatedStorage.Network GetSpawned without require() — the module anti-tamper kicks/hangs foreign callers.
local function getSpawned()
	local spawned = {}
	for _, record in ipairs(Players:GetChildren()) do
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

local WHITE = Color3.fromRGB(248, 250, 252)
local DIM = Color3.fromRGB(148, 156, 168)
local BAR_BG = Color3.fromRGB(10, 12, 16)
local BACKDROP = Color3.fromRGB(8, 10, 14)

local function hpColor(ratio)
	if ratio > 0.55 then
		return Color3.fromRGB(72, 214, 128)
	elseif ratio > 0.25 then
		return Color3.fromRGB(255, 196, 72)
	end
	return Color3.fromRGB(255, 86, 92)
end

local function formatDistance(studs)
	if studs >= 1000 then
		return string.format("%.1fkm", studs / 1000)
	end
	return string.format("%dm", math.floor(studs))
end

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
	if id == nil then
		local record = Players:FindFirstChild(LocalPlayer.Name)
		if record then
			id = record:GetAttribute("Team")
		end
	end
	if id == nil then
		return nil
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

	for name, char in pairs(getSpawned()) do
		add(name, char)
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

local function getAimPart(char)
	if not char then
		return nil
	end
	local part = char:FindFirstChild(Config.AimPart or "Head")
	if part and part:IsA("BasePart") then
		return part
	end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function getAimOrigin()
	if UserInputService.MouseEnabled then
		return UserInputService:GetMouseLocation()
	end
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

local function isThirdPerson()
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local vortex = scripts and scripts:FindFirstChild("Vortex")
	if vortex then
		local modifiers = vortex:FindFirstChild("Modifiers")
		local flag = modifiers and modifiers:FindFirstChild("IsThirdPerson")
		if flag and flag:IsA("BoolValue") then
			return flag.Value
		end
	end
	local api = rawget(_G, "GlobalAPI")
	if api and typeof(api.Settings) == "table" then
		local mode = api.Settings.CameraMode
		if mode ~= nil then
			return mode ~= 1
		end
	end
	return LocalPlayer.CameraMinZoomDistance > 1
end

local function syncMouseHitSpot(position)
	if typeof(position) ~= "Vector3" then
		return
	end
	_G.MouseHitSpot = position
	if typeof(getgenv) == "function" then
		local env = getgenv()
		if typeof(env) == "table" then
			env.MouseHitSpot = position
		end
	end
end

local function considerAimCandidate(closest, closestDistSq, worldPos, originX, originY, candidate)
	local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
	if not onScreen or screenPos.Z <= 0 then
		return closest, closestDistSq
	end
	local dx = screenPos.X - originX
	local dy = screenPos.Y - originY
	local distSq = dx * dx + dy * dy
	if distSq >= closestDistSq then
		return closest, closestDistSq
	end
	candidate.position = worldPos
	candidate.screenPos = Vector2.new(screenPos.X, screenPos.Y)
	return candidate, distSq
end

local function getClosestAimTarget(origin)
	local closest = nil
	local closestDistSq = aimFovSq
	local originX, originY = origin.X, origin.Y

	for char, name in pairs(collectTargets()) do
		local alive = isCombatModel(char)
		if not alive or isAllySpawnShielded(name) then
			continue
		end
		if Config.AimTeamCheck and relation(name, char) == "Ally" then
			continue
		end
		local part = getAimPart(char)
		if not part then
			continue
		end
		local candidate = { char = char, name = name, part = part }
		closest, closestDistSq = considerAimCandidate(
			closest,
			closestDistSq,
			part.Position,
			originX,
			originY,
			candidate
		)
	end

	return closest
end

-- 1 = snap, 100 = glide. Frame-rate independent via exponential decay.
local function aimAlpha(dt)
	local smooth = math.clamp(Config.AimSmooth or 35, 1, 100)
	if smooth <= 1 then
		return 1
	end
	local t = (smooth - 1) / 99
	local speed = 72 * (1 - t) ^ 1.45 + 1.8
	return 1 - math.exp(-speed * dt)
end

local function shouldAimActive()
	if not Config.Aimbot then
		return false
	end
	if Config.AimHold then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end
	return true
end

local function updateAimbot(dt)
	local origin = getAimOrigin()

	if aimFovCircle then
		aimFovCircle.Position = origin
		aimFovCircle.Radius = Config.AimFOV
		aimFovCircle.Visible = Config.Aimbot and Config.AimFOVCircle
	end

	if not shouldAimActive() then
		aimTarget = nil
		return
	end

	aimTarget = getClosestAimTarget(origin)

	if not aimTarget or not aimTarget.part or not aimTarget.part.Parent then
		return
	end

	local targetPos = aimTarget.part.Position
	local alpha = aimAlpha(dt)

	if isThirdPerson() then
		local current = _G.MouseHitSpot
		if typeof(current) ~= "Vector3" then
			current = targetPos
		end
		syncMouseHitSpot(current:Lerp(targetPos, alpha))
	else
		syncMouseHitSpot(targetPos)
		local camPos = Camera.CFrame.Position
		local goal = CFrame.new(camPos, targetPos)
		Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)
	end
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
	entry.backdrop.Visible = visible
	for _, corner in ipairs(entry.corners) do
		corner.Visible = visible
	end
	entry.name.Visible = visible
	entry.hpOutline.Visible = visible
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
	entry.backdrop:Remove()
	for _, corner in ipairs(entry.corners) do
		corner:Remove()
	end
	entry.name:Remove()
	entry.hpOutline:Remove()
	entry.hpFill:Remove()
	entry.dist:Remove()
	entry.line:Remove()
end

local function drawCorners(corners, x, y, w, h, color)
	local len = math.clamp(math.min(w, h) * 0.24, 7, 16)
	local right, bottom = x + w, y + h

	corners[1].From = Vector2.new(x, y)
	corners[1].To = Vector2.new(x + len, y)
	corners[2].From = Vector2.new(x, y)
	corners[2].To = Vector2.new(x, y + len)

	corners[3].From = Vector2.new(right, y)
	corners[3].To = Vector2.new(right - len, y)
	corners[4].From = Vector2.new(right, y)
	corners[4].To = Vector2.new(right, y + len)

	corners[5].From = Vector2.new(x, bottom)
	corners[5].To = Vector2.new(x + len, bottom)
	corners[6].From = Vector2.new(x, bottom)
	corners[6].To = Vector2.new(x, bottom - len)

	corners[7].From = Vector2.new(right, bottom)
	corners[7].To = Vector2.new(right - len, bottom)
	corners[8].From = Vector2.new(right, bottom)
	corners[8].To = Vector2.new(right, bottom - len)

	for _, corner in ipairs(corners) do
		corner.Color = color
		corner.Visible = true
	end
end

local function ensure(char)
	local entry = esp[char]
	if entry then
		return entry
	end
	local corners = {}
	for _ = 1, 8 do
		table.insert(corners, mk("Line", { Thickness = 1.2, Transparency = 0.06 }))
	end
	entry = {
		backdrop = mk("Square", { Filled = true, Thickness = 0, Transparency = 0.84 }),
		corners = corners,
		name = mk("Text", { Size = 13, Center = true, Outline = true }),
		hpOutline = mk("Square", { Filled = true, Thickness = 0, Color = BAR_BG }),
		hpFill = mk("Square", { Filled = true, Thickness = 0 }),
		dist = mk("Text", { Size = 10, Center = true, Outline = true, Transparency = 0.12 }),
		line = mk("Line", { Thickness = 1, Transparency = 0.5 }),
	}
	esp[char] = entry
	return entry
end

if canDraw then
	aimFovCircle = mk("Circle", {
		Thickness = 1,
		NumSides = 48,
		Filled = false,
		Transparency = 0.45,
		Color = Color3.fromRGB(255, 255, 255),
	})
	aimFovCircle.Visible = false
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
	local barW = math.max(38, w + 4)
	local barH = 3
	local barX = cx - barW * 0.5
	local barY = bottom + 6
	local dist = (root.Position - camPos).Magnitude

	entry.backdrop.Position = Vector2.new(x - 2, y - 2)
	entry.backdrop.Size = Vector2.new(w + 4, h + 4)
	entry.backdrop.Color = BACKDROP
	entry.backdrop.Visible = true

	drawCorners(entry.corners, x, y, w, h, accent)

	entry.name.Position = Vector2.new(cx, y - 17)
	entry.name.Text = string.format("%s  %d", displayName(name), math.floor(hp))
	entry.name.Color = WHITE
	entry.name.Visible = true

	entry.hpOutline.Position = Vector2.new(barX, barY)
	entry.hpOutline.Size = Vector2.new(barW, barH)
	entry.hpOutline.Visible = true

	entry.hpFill.Position = Vector2.new(barX, barY)
	entry.hpFill.Size = Vector2.new(math.max(1, barW * ratio), barH)
	entry.hpFill.Color = hpColor(ratio)
	entry.hpFill.Visible = true

	entry.dist.Position = Vector2.new(cx, barY + 7)
	entry.dist.Text = formatDistance(dist)
	entry.dist.Color = DIM
	entry.dist.Visible = true

	if Config.ESPSnaplines then
		entry.line.From = snapFrom
		entry.line.To = Vector2.new(cx, bottom + 1)
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
			label = "Combat",
			sections = {
				{
					title = "Aimbot",
					items = {
						{ type = "toggle", key = "Aimbot", label = "Aimbot", hud = "Aimbot" },
						{ type = "toggle", key = "AimTeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "toggle", key = "AimHold", label = "Hold RMB", hud = "Hold RMB" },
						{
							type = "select",
							key = "AimPart",
							label = "Bone",
							options = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
						},
						{ type = "slider", key = "AimFOV", label = "FOV", min = 20, max = 500, step = 10, onChange = setAimFOV },
						{ type = "slider", key = "AimSmooth", label = "Smoothness", min = 1, max = 100, step = 1 },
						{ type = "toggle", key = "AimFOVCircle", label = "FOV Circle", hud = "FOV Circle" },
						{ type = "hint", text = "Smoothness: 1 = snap, 100 = glide. Hold RMB to aim." },
					},
				},
			},
		},
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
RunService:BindToRenderStep("MicroHubGFA_Aim", Enum.RenderPriority.Camera.Value + 1, updateAimbot)

print("[MicroHub] Gunfight Arena", GAME_BUILD, "— Drawing:", canDraw)
