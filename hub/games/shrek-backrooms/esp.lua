local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Camera = opts.camera
	local canDraw = opts.canDraw == true
	local drawings = {}
	local playerEsp
	local aimCircle

	local function mk(kind, props)
		local d = Drawing.new(kind)
		for k, v in props do
			d[k] = v
		end
		d.Visible = false
		return d
	end

	if canDraw then
		local hubRequire = shared.__MicroHubRequire
		local PlayerESP = hubRequire("lib/esp/player-v2.lua")
		playerEsp = PlayerESP.create({
			config = Config,
			camera = Camera,
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
		local screen, onScreen = Camera:WorldToViewportPoint(position)
		return Vector2.new(screen.X, screen.Y), onScreen and screen.Z > 0
	end

	local function drawMarker(key, position, color)
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

	local function drawBox(key, part, color)
		if not part then
			return
		end
		local cf = part.CFrame
		local size = part.Size
		local corners = {
			cf * Vector3.new(-size.X, size.Y, -size.Z) / 2,
			cf * Vector3.new(size.X, size.Y, -size.Z) / 2,
			cf * Vector3.new(size.X, size.Y, size.Z) / 2,
			cf * Vector3.new(-size.X, size.Y, size.Z) / 2,
		}
		local screenCorners = {}
		for i, corner in corners do
			local pos, onScreen = worldToScreen(corner)
			if not onScreen then
				hidePrefix(key)
				return
			end
			screenCorners[i] = pos
		end
		local edges = {
			{ 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
		}
		for i, edge in edges do
			local line = ensureDrawing(key .. "_" .. i, "Line")
			line.From = screenCorners[edge[1]]
			line.To = screenCorners[edge[2]]
			line.Color = color
			line.Visible = true
		end
	end

	local function tickMonsterEsp()
		if not Config.MonsterESP and not Config.MonsterESPBoxes then
			hidePrefix("monster")
			return
		end

		local monsters = workspace:FindFirstChild("Monsters")
		if not monsters then
			return
		end

		local index = 0
		for _, model in monsters:GetDescendants() do
			if model:IsA("Model") and (model:FindFirstChild("Enemy") or model:GetAttribute("ClientEntity")) then
				local part = model:FindFirstChild("HumanoidRootPart")
					or model:FindFirstChild("RootPart")
					or model.PrimaryPart
				if part then
					index += 1
					local color = Color3.fromRGB(180, 60, 255)
					if Config.MonsterESPBoxes then
						drawBox("monster_" .. index, part, color)
					elseif Config.MonsterESP then
						drawMarker("monster_" .. index, part.Position + Vector3.new(0, 3, 0), color)
					end
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
			return
		end

		local index = 0
		for _, item in folder:GetChildren() do
			index += 1
			drawMarker("search_" .. index, item:GetPivot().Position, Color3.fromRGB(255, 210, 80))
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
			return
		end

		local index = 0
		for _, coin in coins:GetChildren() do
			local root = coin:FindFirstChild("HumanoidRootPart") or coin.PrimaryPart
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
		local radius = tonumber(Config.AimFOV) or 120
		local center = Camera.ViewportSize * 0.5
		aimCircle.Position = center
		aimCircle.Radius = radius
		aimCircle.Visible = true
	end

	local function tick()
		if playerEsp then
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
