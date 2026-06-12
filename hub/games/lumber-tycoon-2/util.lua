local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetItem = require(ReplicatedStorage:WaitForChild("Util"):WaitForChild("GetItem"))

local M = {}

function M.fixVector(vector: Vector3): Vector3
	return Vector3.new(
		math.floor(vector.X + 0.5),
		math.floor(vector.Y + 0.5),
		math.floor(vector.Z + 0.5)
	)
end

function M.getCharacter(player: Player): Model?
	return player and player.Character
end

function M.getHumanoid(player: Player): Humanoid?
	local character = M.getCharacter(player)
	return character and character:FindFirstChildOfClass("Humanoid")
end

function M.getRoot(player: Player): BasePart?
	local character = M.getCharacter(player)
	return character and character:FindFirstChild("HumanoidRootPart")
end

function M.getHead(player: Player): BasePart?
	local character = M.getCharacter(player)
	return character and character:FindFirstChild("Head")
end

function M.isAlive(player: Player): boolean
	local humanoid = M.getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

function M.getItemRoot(part: BasePart?): Instance?
	if not part then
		return nil
	end
	return GetItem(part)
end

function M.isOwnedBy(player: Player, item: Instance?): boolean
	if not item then
		return false
	end
	local owner = item:FindFirstChild("Owner")
	if owner and owner:IsA("ObjectValue") then
		return owner.Value == player
	end
	return false
end

function M.findEquippedAxe(player: Player): Tool?
	local character = M.getCharacter(player)
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:FindFirstChild("ToolName") then
			return child
		end
	end
	return nil
end

function M.findAxeInBackpack(player: Player): Tool?
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return nil
	end
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") and child:FindFirstChild("ToolName") then
			return child
		end
	end
	return nil
end

function M.equipAxe(player: Player): Tool?
	local equipped = M.findEquippedAxe(player)
	if equipped then
		return equipped
	end
	local humanoid = M.getHumanoid(player)
	local axe = M.findAxeInBackpack(player)
	if humanoid and axe then
		humanoid:EquipTool(axe)
		return axe
	end
	return nil
end

local AXE_DAMAGE = {
	BasicHatchet = 0.2,
	Axe1 = 0.6,
	Axe2 = 1.2,
	Axe3 = 2.4,
	FireAxe = 1.4,
	SilverAxe = 1.8,
	Rukiryaxe = 2.8,
}

function M.getAxeStats(tool: Tool?): { Damage: number, Range: number, SwingCooldown: number }
	local stats = {
		Damage = 1,
		Range = 10,
		SwingCooldown = 0.65,
	}
	if not tool then
		return stats
	end

	local rangeValue = tool:FindFirstChild("Range")
	if rangeValue and rangeValue:IsA("NumberValue") then
		stats.Range = rangeValue.Value
	end

	local toolName = tool:FindFirstChild("ToolName")
	if toolName and toolName:IsA("StringValue") then
		stats.Damage = AXE_DAMAGE[toolName.Value] or stats.Damage
	end

	return stats
end

function M.getTreeClass(model: Instance?): string?
	if not model then
		return nil
	end
	local treeClass = model:FindFirstChild("TreeClass")
	if treeClass and treeClass:IsA("StringValue") then
		return treeClass.Value
	end
	return nil
end

function M.distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

return M
