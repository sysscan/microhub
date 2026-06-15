--[[
	Shared player ESP (Drawing API) — box, HP bar, name, weapon, distance, snaplines.
	Used by Prison Life and other MicroHub games via shared.__MicroHubRequire.
]]

local Players = game:GetService("Players")

local DEFAULT_DIM = Color3.fromRGB(148, 156, 168)
local DEFAULT_MAX_DIST = 2000

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function hpColor(ratio: number): Color3
	if ratio > 0.5 then
		return lerpColor(Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 230, 120), (ratio - 0.5) * 2)
	end
	return lerpColor(Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 220, 60), ratio * 2)
end

local function formatDist(studs: number): string
	if studs >= 1000 then
		return string.format("%.1fk", studs / 1000)
	end
	return string.format("%d", math.floor(studs))
end

local function mkDraw(kind: string, props: { [string]: any })
	local d = Drawing.new(kind)
	for k, v in props do
		d[k] = v
	end
	d.Visible = false
	return d
end

local M = {}

function M.create(opts: {
	config: { [string]: any },
	camera: Camera?,
	localPlayer: Player,
	canDraw: boolean?,
	maxDist: number?,
	dimColor: Color3?,
	getCamera: (() -> Camera?)?,
	getCharacter: (Player) -> Model?,
	isAlive: (Model) -> (boolean, Humanoid?, BasePart?),
	getAccent: (Player, Model) -> Color3,
	getNameSuffix: (Model) -> string,
	getWeaponName: ((Model) -> string?)?,
	getHealthRatio: ((Player, Model, Humanoid) -> number)?,
	shouldSkip: ((Player, Model) -> boolean)?,
	getMaxDist: (() -> number)?,
})
	local config = opts.config
	local camera = opts.camera
	local getCamera = opts.getCamera
	local localPlayer = opts.localPlayer
	local canDraw = opts.canDraw ~= false and typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
	local maxDist = opts.maxDist or DEFAULT_MAX_DIST
	local dimColor = opts.dimColor or DEFAULT_DIM
	local getCharacter = opts.getCharacter
	local isAlive = opts.isAlive
	local getAccent = opts.getAccent
	local getNameSuffix = opts.getNameSuffix
	local getWeaponName = opts.getWeaponName
		or function(char: Model): string?
			local tool = char:FindFirstChildWhichIsA("Tool")
			return tool and tool.Name or nil
		end
	local shouldSkip = opts.shouldSkip
	local getMaxDist = opts.getMaxDist

	local function resolveMaxDist(): number
		if getMaxDist then
			return getMaxDist()
		end
		return maxDist
	end

	local function resolveCamera(): Camera?
		if getCamera then
			return getCamera()
		end
		return camera
	end

	local cache: { [Model]: any } = {}
	local needsHide = false

	local function box2d(char: Model, root: BasePart, cam: Camera): (number?, number?, number?, number?)
		if not char.Parent or not root.Parent then
			return nil
		end
		local head = char:FindFirstChild("SmallHead", true) or char:FindFirstChild("Head", true)
		if head and head:IsA("BasePart") then
			local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.4, 0)
			local botPos = root.Position - Vector3.new(0, 2.8, 0)
			local top, topOn = cam:WorldToViewportPoint(topPos)
			local bot, botOn = cam:WorldToViewportPoint(botPos)
			if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
				local h = math.max(14, bot.Y - top.Y)
				local w = h * 0.55
				return top.X - w * 0.5, top.Y, w, h
			end
		end
		local pos, onScreen = cam:WorldToViewportPoint(root.Position)
		if onScreen and pos.Z > 0 then
			return pos.X - 16, pos.Y - 30, 32, 60
		end
		return nil
	end

	local function hideEntry(entry: any)
		for _, obj in entry do
			pcall(function()
				obj.Visible = false
			end)
		end
	end

	local function destroyEntry(entry: any)
		for _, obj in entry do
			pcall(function()
				obj:Remove()
			end)
		end
	end

	local function ensureEntry(char: Model)
		if cache[char] then
			return cache[char]
		end
		local entry = {
			boxOutline = mkDraw("Square", { Filled = false, Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0.6 }),
			box = mkDraw("Square", { Filled = false, Thickness = 1.4 }),
			hpBarBg = mkDraw("Square", { Filled = true, Thickness = 0, Color = Color3.fromRGB(20, 20, 20), Transparency = 0.3 }),
			hpBar = mkDraw("Square", { Filled = true, Thickness = 0 }),
			name = mkDraw("Text", { Size = 14, Center = true, Outline = true, Font = 2 }),
			weapon = mkDraw("Text", { Size = 11, Center = true, Outline = true, Font = 2, Color = Color3.fromRGB(200, 200, 200) }),
			dist = mkDraw("Text", { Size = 11, Center = true, Outline = true, Font = 2 }),
			snapline = mkDraw("Line", { Thickness = 1, Transparency = 0.4 }),
		}
		cache[char] = entry
		return entry
	end

	local getHealthRatio = opts.getHealthRatio

	local function drawTarget(player: Player, char: Model, hum: Humanoid, root: BasePart, cam: Camera, camPos: Vector3, snapFrom: Vector2?)
		if shouldSkip and shouldSkip(player, char) then
			if cache[char] then
				hideEntry(cache[char])
			end
			return
		end

		local dist = (root.Position - camPos).Magnitude
		if dist > resolveMaxDist() then
			if cache[char] then
				hideEntry(cache[char])
			end
			return
		end

		local x, y, w, h = box2d(char, root, cam)
		if not x then
			if cache[char] then
				hideEntry(cache[char])
			end
			return
		end

		local entry = ensureEntry(char)
		local accent = getAccent(player, char)
		local cx = x + w * 0.5
		local bottom = y + h
		local ratio = if getHealthRatio
			then math.clamp(getHealthRatio(player, char, hum), 0, 1)
			else math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		local fadeAlpha = 1 - math.clamp((dist - 800) / 1200, 0, 0.6)

		entry.boxOutline.Position = Vector2.new(x - 1, y - 1)
		entry.boxOutline.Size = Vector2.new(w + 2, h + 2)
		entry.boxOutline.Transparency = 0.55 * fadeAlpha
		entry.boxOutline.Visible = true

		entry.box.Position = Vector2.new(x, y)
		entry.box.Size = Vector2.new(w, h)
		entry.box.Color = accent
		entry.box.Transparency = (1 - fadeAlpha) * 0.3
		entry.box.Visible = true

		local barH = math.clamp(h, 8, 200)
		local barW = 3
		local barX = x - 6
		local barY = y

		entry.hpBarBg.Position = Vector2.new(barX - 1, barY - 1)
		entry.hpBarBg.Size = Vector2.new(barW + 2, barH + 2)
		entry.hpBarBg.Visible = true

		local fillH = math.max(1, barH * ratio)
		entry.hpBar.Position = Vector2.new(barX, barY + (barH - fillH))
		entry.hpBar.Size = Vector2.new(barW, fillH)
		entry.hpBar.Color = hpColor(ratio)
		entry.hpBar.Visible = true

		local suffix = getNameSuffix(char)
		local nameStr = player.DisplayName
		if suffix ~= "" then
			nameStr = nameStr .. " " .. suffix
		end
		entry.name.Position = Vector2.new(cx, y - 16)
		entry.name.Text = nameStr
		entry.name.Color = accent
		entry.name.Visible = true

		local wepName = getWeaponName(char)
		entry.weapon.Position = Vector2.new(cx, bottom + 2)
		entry.weapon.Text = wepName or ""
		entry.weapon.Visible = wepName ~= nil

		local distStr = formatDist(dist) .. "m"
		if ratio < 1 then
			distStr = distStr .. " | " .. math.floor(hum.Health) .. "hp"
		end
		entry.dist.Position = Vector2.new(cx, bottom + (if wepName then 14 else 2))
		entry.dist.Text = distStr
		entry.dist.Color = dimColor
		entry.dist.Visible = true

		if snapFrom then
			entry.snapline.From = snapFrom
			entry.snapline.To = Vector2.new(cx, bottom + 1)
			entry.snapline.Color = accent
			entry.snapline.Transparency = 0.5 * fadeAlpha
		end
		entry.snapline.Visible = config.ESPSnaplines == true and snapFrom ~= nil
	end

	local function update()
		if not canDraw then
			return
		end
		if not config.ESP then
			if needsHide then
				for char, entry in cache do
					destroyEntry(entry)
					cache[char] = nil
				end
				needsHide = false
			end
			return
		end
		needsHide = true

		local cam = resolveCamera()
		if not cam then
			return
		end

		local camPos = cam.CFrame.Position
		local vpSize = cam.ViewportSize
		local snapFrom = if config.ESPSnaplines then Vector2.new(vpSize.X * 0.5, vpSize.Y) else nil
		local seen: { [Model]: boolean } = {}

		for _, player in Players:GetPlayers() do
			if player == localPlayer then
				continue
			end
			local char = getCharacter(player)
			if not char then
				continue
			end
			local alive, hum, root = isAlive(char)
			if alive and hum and root then
				seen[char] = true
				drawTarget(player, char, hum, root, cam, camPos, snapFrom)
			end
		end

		for char, entry in cache do
			if not seen[char] or not char.Parent then
				destroyEntry(entry)
				cache[char] = nil
			end
		end
	end

	local function destroy()
		for char, entry in cache do
			destroyEntry(entry)
			cache[char] = nil
		end
		needsHide = false
	end

	return {
		update = update,
		destroy = destroy,
	}
end

return M
