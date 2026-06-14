local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local targets = opts.targets
	local canDraw = opts.canDraw == true

	if not Config or not Constants or not targets then
		error("[POLYZ] esp.create missing config, constants, or targets", 0)
	end

	local drawings = {}
	local aimCircle: DrawingCircle?
	local enemyColor = Color3.fromRGB(255, 80, 80)
	local playerColor = Color3.fromRGB(80, 160, 255)

	local function getCamera()
		return workspace.CurrentCamera or opts.camera
	end

	local function ensureDrawing(key: string, kind: string?)
		kind = kind or "Line"
		if not canDraw then
			return nil
		end
		local existing = drawings[key]
		if existing then
			return existing
		end
		local drawing = Drawing.new(kind)
		drawing.Visible = false
		drawing.Thickness = 1
		drawings[key] = drawing
		return drawing
	end

	local function hideFromIndex(prefix: string, startIndex: number, maxCount: number)
		for i = startIndex, maxCount do
			local base = prefix .. i
			local marker = drawings[base]
			if marker then
				marker.Visible = false
			end
			for segment = 1, 4 do
				local line = drawings[base .. "_" .. segment]
				if line then
					line.Visible = false
				end
			end
			local snap = drawings[base .. "_snap"]
			if snap then
				snap.Visible = false
			end
			local mark = drawings[base .. "_mark"]
			if mark then
				mark.Visible = false
			end
			local hp = drawings[base .. "_hp"]
			if hp then
				hp.Visible = false
			end
		end
	end

	local function worldToScreen(position: Vector3, camera: Camera)
		local screen, onScreen = camera:WorldToViewportPoint(position)
		return screen.X, screen.Y, onScreen and screen.Z > 0
	end

	local function getPartScreenBox(part: BasePart, camera: Camera)
		local x, y, onScreen = worldToScreen(part.Position, camera)
		if not onScreen then
			return nil
		end
		return x - 28, y - 56, 56, 112
	end

	local function getPartScreenBoxIf(part: BasePart?, camera: Camera)
		if not part then
			return nil
		end
		return getPartScreenBox(part, camera)
	end

	local function isValidScreenBox(x: any, y: any, w: any, h: any): boolean
		return typeof(x) == "number" and typeof(y) == "number" and typeof(w) == "number" and typeof(h) == "number"
	end

	local function getModelScreenBox(model: Model, camera: Camera, useFullBox: boolean)
		if not useFullBox then
			return getPartScreenBoxIf(targets.getAimPart(model), camera)
		end

		local ok, cf, size = pcall(model.GetBoundingBox, model)
		if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			local hx, hy = size.X * 0.5, size.Y * 0.5
			local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
			local anyVisible = false

			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					local world = (cf * CFrame.new(hx * sx, hy * sy, 0)).Position
					local sxPos, syPos, onScreen = worldToScreen(world, camera)
					if onScreen then
						anyVisible = true
						minX = math.min(minX, sxPos)
						minY = math.min(minY, syPos)
						maxX = math.max(maxX, sxPos)
						maxY = math.max(maxY, syPos)
					end
				end
			end

			if anyVisible then
				return minX, minY, maxX - minX, maxY - minY
			end
		end

		return getPartScreenBoxIf(targets.getAimPart(model), camera)
	end

	local function drawScreenBox(key: string, x: number, y: number, w: number, h: number, color: Color3)
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

	local function drawMarker(key: string, position: Vector3, color: Color3, camera: Camera)
		local line = ensureDrawing(key, "Line")
		if not line then
			return
		end
		local x, y, onScreen = worldToScreen(position, camera)
		if not onScreen then
			line.Visible = false
			return
		end
		local from = Vector2.new(x, y)
		line.From = from
		line.To = from + Vector2.new(0, 18)
		line.Color = color
		line.Visible = true
	end

	local function drawSnapline(key: string, position: Vector3, color: Color3, camera: Camera)
		local line = ensureDrawing(key, "Line")
		if not line then
			return
		end
		local x, y, onScreen = worldToScreen(position, camera)
		if not onScreen then
			line.Visible = false
			return
		end
		line.From = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
		line.To = Vector2.new(x, y)
		line.Color = color
		line.Visible = true
	end

	local function tickEnemyEsp(camera: Camera)
		if not (Config.EnemyESP or Config.EnemyESPBoxes or Config.ESPSnaplines or Config.ShowEnemyHealth) then
			hideFromIndex("enemy_", 1, Constants.MAX_ESP_ENEMIES)
			return
		end

		if not canDraw then
			return
		end

		local enemies, count = targets.collectEnemies()
		local index = 0
		local useFullBox = Config.EnemyESPBoxes == true

		for i = 1, math.min(count, Constants.MAX_ESP_ENEMIES) do
			local enemy = enemies[i]
			local part = targets.getAimPart(enemy)
			if not part then
				continue
			end

			local boundsX, boundsY, boundsW, boundsH = getModelScreenBox(enemy, camera, useFullBox)
			if not isValidScreenBox(boundsX, boundsY, boundsW, boundsH) then
				boundsX, boundsY, boundsW, boundsH = getPartScreenBox(part, camera)
			end
			if not isValidScreenBox(boundsX, boundsY, boundsW, boundsH) then
				continue
			end

			index += 1
			local key = "enemy_" .. index

			if Config.EnemyESPBoxes then
				drawScreenBox(key, boundsX, boundsY, boundsW, boundsH, enemyColor)
			end

			if Config.EnemyESP and not Config.EnemyESPBoxes then
				drawMarker(key .. "_mark", part.Position + Vector3.new(0, 2, 0), enemyColor, camera)
			end

			if Config.ESPSnaplines then
				drawSnapline(key .. "_snap", part.Position, enemyColor, camera)
			end

			if Config.ShowEnemyHealth then
				local text = ensureDrawing(key .. "_hp", "Text")
				if text then
					local health = targets.getEnemyHealth(enemy)
					text.Text = if health then string.format("%.0f HP", health) else enemy.Name
					text.Size = 14
					text.Center = true
					text.Outline = true
					text.Color = enemyColor
					text.Position = Vector2.new(boundsX + boundsW * 0.5, boundsY - 16)
					text.Visible = true
				end
			end
		end

		hideFromIndex("enemy_", index + 1, Constants.MAX_ESP_ENEMIES)
	end

	local function tickPlayerEsp(camera: Camera)
		if not Config.PlayerESP then
			hideFromIndex("player_", 1, Constants.MAX_ESP_PLAYERS)
			return
		end

		local folder = workspace:FindFirstChild("Players")
		if not folder then
			hideFromIndex("player_", 1, Constants.MAX_ESP_PLAYERS)
			return
		end

		local index = 0
		for _, model in folder:GetChildren() do
			if index >= Constants.MAX_ESP_PLAYERS then
				break
			end
			if model:IsA("Model") then
				local boundsX, boundsY, boundsW, boundsH = getModelScreenBox(model, camera, true)
				if isValidScreenBox(boundsX, boundsY, boundsW, boundsH) then
					index += 1
					drawScreenBox("player_" .. index, boundsX, boundsY, boundsW, boundsH, playerColor)
				end
			end
		end

		hideFromIndex("player_", index + 1, Constants.MAX_ESP_PLAYERS)
	end

	local function tickAimFov(camera: Camera)
		if not canDraw then
			return
		end

		if not aimCircle then
			aimCircle = Drawing.new("Circle")
			aimCircle.Thickness = 1
			aimCircle.NumSides = 48
			aimCircle.Filled = false
			aimCircle.Transparency = 0.45
			aimCircle.Color = Color3.fromRGB(255, 255, 255)
		end

		if not (Config.ShowAimFOV and (Config.AimAssist or Config.AutoShoot)) then
			aimCircle.Visible = false
			return
		end

		aimCircle.Position = camera.ViewportSize * 0.5
		aimCircle.Radius = tonumber(Config.AimFOV) or 180
		aimCircle.Visible = true
	end

	local function tick()
		local camera = getCamera()
		if not camera then
			return
		end

		tickEnemyEsp(camera)
		tickPlayerEsp(camera)
		tickAimFov(camera)
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
	end

	return {
		tick = tick,
		destroy = destroy,
	}
end

return M
