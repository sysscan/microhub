local Players = game:GetService("Players")

local hubRequire = shared.__MicroHubRequire
local PlayerESP = hubRequire("lib/esp/player-v2.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local util = opts.util
	local loot = opts.loot
	local canDraw = opts.canDraw == true

	local lootLabels = {}
	local remoteLabels = {}
	local playerEsp

	local function getCamera()
		return workspace.CurrentCamera or opts.camera
	end

	local function getEspRange()
		return math.clamp(tonumber(Config.ESPRange) or Constants.DEFAULT_ESP_RANGE, 25, Constants.MAX_ESP_DIST)
	end

	local function findPlayerForCharacter(character)
		for _, player in Players:GetPlayers() do
			if player.Character == character or character.Name == player.Name then
				return player
			end
		end
		return nil
	end

	if canDraw then
		playerEsp = PlayerESP.create({
			config = Config,
			camera = getCamera(),
			getCamera = getCamera,
			localPlayer = LocalPlayer,
			canDraw = true,
			getMaxDist = getEspRange,
			getCharacter = function(player)
				return util.getPlayerCharacter(player)
			end,
			isAlive = function(char)
				return util.isCharacterAlive(char, findPlayerForCharacter(char))
			end,
			getHealthRatio = function(player, char, humanoid)
				return util.getHealthRatio(player, char, humanoid)
			end,
			getAccent = function()
				return Color3.fromRGB(255, 90, 90)
			end,
			getNameSuffix = function()
				return ""
			end,
		})
	end

	local function ensureLootLabel(index)
		if lootLabels[index] then
			return lootLabels[index]
		end
		if not canDraw then
			return nil
		end
		local label = Drawing.new("Text")
		label.Size = math.clamp(tonumber(Config.LootESPTextSize) or 13, 10, 20)
		label.Center = true
		label.Outline = true
		label.Visible = false
		lootLabels[index] = label
		return label
	end

	local function ensureRemoteLabel(userId)
		if remoteLabels[userId] then
			return remoteLabels[userId]
		end
		if not canDraw then
			return nil
		end
		local label = Drawing.new("Text")
		label.Size = 14
		label.Center = true
		label.Outline = true
		label.Color = Color3.fromRGB(255, 90, 90)
		label.Visible = false
		remoteLabels[userId] = label
		return label
	end

	local function formatLootLabel(entry)
		local text = entry.name
		if Config.LootESPShowCategory then
			text = string.format("[%s] %s", entry.category, text)
		end
		if Config.LootESPShowDistance then
			text = string.format("%s (%dm)", text, math.floor(entry.distance))
		end
		return text
	end

	local function drawLoot(entry, index)
		local label = ensureLootLabel(index)
		if not label then
			return
		end
		local part = entry.part
		if not part or not part.Parent then
			label.Visible = false
			return
		end
		local camera = getCamera()
		if not camera then
			label.Visible = false
			return
		end
		local screen, onScreen = camera:WorldToViewportPoint(part.Position)
		if not onScreen or screen.Z <= 0 then
			label.Visible = false
			return
		end
		label.Text = formatLootLabel(entry)
		label.Position = Vector2.new(screen.X, screen.Y)
		label.Color = Config.LootESPUseColors and entry.color or Color3.fromRGB(120, 220, 255)
		label.Visible = true
	end

	local function getLootScanOptions()
		return {
			filter = Config.LootESPFilter,
			range = loot.getLootEspRange(),
			maxItems = loot.getLootEspMaxItems(),
		}
	end

	local function drawLootEsp()
		if not canDraw or not Config.LootESP then
			for _, label in lootLabels do
				label.Visible = false
			end
			return
		end

		local ok, lootItems = pcall(function()
			return loot.scanLoot(false, getLootScanOptions())
		end)
		if not ok or typeof(lootItems) ~= "table" then
			for _, label in lootLabels do
				label.Visible = false
			end
			return
		end
		for index, entry in lootItems do
			drawLoot(entry, index)
		end
		for index = #lootItems + 1, #lootLabels do
			lootLabels[index].Visible = false
		end
	end

	local function drawRemotePlayerEsp()
		if not canDraw or not Config.ESP then
			for _, label in remoteLabels do
				label.Visible = false
			end
			return
		end

		local camera = getCamera()
		local root = util.getRoot()
		if not camera or not root then
			return
		end

		local maxDist = getEspRange()
		local origin = root.Position
		local seen = {}

		for _, player in Players:GetPlayers() do
			if player == LocalPlayer then
				continue
			end
			if not util.isPlayerSpawnedAlive(player) then
				continue
			end
			local char = util.getPlayerCharacter(player)
			if char then
				local alive = util.isCharacterAlive(char, player)
				if alive then
					seen[player.UserId] = true
					local label = remoteLabels[player.UserId]
					if label then
						label.Visible = false
					end
					continue
				end
			end
			local cframe = util.getPlayerAliveCFrame(player)
			if not cframe then
				continue
			end
			local distance = (origin - cframe.Position).Magnitude
			if distance > maxDist then
				continue
			end
			local label = ensureRemoteLabel(player.UserId)
			if not label then
				continue
			end
			local screen, onScreen = camera:WorldToViewportPoint(cframe.Position)
			if not onScreen or screen.Z <= 0 then
				label.Visible = false
				continue
			end
			seen[player.UserId] = true
			label.Text = string.format("%s (%dm)", player.DisplayName, math.floor(distance))
			label.Position = Vector2.new(screen.X, screen.Y)
			label.Visible = true
		end

		for userId, label in remoteLabels do
			if not seen[userId] then
				label.Visible = false
			end
		end
	end

	local function tick(needsLootScan)
		if playerEsp then
			playerEsp.update()
		end
		drawRemotePlayerEsp()
		drawLootEsp()
		if needsLootScan then
			loot.scanLoot(true, { filter = Config.AutoLootFilter or "All" })
		end
	end

	local function destroy()
		if playerEsp then
			playerEsp.destroy()
			playerEsp = nil
		end
		for _, label in lootLabels do
			pcall(function()
				label:Remove()
			end)
		end
		for _, label in remoteLabels do
			pcall(function()
				label:Remove()
			end)
		end
		table.clear(lootLabels)
		table.clear(remoteLabels)
	end

	return {
		tick = tick,
		destroy = destroy,
	}
end

return M
