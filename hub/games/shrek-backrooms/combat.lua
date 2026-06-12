local hubRequire = shared.__MicroHubRequire
local MonstersLib = hubRequire("games/shrek-backrooms/monsters.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local remotes = opts.remotes
	local LocalPlayer = opts.localPlayer
	local movement = opts.movement

	local lastAttackAt = 0
	local lastEquipAt = 0

	local function getCamera()
		return workspace.CurrentCamera
	end

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

	local function isCombatTool(tool)
		if not tool or not tool:IsA("Tool") then
			return false
		end
		if tool:GetAttribute("serial") then
			return false
		end
		return getToolDamage(tool) > 0
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
			if not isCombatTool(tool) then
				continue
			end
			local damage = getToolDamage(tool)
			if damage > bestDamage then
				bestDamage = damage
				bestTool = tool
			elseif damage == bestDamage and bestTool and tool.Name < bestTool.Name then
				bestTool = tool
			end
		end

		if bestTool and getEquippedTool() ~= bestTool then
			pcall(function()
				humanoid:EquipTool(bestTool)
			end)
		end
	end

	local function getNearestMonster(range)
		local root = movement.getRoot()
		if not root then
			return nil
		end

		local bestModel = nil
		local bestDist = math.huge
		local camera = getCamera()

		for _, child in MonstersLib.collect() do
			local part = MonstersLib.getRoot(child)
			if part then
				local dist = (part.Position - root.Position).Magnitude
				if dist <= range and dist < bestDist then
					if Config.AimAssist and camera then
						local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
						if not onScreen or screenPos.Z <= 0 then
							continue
						end
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

		return bestModel
	end

	local function faceTarget(model)
		local root = movement.getRoot()
		local part = model and MonstersLib.getRoot(model)
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
		local part = MonstersLib.getRoot(model)
		if not (part and tool) then
			return
		end

		if Config.AimAssist then
			faceTarget(model)
		end

		if model:FindFirstChild("Enemy", true) then
			remotes.damageMonster(tool, part, part.Position)
			return
		end

		remotes.meleeMonster(tool, model)
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
		if not tool or not isCombatTool(tool) then
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
