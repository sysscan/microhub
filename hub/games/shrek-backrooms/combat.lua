local M = {}

function M.create(opts)
	local Config = opts.config
	local remotes = opts.remotes
	local LocalPlayer = opts.localPlayer
	local movement = opts.movement
	local Camera = opts.camera

	local lastAttackAt = 0
	local lastEquipAt = 0

	local function getToolDamage(tool)
		if not tool then
			return 0
		end
		local config = tool:FindFirstChild("Configuration")
		if config then
			local hitDamage = config:FindFirstChild("HitDamage")
			if hitDamage and hitDamage:IsA("NumberValue") then
				return hitDamage.Value
			end
		end
		return 0
	end

	local function getAllTools()
		local tools = {}
		local character = LocalPlayer.Character
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if character then
			for _, child in character:GetChildren() do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end
		if backpack then
			for _, child in backpack:GetChildren() do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end
		return tools
	end

	local function getEquippedTool()
		local character = LocalPlayer.Character
		if not character then
			return nil
		end
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				return child
			end
		end
		return nil
	end

	local function equipBestTool()
		local humanoid = movement.getHumanoid()
		if not humanoid then
			return
		end

		local bestTool = nil
		local bestDamage = -1
		for _, tool in getAllTools() do
			local damage = getToolDamage(tool)
			if damage > bestDamage then
				bestDamage = damage
				bestTool = tool
			elseif damage == bestDamage and bestTool and #tool.Name > #bestTool.Name then
				bestTool = tool
			end
		end

		if bestTool and getEquippedTool() ~= bestTool then
			pcall(function()
				humanoid:EquipTool(bestTool)
			end)
		end
	end

	local function isMonsterModel(model)
		if not model or not model:IsA("Model") then
			return false
		end
		if model:FindFirstChild("Enemy") then
			return true
		end
		if model:GetAttribute("ClientEntity") then
			return true
		end
		return false
	end

	local function getMonsterRoot(model)
		return model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("RootPart")
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart")
	end

	local function getNearestMonster(range)
		local root = movement.getRoot()
		if not root then
			return nil
		end

		local monsters = workspace:FindFirstChild("Monsters")
		if not monsters then
			return nil
		end

		local bestModel = nil
		local bestDist = math.huge
		local camera = Camera or workspace.CurrentCamera

		for _, child in monsters:GetDescendants() do
			if child:IsA("Model") and isMonsterModel(child) then
				local humanoid = child:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health > 0 then
					local part = getMonsterRoot(child)
					if part then
						local dist = (part.Position - root.Position).Magnitude
						if dist <= range and dist < bestDist then
							if Config.AimAssist and camera then
								local screenPos = camera:WorldToViewportPoint(part.Position)
								local center = camera.ViewportSize * 0.5
								local fov = tonumber(Config.AimFOV) or 120
								if (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude > fov then
									continue
								end
							end
							bestDist = dist
							bestModel = child
						end
					end
				end
			end
		end

		return bestModel
	end

	local function faceTarget(model)
		local root = movement.getRoot()
		local part = model and getMonsterRoot(model)
		if not (root and part) then
			return
		end
		local flat = (part.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 0.1 then
			return
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end

	local function attackMonster(model, tool)
		local part = getMonsterRoot(model)
		if not (part and tool) then
			return
		end

		if Config.AimAssist then
			faceTarget(model)
		end

		if model:FindFirstChild("Enemy") then
			remotes.damageMonster(tool, part, part.Position)
			return
		end

		remotes.meleeMonster(tool, part.Parent)
	end

	local function tickCombat()
		local now = os.clock()

		if Config.AutoEquipBest and now - lastEquipAt >= 1 then
			lastEquipAt = now
			pcall(equipBestTool)
		end

		if not Config.AutoAttack then
			return
		end

		if now - lastAttackAt < (tonumber(Config.CombatInterval) or 0.12) then
			return
		end

		local tool = getEquippedTool()
		if not tool and Config.AutoEquipBest then
			equipBestTool()
			tool = getEquippedTool()
		end
		if not tool then
			return
		end

		local range = tonumber(Config.AttackRange) or 80
		local monster = getNearestMonster(range)
		if not monster then
			return
		end

		lastAttackAt = now
		pcall(function()
			attackMonster(monster, tool)
		end)
	end

	return {
		tickCombat = tickCombat,
		getNearestMonster = getNearestMonster,
		equipBestTool = equipBestTool,
		getEquippedTool = getEquippedTool,
	}
end

return M
