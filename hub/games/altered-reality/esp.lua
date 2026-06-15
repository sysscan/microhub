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
	local playerEsp

	local function getCamera()
		return workspace.CurrentCamera or opts.camera
	end

	local function findPlayerForCharacter(character)
		for _, player in Players:GetPlayers() do
			if player.Character == character then
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
			getMaxDist = function()
				return math.clamp(tonumber(Config.ESPRange) or Constants.DEFAULT_ESP_RANGE, 25, Constants.MAX_ESP_DIST)
			end,
			getCharacter = function(player)
				return player and player.Character
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

	local function drawLootEsp()
		if not canDraw or not Config.LootESP then
			for _, label in lootLabels do
				label.Visible = false
			end
			return
		end

		local ok, lootItems = pcall(loot.scanLoot, loot, false)
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

	local function tick(needsLootScan)
		if playerEsp then
			playerEsp.update()
		end
		drawLootEsp()
		if needsLootScan then
			loot.scanLoot(false, { filter = "All" })
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
		table.clear(lootLabels)
	end

	return {
		tick = tick,
		destroy = destroy,
	}
end

return M
