local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local Camera = opts.camera
	local teams = opts.teams
	local canDraw = opts.canDraw

	local collectTargets = teams.collectTargets
	local relation = teams.relation
	local displayName = teams.displayName
	local isAllySpawnShielded = teams.isAllySpawnShielded
	local isCombatModel = teams.isCombatModel
	local teamColor = teams.teamColor

	local WHITE = Constants.WHITE
	local DIM = Constants.DIM
	local BAR_BG = Constants.BAR_BG
	local BACKDROP = Constants.BACKDROP
	local CORNER_OFFSETS = Constants.CORNER_OFFSETS
	local ESP_DRAWABLES = Constants.ESP_DRAWABLES

	local esp: { [Model]: any } = {}
	local espNeedsHide = false

	local function hpColor(ratio: number): Color3
		if ratio > 0.55 then
			return Color3.fromRGB(72, 214, 128)
		end
		if ratio > 0.25 then
			return Color3.fromRGB(255, 196, 72)
		end
		return Color3.fromRGB(255, 86, 92)
	end

	local function formatDistance(studs: number): string
		if studs >= 1000 then
			return string.format("%.1fkm", studs / 1000)
		end
		return string.format("%dm", math.floor(studs))
	end

	local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
		if not char.Parent or not root.Parent then
			return nil
		end

		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
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

		local okBb, cf, size = pcall(char.GetBoundingBox, char)
		if not okBb or typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" then
			return nil
		end
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
			return nil
		end
		return minX, minY, maxX - minX, maxY - minY
	end

	local function mk(kind: string, props: { [string]: any })
		local d = Drawing.new(kind)
		for k, v in props do
			d[k] = v
		end
		d.Visible = false
		return d
	end

	local function setVisible(entry: any, visible: boolean)
		for _, key in ESP_DRAWABLES do
			local draw = entry[key]
			draw.Visible = visible and (key ~= "line" or Config.ESPSnaplines)
		end
		for _, corner in entry.corners do
			corner.Visible = visible
		end
	end

	local function hideAll()
		for _, entry in esp do
			setVisible(entry, false)
		end
	end

	local function destroyEntry(entry: any)
		for _, key in ESP_DRAWABLES do
			entry[key]:Remove()
		end
		for _, corner in entry.corners do
			corner:Remove()
		end
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

	local function ensure(char: Model)
		local entry = esp[char]
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
		esp[char] = entry
		return entry
	end

	local function drawTarget(name: string, char: Model, hum: Humanoid, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
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
		local maxHp = if hum.MaxHealth > 0 then hum.MaxHealth else 100
		local ratio = math.clamp(hp / maxHp, 0, 1)
		local barW = math.max(38, w + 4)
		local barH = 3
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
		entry.hpOutline.Size = Vector2.new(barW, barH)
		entry.hpOutline.Visible = true

		entry.hpFill.Position = Vector2.new(barX, barY)
		entry.hpFill.Size = Vector2.new(math.max(1, barW * ratio), barH)
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

		local camPos = Camera.CFrame.Position
		local snapFrom = if Config.ESPSnaplines
			then Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
			else nil
		local seen: { [Model]: boolean } = {}

		for char, name in collectTargets() do
			local alive, hum, root = isCombatModel(char)
			if alive and hum and root and not isAllySpawnShielded(name) then
				seen[char] = true
				drawTarget(name, char, hum, root, camPos, snapFrom)
			end
		end

		for char, entry in esp do
			if not seen[char] or not char.Parent then
				destroyEntry(entry)
				esp[char] = nil
			end
		end
	end

	return {
		updateESP = updateESP,
	}
end

return M
