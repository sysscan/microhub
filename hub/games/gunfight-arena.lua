--[[
	Gunfight Arena — placeIds 15514727567, 14518422161
	Characters: workspace[Player.Name]. Teams: Player:GetAttribute("Team").
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "2-sleek-esp"
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

local function teamColor(rel)
	if rel == "Enemy" then
		return Config.ESPEnemyColor
	elseif rel == "Ally" then
		return Config.ESPAllyColor
	end
	return Config.ESPNeutralColor
end

local function relation(player, localTeam)
	local pt = player:GetAttribute("Team")
	if localTeam ~= nil and pt ~= nil then
		return localTeam == pt and "Ally" or "Enemy"
	end
	return "Neutral"
end

local function getChar(player)
	local m = workspace:FindFirstChild(player.Name)
	return (m and m:IsA("Model")) and m or player.Character
end

local function isSpawnProtected(player, char)
	if char:FindFirstChildOfClass("ForceField") then
		return true
	end
	if not wallsFolder then
		wallsFolder = workspace:FindFirstChild("Walls")
	end
	return wallsFolder and wallsFolder:FindFirstChild(player.Name .. "Forcefield") ~= nil
end

local function box2d(char)
	local head = char:FindFirstChild("Head")
	local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
	if head and root then
		local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0))
		local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))
		if topOn and botOn and top.Z > 0 and bot.Z > 0 then
			local height = math.max(12, bot.Y - top.Y)
			local width = height * 0.52
			return top.X - width * 0.5, top.Y, width, height
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
			if p.X < minX then
				minX = p.X
			end
			if p.Y < minY then
				minY = p.Y
			end
			if p.X > maxX then
				maxX = p.X
			end
			if p.Y > maxY then
				maxY = p.Y
			end
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

local function ensure(player)
	local entry = esp[player]
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
	esp[player] = entry
	return entry
end

Players.PlayerRemoving:Connect(function(player)
	local entry = esp[player]
	if entry then
		destroyEntry(entry)
		esp[player] = nil
	end
end)

local function drawPlayer(player, char, hum, root, localTeam, camPos, snapFrom)
	local rel = relation(player, localTeam)
	if rel == "Ally" and not Config.ESPAllies then
		local entry = esp[player]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local x, y, w, h = box2d(char)
	if not x then
		local entry = esp[player]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local entry = ensure(player)
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
	entry.name.Text = player.DisplayName
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
	local localTeam = LocalPlayer:GetAttribute("Team")
	local snapFrom = Config.ESPSnaplines and Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y) or nil

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local char = getChar(player)
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
			if hum and root and hum.Health > 0 and not isSpawnProtected(player, char) then
				drawPlayer(player, char, hum, root, localTeam, camPos, snapFrom)
			elseif esp[player] then
				setVisible(esp[player], false)
			end
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

print("[MicroHub] Gunfight Arena", GAME_BUILD, "— Drawing:", canDraw)
