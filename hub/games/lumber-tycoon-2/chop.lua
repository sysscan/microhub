local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local Util = opts.util
	local Remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local treeRegion = workspace:WaitForChild("TreeRegion", 30)
	local lastChopAt = 0
	local sectionCache = {}
	local sectionCacheAt = 0
	local sectionCachePlayerWood = false
	local SECTION_CACHE_TTL = 0.55

	local function getSearchFolders(): { Instance }
		local folders = { treeRegion }
		local playerModels = workspace:FindFirstChild("PlayerModels")
		if Config.ChopPlayerWood and playerModels then
			table.insert(folders, playerModels)
		end
		return folders
	end

	local function rebuildSectionCache()
		local now = os.clock()
		local includePlayerWood = Config.ChopPlayerWood == true
		if (now - sectionCacheAt) < SECTION_CACHE_TTL and sectionCachePlayerWood == includePlayerWood then
			return
		end

		sectionCacheAt = now
		sectionCachePlayerWood = includePlayerWood
		table.clear(sectionCache)

		for _, folder in getSearchFolders() do
			for _, model in folder:GetChildren() do
				if not model:IsA("Model") then
					continue
				end
				local cutEvent = model:FindFirstChild("CutEvent")
				if not cutEvent then
					continue
				end
				local className = Util.getTreeClass(model)
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						local idValue = descendant:FindFirstChild("ID")
						if idValue and idValue:IsA("IntValue") then
							table.insert(sectionCache, {
								section = descendant,
								model = model,
								className = className,
							})
						end
					end
				end
			end
		end
	end

	local function getNearestSection(origin: Vector3, maxRange: number, options: { filter: string?, rareOnly: boolean? }?)
		rebuildSectionCache()

		local bestSection = nil
		local bestModel = nil
		local bestDistSq = maxRange * maxRange
		local filter = (options and options.filter) or Config.ChopWoodType or "Any"
		local rareOnly = if options and options.rareOnly ~= nil then options.rareOnly else Config.ChopRareOnly == true

		for _, entry in sectionCache do
			if rareOnly and not Util.isRareWood(entry.className, Constants.RARE_WOODS) then
				continue
			end
			if not Util.matchesWoodFilter(entry.className, filter) then
				continue
			end
			local distSq = Util.distanceSq(origin, entry.section.Position)
			if distSq < bestDistSq then
				bestDistSq = distSq
				bestSection = entry.section
				bestModel = entry.model
			end
		end

		if not bestSection then
			return nil, nil, maxRange
		end
		return bestSection, bestModel, math.sqrt(bestDistSq)
	end

	local function getChopHeight(section: BasePart, hitPoint: Vector3): number
		local height = section.CFrame:PointToObjectSpace(hitPoint).Y + section.Size.Y / 2
		return math.clamp(height, 0, section.Size.Y)
	end

	local function getChopTarget(section: BasePart, height: number): Vector3
		return (section.CFrame * CFrame.new(0, height - section.Size.Y / 2, 0)).Position
	end

	local function buildFaceVector(section: BasePart, head: BasePart, surfaceNormal: Vector3, lookPoint: Vector3): Vector3?
		local faceVector = Util.fixVector(section.CFrame:VectorToObjectSpace(surfaceNormal))
		if faceVector.Y ~= 0 then
			return nil
		end

		local lookAt = CFrame.new(head.Position, lookPoint)
		local relative = lookAt:ToObjectSpace(section.CFrame * CFrame.Angles(math.pi / 2, 0, 0))
		local sign = if relative.LookVector.Y >= 0 then 1 else -1

		if faceVector.X == 1 then
			return Vector3.new(0, 0, -1) * sign
		elseif faceVector.X == -1 then
			return Vector3.new(0, 0, 1) * sign
		elseif faceVector.Z == 1 then
			return Vector3.new(1, 0, 0) * sign
		elseif faceVector.Z == -1 then
			return Vector3.new(-1, 0, 0) * sign
		end
		return nil
	end

	local function chopSection(section: BasePart, treeModel: Model, tool: Tool): boolean
		local head = Util.getHead(LocalPlayer)
		local character = Util.getCharacter(LocalPlayer)
		if not (head and character) then
			return false
		end

		local cutEvent = treeModel:FindFirstChild("CutEvent")
		local idValue = section:FindFirstChild("ID")
		if not (cutEvent and idValue and idValue:IsA("IntValue")) then
			return false
		end

		local stats = Util.getAxeStats(tool)
		local range = stats.Range
		local lookPoint = section.Position
		local height = getChopHeight(section, lookPoint)
		local rayTarget = getChopTarget(section, height)

		local rayResult, surfaceNormal = Util.raycastFromHead(head, rayTarget, range, character)
		if rayResult ~= section and (not rayResult or rayResult.Parent ~= treeModel) then
			local closeEnough = Util.distance(head.Position, section.Position) <= range * 0.9
			if not closeEnough then
				return false
			end
			surfaceNormal = (head.Position - section.Position).Unit
		end
		if not surfaceNormal then
			surfaceNormal = (head.Position - rayTarget).Unit
		end

		local faceVector = buildFaceVector(section, head, surfaceNormal, lookPoint)
		if not faceVector then
			return false
		end

		local damage = stats.Damage * math.max(tonumber(Config.ChopDamageMult) or 1, 0.1)
		local ping = Remotes.getPing()
		local payload = {
			cuttingClass = "Axe",
			sectionId = idValue.Value,
			faceVector = faceVector,
			height = height,
			hitPoints = damage,
			cooldown = 0.65 * stats.SwingCooldown - ping,
			tool = tool,
		}

		return Remotes.fireChop(cutEvent, payload)
	end

	local function tryAutoChop(force: boolean?)
		if not force and not Config.AutoChop then
			return
		end

		local now = os.clock()
		local interval = tonumber(Config.ChopInterval) or 0.35
		if now - lastChopAt < interval then
			return
		end

		local root = Util.getRoot(LocalPlayer)
		if not root or not Util.isAlive(LocalPlayer) then
			return
		end

		local tool = if Config.AutoEquipAxe then Util.equipAxe(LocalPlayer) else Util.findEquippedAxe(LocalPlayer)
		if not tool then
			return
		end

		local stats = Util.getAxeStats(tool)
		local range = math.clamp(tonumber(Config.ChopRange) or 24, 8, 120)
		local section, treeModel, dist = getNearestSection(root.Position, range)
		if not (section and treeModel) then
			return
		end

		if Config.ChopTeleport and dist > (stats.Range * 0.8) then
			pcall(function()
				root.CFrame = CFrame.new(section.Position + Vector3.new(0, 3, 0), section.Position)
			end)
		end

		if chopSection(section, treeModel, tool) then
			lastChopAt = now
		end
	end

	local function findNearestRareWood(maxRange: number?)
		local root = Util.getRoot(LocalPlayer)
		if not root then
			return nil
		end
		local range = maxRange or math.clamp(tonumber(Config.WoodESPRange) or 400, 50, 5000)
		return select(1, getNearestSection(root.Position, range, {
			filter = "Any",
			rareOnly = true,
		}))
	end

	local function teleportToNearestRareWood()
		local section = findNearestRareWood()
		local root = Util.getRoot(LocalPlayer)
		if not (section and root) then
			warn("[LT2] no rare wood found in range")
			return false
		end
		return pcall(function()
			root.CFrame = CFrame.new(section.Position + Vector3.new(0, 5, 0), section.Position)
		end)
	end

	return {
		tryAutoChop = tryAutoChop,
		findNearestRareWood = findNearestRareWood,
		teleportToNearestRareWood = teleportToNearestRareWood,
	}
end

return M
