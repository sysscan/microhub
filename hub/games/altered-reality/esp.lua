local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local Camera = opts.camera
	local canDraw = opts.canDraw
	local targets = opts.targets

	local lootCache = {}
	local lootCacheAt = 0
	local playerVisuals = {}
	local lootVisuals = {}
	local snapline

	local function ensurePlayerVisual(player)
		local key = player.UserId
		if playerVisuals[key] then
			return playerVisuals[key]
		end
		if not canDraw then
			return nil
		end
		local box = Drawing.new("Square")
		box.Thickness = 1
		box.Filled = false
		box.Color = Color3.fromRGB(255, 90, 90)
		box.Visible = false
		local label = Drawing.new("Text")
		label.Size = 14
		label.Center = true
		label.Outline = true
		label.Color = Color3.fromRGB(255, 255, 255)
		label.Visible = false
		playerVisuals[key] = { box = box, label = label }
		return playerVisuals[key]
	end

	local function ensureLootVisual(index)
		if lootVisuals[index] then
			return lootVisuals[index]
		end
		if not canDraw then
			return nil
		end
		local label = Drawing.new("Text")
		label.Size = 13
		label.Center = true
		label.Outline = true
		label.Color = Color3.fromRGB(120, 220, 255)
		label.Visible = false
		lootVisuals[index] = label
		return label
	end

	local function ensureSnapline()
		if snapline or not canDraw then
			return snapline
		end
		snapline = Drawing.new("Line")
		snapline.Thickness = 1
		snapline.Color = Color3.fromRGB(255, 90, 90)
		snapline.Visible = false
		return snapline
	end

	local function hidePlayerVisual(visual)
		visual.box.Visible = false
		visual.label.Visible = false
	end

	local function scanLoot(force)
		local now = tick()
		if not force and now - lootCacheAt < Constants.LOOT_SCAN_INTERVAL then
			return lootCache
		end
		lootCacheAt = now
		table.clear(lootCache)

		local chunks = workspace:FindFirstChild("Chunks")
		if not chunks then
			return lootCache
		end

		for _, chunk in chunks:GetChildren() do
			for _, descendant in chunk:GetDescendants() do
				if #lootCache >= Constants.MAX_ESP_LOOT then
					return lootCache
				end
				if descendant:IsA("Model") or descendant:IsA("BasePart") then
					local id = descendant:GetAttribute("Id")
					local alias = descendant:GetAttribute("Alias")
					if id and alias then
						local part = if descendant:IsA("BasePart") then descendant else descendant:FindFirstChildWhichIsA("BasePart", true)
						if part then
							table.insert(lootCache, {
								id = id,
								name = tostring(alias),
								part = part,
							})
						end
					end
				end
			end
			if #lootCache >= Constants.MAX_ESP_LOOT then
				break
			end
		end

		return lootCache
	end

	local function drawPlayer(player)
		local character = player.Character
		local visual = ensurePlayerVisual(player)
		if not visual then
			return
		end
		if not character or not targets.isEnemyAlive(character) then
			hidePlayerVisual(visual)
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
		if not root then
			hidePlayerVisual(visual)
			return
		end
		local screen, onScreen = Camera:WorldToViewportPoint(root.Position)
		if not onScreen or screen.Z <= 0 then
			hidePlayerVisual(visual)
			return
		end
		local size = math.clamp(2200 / screen.Z, 18, 120)
		visual.box.Size = Vector2.new(size, size * 1.8)
		visual.box.Position = Vector2.new(screen.X - size * 0.5, screen.Y - size * 0.9)
		visual.box.Visible = Config.PlayerESPBoxes == true
		visual.label.Text = player.Name
		if Config.ShowPlayerHealth then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				visual.label.Text = string.format("%s [%d]", player.Name, math.floor(humanoid.Health))
			end
		end
		visual.label.Position = Vector2.new(screen.X, screen.Y - size)
		visual.label.Visible = Config.PlayerESP == true
		if Config.ESPSnaplines then
			local line = ensureSnapline()
			if line then
				line.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
				line.To = Vector2.new(screen.X, screen.Y)
				line.Visible = true
			end
		elseif snapline then
			snapline.Visible = false
		end
	end

	local function drawLoot(entry, index)
		local label = ensureLootVisual(index)
		if not label then
			return
		end
		local part = entry.part
		if not part or not part.Parent then
			label.Visible = false
			return
		end
		local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or screen.Z <= 0 then
			label.Visible = false
			return
		end
		label.Text = entry.name
		label.Position = Vector2.new(screen.X, screen.Y)
		label.Visible = true
	end

	local function tick(needsLootScan)
		if not canDraw and not needsLootScan then
			return
		end

		local activePlayers = {}
		if canDraw and (Config.PlayerESP or Config.PlayerESPBoxes or Config.ESPSnaplines) then
			local count = 0
			for _, player in targets.collectPlayers() do
				count += 1
				if count > Constants.MAX_ESP_PLAYERS then
					break
				end
				activePlayers[player.UserId] = true
				drawPlayer(player)
			end
			for userId, visual in playerVisuals do
				if not activePlayers[userId] then
					hidePlayerVisual(visual)
				end
			end
			if not Config.ESPSnaplines and snapline then
				snapline.Visible = false
			end
		end

		if Config.LootESP and canDraw then
			local lootItems = scanLoot(false)
			for index, entry in lootItems do
				drawLoot(entry, index)
			end
			for index = #lootItems + 1, #lootVisuals do
				lootVisuals[index].Visible = false
			end
		elseif canDraw then
			for _, label in lootVisuals do
				label.Visible = false
			end
		end

		if needsLootScan then
			scanLoot(false)
		end
	end

	local function destroy()
		for _, visual in playerVisuals do
			pcall(function()
				visual.box:Remove()
				visual.label:Remove()
			end)
		end
		table.clear(playerVisuals)
		for _, label in lootVisuals do
			pcall(function()
				label:Remove()
			end)
		end
		table.clear(lootVisuals)
		if snapline then
			pcall(function()
				snapline:Remove()
			end)
			snapline = nil
		end
	end

	return {
		tick = tick,
		scanLoot = scanLoot,
		destroy = destroy,
	}
end

return M
