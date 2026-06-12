local hubRequire = shared.__MicroHubRequire
local MonstersLib = hubRequire("games/shrek-backrooms/monsters.lua")
local PlayerESP = hubRequire("lib/esp/player-v2.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local canDraw = opts.canDraw == true
	local drawings = {}
	local playerEsp
	local aimCircle

	local function getCamera()
		return workspace.CurrentCamera or opts.camera
	end

	local function mk(kind, props)
		local d = Drawing.new(kind)
		for k, v in props do
			d[k] = v
		end
		d.Visible = false
		return d
	end

	if canDraw then
		playerEsp = PlayerESP.create({
			config = Config,
			camera = getCamera(),
			localPlayer = LocalPlayer,
			canDraw = true,
			getCharacter = function(player)
				return player and player.Character
			end,
			isAlive = function(char)
				if not char then
					return false
				end
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")
				return humanoid ~= nil and root ~= nil and humanoid.Health > 0, humanoid, root
			end,
			getAccent = function()
				return Color3.fromRGB(120, 180, 255)
			end,
			getNameSuffix = function()
				return ""
			end,
		})
		aimCircle = mk("Circle", {
			Thickness = 1,
			NumSides = 48,
			Filled = false,
			Transparency = 0.45,
			Color = Color3.fromRGB(255, 255, 255),
		})
	end

	local function ensureDrawing(key, kind)
		kind = kind or "Line"
		if not canDraw then
			return nil
		end
		if drawings[key] then
			return drawings[key]
		end
		local drawing = Drawing.new(kind)
		drawing.Visible = false
		drawing.Thickness = 1
		drawings[key] = drawing
		return drawing
	end

	local function hidePrefix(prefix)
		for key, drawing in drawings do
			if string.sub(key, 1, #prefix) == prefix then
				drawing.Visible = false
			end
		end
	end

	local function worldToScreen(position)
		local camera = getCamera()
		if not camera then
			return nil, false
		end
		local screen, onScreen = camera:WorldToViewportPoint(position)
		return Vector2.new(screen.X, screen.Y), onScreen and screen.Z > 0
	end

	local function drawMarker(key, position, color)
		hidePrefix(key .. "_")
		local line = ensureDrawing(key, "Line")
		if not line then
			return
		end
		local screenPos, onScreen = worldToScreen(position)
		if not onScreen then
			line.Visible = false
			return
		end
		line.From = screenPos
		line.To = screenPos + Vector2.new(0, 18)
		line.Color = color
		line.Visible = true
	end

	local function getModelScreenBox(model)
		local camera = getCamera()
		if not camera then
			return nil
		end

		local ok, cf, size = pcall(model.GetBoundingBox, model)
		if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
			local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
			local anyVisible = false

			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						local world = (cf * CFrame.new(hx * sx, hy * sy, hz * sz)).Position
						local screen, onScreen = camera:WorldToViewportPoint(world)
						if onScreen and screen.Z > 0 then
							anyVisible = true
							minX = math.min(minX, screen.X)
							minY = math.min(minY, screen.Y)
							maxX = math.max(maxX, screen.X)
							maxY = math.max(maxY, screen.Y)
						end
					end
				end
			end

			if anyVisible then
				return minX, minY, maxX - minX, maxY - minY
			end
		end

		local root = MonstersLib.getRoot(model)
		if not root then
			return nil
		end

		local screenPos, onScreen = worldToScreen(root.Position)
		if not onScreen then
			return nil
		end

		return screenPos.X - 28, screenPos.Y - 56, 56, 112
	end

	local function drawScreenBox(key, x, y, w, h, color)
		local topLeft = Vector2.new(x, y)
		local topRight = Vector2.new(x + w, y)
		local bottomRight = Vector2.new(x + w, y + h)
		local bottomLeft = Vector2.new(x, y + h)
		local segments = {
			{ topLeft, topRight },
			{ topRight, bottomRight },
			{ bottomRight, bottomLeft },
			{ bottomLeft, topLeft },
		}

		local marker = drawings[key]
		if marker then
			marker.Visible = false
		end

		for i, segment in segments do
			local line = ensureDrawing(key .. "_" .. i, "Line")
			if not line then
				return
			end
			line.From = segment[1]
			line.To = segment[2]
			line.Color = color
			line.Visible = true
		end
	end

	local function tickMonsterEsp()
		if not Config.MonsterESP and not Config.MonsterESPBoxes then
			hidePrefix("monster")
			return
		end

		if not canDraw then
			return
		end

		local index = 0
		for _, model in MonstersLib.collect() do
			local boundsX, boundsY, boundsW, boundsH = getModelScreenBox(model)
			if boundsX then
				index += 1
				local color = Color3.fromRGB(180, 60, 255)
				local key = "monster_" .. index
				if Config.MonsterESPBoxes then
					drawScreenBox(key, boundsX, boundsY, boundsW, boundsH, color)
				else
					hidePrefix(key .. "_")
					local root = MonstersLib.getRoot(model)
					local markerPos = root and (root.Position + Vector3.new(0, 3, 0))
					if not markerPos then
						local ok, cf, size = pcall(model.GetBoundingBox, model)
						markerPos = ok and (cf.Position + Vector3.new(0, size.Y * 0.5, 0)) or model:GetPivot().Position
					end
					drawMarker(key, markerPos, color)
				end
			end
		end

		for i = index + 1, index + 30 do
			hidePrefix("monster_" .. i)
		end
	end

	local function tickSearchEsp()
		if not Config.SearchESP then
			hidePrefix("search")
			return
		end

		local folder = workspace:FindFirstChild("SearchItems")
		if not folder then
			hidePrefix("search")
			return
		end

		local index = 0
		for _, item in folder:GetDescendants() do
			if item:IsA("Model") or item:IsA("BasePart") then
				index += 1
				local position = item:IsA("Model") and item:GetPivot().Position or item.Position
				drawMarker("search_" .. index, position, Color3.fromRGB(255, 210, 80))
			end
		end

		for i = index + 1, index + 30 do
			hidePrefix("search_" .. i)
		end
	end

	local function tickCoinEsp()
		if not Config.CoinESP then
			hidePrefix("coin")
			return
		end

		local coins = workspace:FindFirstChild("Coins")
		coins = coins and coins:FindFirstChild("Coins")
		if not coins then
			hidePrefix("coin")
			return
		end

		local index = 0
		for _, coin in coins:GetChildren() do
			local root = coin:FindFirstChild("HumanoidRootPart", true) or coin.PrimaryPart
			if root then
				index += 1
				drawMarker("coin_" .. index, root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(80, 220, 120))
			end
		end

		for i = index + 1, index + 30 do
			hidePrefix("coin_" .. i)
		end
	end

	local function tickMysteryBoxEsp()
		if not Config.MysteryBoxESP then
			hidePrefix("mbox")
			return
		end

		local lobby = workspace:FindFirstChild("Lobby")
		local boxes = lobby and lobby:FindFirstChild("MysteryBoxes")
		if not boxes then
			hidePrefix("mbox")
			return
		end

		local index = 0
		for _, box in boxes:GetChildren() do
			local part = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart")
			if part then
				index += 1
				drawMarker("mbox_" .. index, part.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 120, 200))
			end
		end

		for i = index + 1, index + 20 do
			hidePrefix("mbox_" .. i)
		end
	end

	local function tickAimFov()
		if not aimCircle then
			return
		end
		if not (Config.ShowAimFOV and (Config.AimAssist or Config.AutoAttack)) then
			aimCircle.Visible = false
			return
		end
		local camera = getCamera()
		if not camera then
			aimCircle.Visible = false
			return
		end
		local radius = tonumber(Config.AimFOV) or 120
		local center = camera.ViewportSize * 0.5
		aimCircle.Position = center
		aimCircle.Radius = radius
		aimCircle.Visible = true
	end

	local function tick()
		if playerEsp and Config.ESP then
			playerEsp.update()
		end
		tickMonsterEsp()
		tickSearchEsp()
		tickCoinEsp()
		tickMysteryBoxEsp()
		tickAimFov()
	end

	local function destroy()
		for _, drawing in drawings do
			pcall(function()
				drawing:Remove()
			end)
		end
		table.clear(drawings)
		if aimCircle then
			pcall(function()
				aimCircle:Remove()
			end)
			aimCircle = nil
		end
		if playerEsp then
			playerEsp.destroy()
			playerEsp = nil
		end
	end

	return {
		tick = tick,
		destroy = destroy,
	}
end

return M
