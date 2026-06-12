local M = {}

function M.create(opts)
	local Config = opts.config
	local Util = opts.util
	local Remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local treeRegion = workspace:WaitForChild("TreeRegion", 30)
	local lastChopAt = 0

	local function getNearestSection(origin: Vector3, maxRange: number)
		local bestSection = nil
		local bestModel = nil
		local bestDist = maxRange

		for _, model in treeRegion:GetChildren() do
			if not model:IsA("Model") then
				continue
			end
			local cutEvent = model:FindFirstChild("CutEvent")
			if not cutEvent then
				continue
			end
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") and descendant:FindFirstChild("ID") then
					local dist = Util.distance(origin, descendant.Position)
					if dist < bestDist then
						bestDist = dist
						bestSection = descendant
						bestModel = model
					end
				end
			end
		end

		return bestSection, bestModel, bestDist
	end

	local function buildFaceVector(section: BasePart, head: BasePart, surfaceNormal: Vector3): Vector3?
		local faceVector = Util.fixVector(section.CFrame:VectorToObjectSpace(surfaceNormal))
		if faceVector.Y ~= 0 then
			return nil
		end

		local lookAt = CFrame.new(head.Position, section.Position)
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
		local root = Util.getRoot(LocalPlayer)
		if not (head and root) then
			return false
		end

		local cutEvent = treeModel:FindFirstChild("CutEvent")
		local idValue = section:FindFirstChild("ID")
		if not (cutEvent and idValue and idValue:IsA("IntValue")) then
			return false
		end

		local stats = Util.getAxeStats(tool)
		local range = stats.Range
		local targetPos = section.Position
		local height = section.CFrame:PointToObjectSpace(targetPos).Y + section.Size.Y / 2

		local rayDirection = (targetPos - head.Position)
		if rayDirection.Magnitude < 0.05 then
			return false
		end

		local rayResult, surfaceNormal = workspace:FindPartOnRay(
			Ray.new(head.Position, rayDirection.Unit * range),
			LocalPlayer.Character
		)
		if rayResult ~= section and (not rayResult or rayResult.Parent ~= treeModel) then
			return false
		end
		if not surfaceNormal then
			surfaceNormal = -rayDirection.Unit
		end

		local faceVector = buildFaceVector(section, head, surfaceNormal)
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

		local range = math.clamp(tonumber(Config.ChopRange) or 24, 8, 80)
		local section, treeModel, dist = getNearestSection(root.Position, range)
		if not (section and treeModel) then
			return
		end

		if Config.ChopTeleport and dist > (Util.getAxeStats(tool).Range * 0.8) then
			pcall(function()
				root.CFrame = CFrame.new(section.Position + Vector3.new(0, 3, 0), section.Position)
			end)
			task.wait(0.05)
		end

		if chopSection(section, treeModel, tool) then
			lastChopAt = now
		end
	end

	return {
		tryAutoChop = tryAutoChop,
	}
end

return M
