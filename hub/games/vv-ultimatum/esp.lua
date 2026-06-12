local M = {}

function M.create(opts)
	local hubRequire = shared.__MicroHubRequire
	local Config = opts.config
	local Constants = opts.constants
	local Camera = opts.camera
	local LocalPlayer = opts.localPlayer
	local playerData = opts.playerData
	local targets = opts.targets
	local canDraw = opts.canDraw

	local PlayerESP = hubRequire("lib/esp/player-v2.lua")

	local mobCache: { [Model]: any } = {}
	local questCache: { [Instance]: any } = {}
	local chestCache: { [Instance]: any } = {}
	local mobEspActive = false
	local questEspActive = false
	local chestEspActive = false
	local playersEspActive = false

	local cachedFaction: string? = nil
	local cachedFactionAt = 0

	local function mk(kind, props)
		local d = Drawing.new(kind)
		for k, v in props do
			d[k] = v
		end
		d.Visible = false
		return d
	end

	local function destroyMobEntry(entry)
		entry.box:Remove()
		entry.name:Remove()
		entry.dist:Remove()
		entry.snap:Remove()
	end

	local function destroyMarkerEntry(entry)
		entry.text:Remove()
	end

	local function getLocalFaction()
		local now = os.clock()
		if now - cachedFactionAt < 1 then
			return cachedFaction
		end
		cachedFactionAt = now
		local char = playerData.getCharacterData()
		cachedFaction = char and char.Faction or nil
		return cachedFaction
	end

	local function getMobHealth(model: Model): (number, number)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			return hum.Health, hum.MaxHealth
		end
		local status = model:FindFirstChild("Status")
		if status then
			local health = status:FindFirstChild("Health")
			if health and health:IsA("ValueBase") then
				return health.Value, health.MaxValue or 100
			end
		end
		return 0, 100
	end

	local function mobColor(model: Model): Color3
		if model:GetAttribute("IsBoss") == true then
			return Constants.BOSS_COLOR
		end
		local stage = model:GetAttribute("HollowStage")
		if stage and Constants.HOLLOW_STAGE_COLORS[stage] then
			return Constants.HOLLOW_STAGE_COLORS[stage]
		end
		local race = model:GetAttribute("Race")
		if race and Constants.FACTION_COLORS[race] then
			return Constants.FACTION_COLORS[race]
		end
		return Constants.FACTION_COLORS.DefaultEnemy
	end

	local function box2d(model: Model, root: BasePart)
		if not model.Parent or not root.Parent then
			return nil
		end
		local head = model:FindFirstChild("Head")
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
		return nil
	end

	local function ensureMobEntry(model: Model)
		if mobCache[model] then
			return mobCache[model]
		end
		local entry = {
			box = mk("Square", { Thickness = 1, Filled = false }),
			name = mk("Text", { Size = 13, Center = true, Outline = true, Font = 2 }),
			dist = mk("Text", { Size = 12, Center = true, Outline = true, Font = 2 }),
			snap = mk("Line", { Thickness = 1 }),
		}
		mobCache[model] = entry
		return entry
	end

	local function hideMobEntry(entry)
		entry.box.Visible = false
		entry.name.Visible = false
		entry.dist.Visible = false
		entry.snap.Visible = false
	end

	local function drawMob(model: Model, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
		local entry = ensureMobEntry(model)
		local dist = (root.Position - camPos).Magnitude
		if dist > Constants.MAX_ESP_DIST then
			hideMobEntry(entry)
			return
		end

		local x, y, w, h = box2d(model, root)
		if not x then
			hideMobEntry(entry)
			return
		end

		local color = mobColor(model)
		local hp = getMobHealth(model)
		local hollowType = model:GetAttribute("HollowType") or model.Name
		local stage = model:GetAttribute("HollowStage")
		local suffix = if stage then (" [" .. tostring(stage) .. "]") else ""

		entry.box.Position = Vector2.new(x, y)
		entry.box.Size = Vector2.new(w, h)
		entry.box.Color = color
		entry.box.Visible = true

		entry.name.Position = Vector2.new(x + w * 0.5, y - 16)
		entry.name.Text = tostring(hollowType) .. suffix
		entry.name.Color = color
		entry.name.Visible = true

		entry.dist.Position = Vector2.new(x + w * 0.5, y + h + 2)
		entry.dist.Text = string.format("%dm | %dhp", math.floor(dist), math.floor(hp))
		entry.dist.Color = Color3.fromRGB(180, 180, 190)
		entry.dist.Visible = true

		if snapFrom and Config.ESPSnaplines then
			entry.snap.From = snapFrom
			entry.snap.To = Vector2.new(x + w * 0.5, y + h)
			entry.snap.Color = color
			entry.snap.Visible = true
		else
			entry.snap.Visible = false
		end
	end

	local function ensureMarkerEntry(cache: { [Instance]: any }, inst: Instance)
		if cache[inst] then
			return cache[inst]
		end
		local entry = {
			text = mk("Text", { Size = 14, Center = true, Outline = true, Font = 2 }),
		}
		cache[inst] = entry
		return entry
	end

	local function drawMarker(inst: Instance, label: string, color: Color3, camPos: Vector3, cache: { [Instance]: any })
		local adornee: BasePart? = nil
		if inst:IsA("BasePart") then
			adornee = inst
		elseif inst:IsA("Model") then
			adornee = inst:FindFirstChild("HumanoidRootPart")
				or inst:FindFirstChild("Head")
				or (inst.PrimaryPart and inst.PrimaryPart:IsA("BasePart") and inst.PrimaryPart or nil)
		end
		if not adornee then
			return
		end

		local entry = ensureMarkerEntry(cache, inst)
		local dist = (adornee.Position - camPos).Magnitude
		if dist > Constants.MAX_ESP_DIST then
			entry.text.Visible = false
			return
		end

		local pos, onScreen = Camera:WorldToViewportPoint(adornee.Position + Vector3.new(0, 3, 0))
		if not onScreen or pos.Z <= 0 then
			entry.text.Visible = false
			return
		end

		entry.text.Position = Vector2.new(pos.X, pos.Y)
		entry.text.Text = string.format("%s (%dm)", label, math.floor(dist))
		entry.text.Color = color
		entry.text.Visible = true
	end

	local _playerESP = PlayerESP.create({
		config = Config,
		camera = Camera,
		localPlayer = LocalPlayer,
		canDraw = canDraw,
		maxDist = Constants.MAX_ESP_DIST,
		getCharacter = function(plr)
			return plr.Character
		end,
		isAlive = function(char)
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				return true, hum, root
			end
			return false, hum, root
		end,
		getAccent = function(plr, char)
			local race = char:GetAttribute("Race")
			if race and Constants.FACTION_COLORS[race] then
				return Constants.FACTION_COLORS[race]
			end
			local myFaction = getLocalFaction()
			local theirFaction = char:GetAttribute("Faction") or plr:GetAttribute("Faction")
			if myFaction and theirFaction and myFaction == theirFaction then
				return Config.ESPAllyColor
			end
			return Config.ESPEnemyColor
		end,
		getNameSuffix = function(char)
			local lvl = char:GetAttribute("Level")
			local race = char:GetAttribute("Race")
			if lvl and race then
				return string.format(" L%d %s", lvl, race)
			end
			if race then
				return " " .. tostring(race)
			end
			return ""
		end,
		shouldSkip = function(_plr, _char)
			return Config.ESPPlayers ~= true
		end,
	})

	local function clearMobCache()
		for model, entry in mobCache do
			destroyMobEntry(entry)
			mobCache[model] = nil
		end
		mobEspActive = false
	end

	local function clearQuestCache()
		for inst, entry in questCache do
			destroyMarkerEntry(entry)
			questCache[inst] = nil
		end
		questEspActive = false
	end

	local function clearChestCache()
		for inst, entry in chestCache do
			destroyMarkerEntry(entry)
			chestCache[inst] = nil
		end
		chestEspActive = false
	end

	local function updateMobs(camPos: Vector3, snapFrom: Vector2?)
		local enabled = Config.ESPHollows or Config.ESPBosses
		if not enabled then
			if mobEspActive then
				clearMobCache()
			end
			return
		end
		mobEspActive = true

		local seen: { [Model]: boolean } = {}
		targets.forEachHostile(function(model, _hum, root)
			local isBoss = model:GetAttribute("IsBoss") == true
			if isBoss and not Config.ESPBosses then
				return
			end
			if not isBoss and not Config.ESPHollows then
				return
			end
			seen[model] = true
			drawMob(model, root, camPos, snapFrom)
		end)

		for model, entry in mobCache do
			if not seen[model] or not model.Parent then
				destroyMobEntry(entry)
				mobCache[model] = nil
			end
		end
	end

	local function updateQuestNPCs(camPos: Vector3)
		if not Config.ESPQuestNPCs then
			if questEspActive then
				clearQuestCache()
			end
			return
		end
		questEspActive = true

		local folder = workspace:FindFirstChild("DialogueInteractables")
		local seen: { [Instance]: boolean } = {}
		if folder then
			for _, npc in folder:GetChildren() do
				if npc:GetAttribute("QuestAvailable") == true or npc:GetAttribute("MissionGiver") then
					seen[npc] = true
					local label = if npc:GetAttribute("MissionGiver") then "Mission Giver" else "Quest"
					drawMarker(npc, label, Constants.QUEST_COLOR, camPos, questCache)
				end
			end
		end

		for inst, entry in questCache do
			if not seen[inst] or not inst.Parent then
				destroyMarkerEntry(entry)
				questCache[inst] = nil
			end
		end
	end

	local function updateChests(camPos: Vector3)
		if not Config.ESPChests then
			if chestEspActive then
				clearChestCache()
			end
			return
		end
		chestEspActive = true

		local debris = workspace:FindFirstChild("Debris")
		local spawns = debris and debris:FindFirstChild("LocalChestSpawns")
		local seen: { [Instance]: boolean } = {}
		if spawns then
			for _, part in spawns:GetChildren() do
				if part:IsA("BasePart") then
					seen[part] = true
					drawMarker(part, "Chest", Constants.CHEST_COLOR, camPos, chestCache)
				end
			end
		end

		for inst, entry in chestCache do
			if not seen[inst] or not inst.Parent then
				destroyMarkerEntry(entry)
				chestCache[inst] = nil
			end
		end
	end

	local function updatePlayers()
		if Config.ESPPlayers then
			Config.ESP = true
			if not playersEspActive then
				playersEspActive = true
			end
			_playerESP.update()
			return
		end

		if playersEspActive then
			_playerESP.destroy()
			playersEspActive = false
		end
	end

	local function update()
		if not canDraw then
			return
		end

		local camPos = Camera.CFrame.Position
		local vp = Camera.ViewportSize
		local snapFrom = if Config.ESPSnaplines then Vector2.new(vp.X * 0.5, vp.Y) else nil

		updatePlayers()
		updateMobs(camPos, snapFrom)
		updateQuestNPCs(camPos)
		updateChests(camPos)
	end

	local function destroy()
		_playerESP.destroy()
		playersEspActive = false
		clearMobCache()
		clearQuestCache()
		clearChestCache()
	end

	return {
		update = update,
		destroy = destroy,
	}
end

return M
