local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local Camera = opts.camera
	local targets = opts.targets
	local util = opts.util
	local canDraw = opts.canDraw

	local collectTargets = targets.collectTargets
	local isCombatModel = targets.isCombatModel
	local displayName = targets.displayName
	local playerColor = targets.playerColor

	local WHITE = Constants.WHITE
	local DIM = Constants.DIM
	local BAR_BG = Constants.BAR_BG
	local BACKDROP = Constants.BACKDROP
	local CORNER_OFFSETS = Constants.CORNER_OFFSETS
	local ESP_DRAWABLES = Constants.ESP_DRAWABLES

	local playerEsp: { [Model]: any } = {}
	local itemEsp: { [Model]: any } = {}
	local zoneEsp: { [string]: any } = {}
	local playerNeedsHide = false
	local itemNeedsHide = false

	local function formatDistance(studs: number): string
		if studs >= 1000 then
			return string.format("%.1fkm", studs / 1000)
		end
		return string.format("%dm", math.floor(studs))
	end

	local function mk(kind: string, props: { [string]: any })
		local d = Drawing.new(kind)
		for k, v in props do
			d[k] = v
		end
		d.Visible = false
		return d
	end

	local function hpColor(ratio: number): Color3
		if ratio > 0.55 then
			return Color3.fromRGB(72, 214, 128)
		end
		if ratio > 0.25 then
			return Color3.fromRGB(255, 196, 72)
		end
		return Color3.fromRGB(255, 86, 92)
	end

	local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
		if not char.Parent or not root.Parent then
			return nil
		end

		local head = util.getHead(char)
		if head then
			local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0))
			local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))
			if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
				local height = math.max(12, bot.Y - top.Y)
				local width = height * 0.52
				return top.X - width * 0.5, top.Y, width, height
			end
		end

		local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
		if onScreen and pos.Z > 0 then
			local height = 56
			local width = height * 0.52
			return pos.X - width * 0.5, pos.Y - height * 0.5, width, height
		end

		return nil
	end

	local function setPlayerVisible(entry: any, visible: boolean, snaplines: boolean?)
		for _, key in ESP_DRAWABLES do
			entry[key].Visible = visible and (key ~= "line" or snaplines == true)
		end
		for _, corner in entry.corners do
			corner.Visible = visible
		end
	end

	local function destroyEntry(entry: any, keys: { string })
		for _, key in keys do
			if entry[key] then
				entry[key]:Remove()
			end
		end
	end

	local function ensurePlayer(char: Model)
		local entry = playerEsp[char]
		if entry then
			return entry
		end

		local corners = table.create(8)
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
		playerEsp[char] = entry
		return entry
	end

	local function ensureItem(item: Model)
		local entry = itemEsp[item]
		if entry then
			return entry
		end
		entry = {
			name = mk("Text", { Size = 12, Center = true, Outline = true }),
			dist = mk("Text", { Size = 10, Center = true, Outline = true, Transparency = 0.12 }),
		}
		itemEsp[item] = entry
		return entry
	end

	local function ensureZone(name: string)
		local entry = zoneEsp[name]
		if entry then
			return entry
		end
		entry = {
			name = mk("Text", { Size = 13, Center = true, Outline = true }),
			dist = mk("Text", { Size = 10, Center = true, Outline = true, Transparency = 0.12 }),
		}
		zoneEsp[name] = entry
		return entry
	end

	local function drawCorners(corners: { any }, x: number, y: number, w: number, h: number, color: Color3)
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

		for _, corner in corners do
			corner.Color = color
			corner.Visible = true
		end
	end

	local function drawPlayer(name: string, char: Model, hum: Humanoid, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
		local x, y, w, h = box2d(char, root)
		if not x then
			local entry = playerEsp[char]
			if entry then
				setPlayerVisible(entry, false)
			end
			return
		end

		local entry = ensurePlayer(char)
		local accent = playerColor()
		local cx = x + w * 0.5
		local bottom = y + h
		local hp = hum.Health
		local maxHp = if hum.MaxHealth > 0 then hum.MaxHealth else 100
		local ratio = math.clamp(hp / maxHp, 0, 1)
		local barW = math.max(38, w + 4)
		local barX = cx - barW * 0.5
		local barY = bottom + 6

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
		entry.hpOutline.Size = Vector2.new(barW, 3)
		entry.hpOutline.Visible = true

		entry.hpFill.Position = Vector2.new(barX, barY)
		entry.hpFill.Size = Vector2.new(math.max(1, barW * ratio), 3)
		entry.hpFill.Color = hpColor(ratio)
		entry.hpFill.Visible = true

		entry.dist.Position = Vector2.new(cx, barY + 7)
		entry.dist.Text = formatDistance((root.Position - camPos).Magnitude)
		entry.dist.Color = DIM
		entry.dist.Visible = true

		if snapFrom then
			entry.line.From = snapFrom
			entry.line.To = Vector2.new(cx, bottom + 1)
			entry.line.Color = accent
		end
		entry.line.Visible = Config.ESPSnaplines and snapFrom ~= nil
	end

	local function drawItem(item: Model, root: BasePart, camPos: Vector3)
		local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
		if not onScreen or pos.Z <= 0 then
			local entry = itemEsp[item]
			if entry then
				entry.name.Visible = false
				entry.dist.Visible = false
			end
			return
		end

		local entry = ensureItem(item)
		entry.name.Position = Vector2.new(pos.X, pos.Y - 8)
		entry.name.Text = item.Name
		entry.name.Color = Config.ESPItemColor
		entry.name.Visible = true
		entry.dist.Position = Vector2.new(pos.X, pos.Y + 6)
		entry.dist.Text = formatDistance((root.Position - camPos).Magnitude)
		entry.dist.Color = DIM
		entry.dist.Visible = true
	end

	local function drawZone(zoneName: string, part: BasePart, camPos: Vector3)
		local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or pos.Z <= 0 then
			local entry = zoneEsp[zoneName]
			if entry then
				entry.name.Visible = false
				entry.dist.Visible = false
			end
			return
		end

		local label = zoneName:gsub("^__", ""):gsub("zone$", "")
		local entry = ensureZone(zoneName)
		entry.name.Position = Vector2.new(pos.X, pos.Y - 8)
		entry.name.Text = string.upper(label)
		entry.name.Color = Config.ESPZoneColor
		entry.name.Visible = true
		entry.dist.Position = Vector2.new(pos.X, pos.Y + 6)
		entry.dist.Text = formatDistance((part.Position - camPos).Magnitude)
		entry.dist.Color = DIM
		entry.dist.Visible = true
	end

	local function hidePlayerEsp()
		for _, entry in playerEsp do
			setPlayerVisible(entry, false)
		end
		playerNeedsHide = false
	end

	local function hideItemEsp()
		for _, entry in itemEsp do
			entry.name.Visible = false
			entry.dist.Visible = false
		end
		itemNeedsHide = false
	end

	local function updatePlayers(camPos: Vector3, snapFrom: Vector2?)
		if not Config.ESP then
			if playerNeedsHide then
				hidePlayerEsp()
			end
			return
		end
		playerNeedsHide = true

		local seen: { [Model]: boolean } = {}
		for char, name in collectTargets() do
			local alive, hum, root = isCombatModel(char)
			if alive and hum and root then
				seen[char] = true
				drawPlayer(name, char, hum, root, camPos, snapFrom)
			end
		end

		for char, entry in playerEsp do
			if not seen[char] or not char.Parent then
				destroyEntry(entry, ESP_DRAWABLES)
				for _, corner in entry.corners do
					corner:Remove()
				end
				playerEsp[char] = nil
			end
		end
	end

	local function updateItems(camPos: Vector3)
		if not Config.ESPItems then
			if itemNeedsHide then
				hideItemEsp()
			end
			return
		end
		itemNeedsHide = true

		local folder = workspace:FindFirstChild("__items")
		if not folder then
			return
		end

		local seen: { [Model]: boolean } = {}
		for _, item in folder:GetChildren() do
			if item:IsA("Model") then
				local root = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
				if root then
					seen[item] = true
					drawItem(item, root, camPos)
				end
			end
		end

		for item, entry in itemEsp do
			if not seen[item] or not item.Parent then
				destroyEntry(entry, { "name", "dist" })
				itemEsp[item] = nil
			end
		end
	end

	local function updateZones(camPos: Vector3)
		if not Config.ESPZones then
			for _, entry in zoneEsp do
				entry.name.Visible = false
				entry.dist.Visible = false
			end
			return
		end

		for _, zoneName in Constants.ZONE_NAMES do
			local part = workspace:FindFirstChild(zoneName)
			if part and part:IsA("BasePart") then
				drawZone(zoneName, part, camPos)
			end
		end
	end

	local function updateESP()
		if not canDraw then
			return
		end

		local camPos = Camera.CFrame.Position
		local snapFrom = if Config.ESPSnaplines
			then Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
			else nil

		updatePlayers(camPos, snapFrom)
		updateItems(camPos)
		updateZones(camPos)
	end

	local function destroy()
		for char, entry in playerEsp do
			destroyEntry(entry, ESP_DRAWABLES)
			for _, corner in entry.corners do
				corner:Remove()
			end
			playerEsp[char] = nil
		end
		for item, entry in itemEsp do
			destroyEntry(entry, { "name", "dist" })
			itemEsp[item] = nil
		end
		for name, entry in zoneEsp do
			destroyEntry(entry, { "name", "dist" })
			zoneEsp[name] = nil
		end
	end

	return {
		updateESP = updateESP,
		destroy = destroy,
	}
end

return M
