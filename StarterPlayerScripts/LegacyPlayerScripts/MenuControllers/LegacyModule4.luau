-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer
local Hotbar = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("CanvasInGame"):WaitForChild("Hotbar")
local Maid = require(ReplicatedStorage.Game.Modules:WaitForChild("Maid"))
local t = {
	Tools = {},
	Connections = {},
	ToolCounter = 0,
	HideTimer = nil,
	LastAction = 0
}
local t2 = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9
}
function t.ShowInventory(p1) --[[ ShowInventory | Line: 38 | Upvalues: Hotbar (copy) ]]
	Hotbar.Visible = true
	if p1.HideTimer then
		task.cancel(p1.HideTimer)
	end
	p1.HideTimer = task.delay(5, function() --[[ Line: 43 | Upvalues: Hotbar (ref) ]]
		Hotbar.Visible = false
	end)
end
function t.GetCharacter(p1) --[[ GetCharacter | Line: 48 | Upvalues: LocalPlayer (copy) ]]
	return LocalPlayer.Character
end
function t.GetHumanoid(p1) --[[ GetHumanoid | Line: 52 ]]
	local v1 = p1:GetCharacter()
	return if v1 then v1:FindFirstChildOfClass("Humanoid") else v1
end
function t.CanEquipTools(p1) --[[ CanEquipTools | Line: 57 ]]
	local v1 = workspace:GetAttribute("EnableToolEquip")
	return if v1 == nil then true else v1 == true
end
function t.GetSortedTools(p1) --[[ GetSortedTools | Line: 62 ]]
	local t = {}
	for k, v in pairs(p1.Tools) do
		if k and (k.Parent and (v and (v.Button and v.Button.Parent))) then
			table.insert(t, {
				Tool = k,
				Button = v.Button,
				Order = v.Button.LayoutOrder
			})
		end
	end
	table.sort(t, function(p1, p2) --[[ Line: 69 ]]
		return p1.Order < p2.Order
	end)
	return t
end
function t.RenumberButtons(p1) --[[ RenumberButtons | Line: 75 ]]
	local v1 = p1:GetSortedTools()
	for i, v in ipairs(v1) do
		local Button = v.Button
		Button.LayoutOrder = i
		local ColorFrame = Button:FindFirstChild("ColorFrame")
		if ColorFrame then
			local Number = ColorFrame:FindFirstChild("Number")
			if Number then
				Number.Text = tostring(i)
			end
		end
	end
	p1.ToolCounter = #v1
end
function t.RefreshVisuals(p1) --[[ RefreshVisuals | Line: 91 | Upvalues: TweenService (copy) ]]
	local v1 = p1:GetCharacter()
	for k, v in pairs(p1.Tools) do
		local Button = v.Button
		if Button and Button.Parent then
			if k.Parent == v1 then
				TweenService:Create(Button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					Size = UDim2.new(0.3, 0, 0.9, 0)
				}):Play()
				if Button:FindFirstChild("ColorFrame") then
					TweenService:Create(Button.ColorFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
						Size = UDim2.new(0.2, 0, 0.8, 0)
					}):Play()
				end
				if Button:FindFirstChild("ToolName") then
					TweenService:Create(Button.ToolName, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
						TextTransparency = 0
					}):Play()
				end
				continue
			end
			TweenService:Create(Button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
				Size = UDim2.new(0.1, 0, 0.9, 0)
			}):Play()
			if Button:FindFirstChild("ColorFrame") then
				TweenService:Create(Button.ColorFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					Size = UDim2.new(0.975, 0, 0.8, 0)
				}):Play()
			end
			if Button:FindFirstChild("ToolName") then
				TweenService:Create(Button.ToolName, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					TextTransparency = 1
				}):Play()
			end
		end
	end
end
function t.ToggleTool(p1, p2) --[[ ToggleTool | Line: 117 | Upvalues: LocalPlayer (copy) ]]
	if not p1:CanEquipTools() then
		return
	end
	local v1 = p1:GetHumanoid()
	if not v1 then
		return
	end
	if os.clock() - p1.LastAction < 0.25 then
		return
	end
	p1.LastAction = os.clock()
	if p2.Parent == LocalPlayer.Backpack then
		v1:EquipTool(p2)
		return
	end
	if p2.Parent ~= p1:GetCharacter() then
		return
	end
	v1:UnequipTools()
end
function t.SelectSlot(p1, p2) --[[ SelectSlot | Line: 132 ]]
	if not p1:CanEquipTools() then
		return
	end
	local v1 = p1:GetSortedTools()
	local v2 = p1:GetHumanoid()
	if not v2 then
		return
	end
	if os.clock() - p1.LastAction < 0.25 then
		return
	end
	p1.LastAction = os.clock()
	if p2 < 1 or #v1 < p2 then
		v2:UnequipTools()
		return
	end
	local v3 = v1[p2]
	if not v3 then
		return
	end
	v2:EquipTool(v3.Tool)
end
function t.GetCurrentSlot(p1) --[[ GetCurrentSlot | Line: 152 ]]
	local v1 = p1:GetCharacter()
	for i, v in ipairs((p1:GetSortedTools())) do
		if v.Tool.Parent == v1 then
			return i
		end
	end
	return 0
end
function t.CycleNext(p1) --[[ CycleNext | Line: 163 ]]
	local v1 = p1:GetSortedTools()
	if #v1 == 0 then
		return
	end
	local v2 = p1:GetCurrentSlot() + 1
	if #v1 < v2 then
		v2 = 1
	end
	p1:SelectSlot(v2)
	p1:ShowInventory()
end
function t.CyclePrevious(p1) --[[ CyclePrevious | Line: 173 ]]
	local v1 = p1:GetSortedTools()
	if #v1 == 0 then
		return
	end
	local v2 = p1:GetCurrentSlot() - 1
	if v2 < 1 then
		v2 = #v1
	end
	p1:SelectSlot(v2)
	p1:ShowInventory()
end
function t.CreateButton(p1, p2) --[[ CreateButton | Line: 183 | Upvalues: Hotbar (copy) ]]
	local Template = script:FindFirstChild("Template")
	if not Template then
		return nil
	end
	p1.ToolCounter = p1.ToolCounter + 1
	local v1 = Template:Clone()
	v1.Name = p2.Name
	v1.Parent = Hotbar
	v1.LayoutOrder = p1.ToolCounter
	local ToolName = v1:FindFirstChild("ToolName")
	if ToolName then
		ToolName.Text = p2.Name
	end
	local ColorFrame = v1:FindFirstChild("ColorFrame")
	if not ColorFrame then
		return v1
	end
	local Number = ColorFrame:FindFirstChild("Number")
	if not Number then
		return v1
	end
	Number.Text = tostring(p1.ToolCounter)
	return v1
end
function t.AddTool(p1, p2) --[[ AddTool | Line: 205 | Upvalues: Maid (copy), LocalPlayer (copy) ]]
	if not p2:IsA("Tool") then
		return
	end
	if p1.Tools[p2] then
		return
	end
	local v1 = p1:CreateButton(p2)
	if v1 then
		local v2 = Maid.new()
		p1.Tools[p2] = {
			Button = v1,
			Maid = v2
		}
		v2:GiveTask(v1.Activated:Connect(function() --[[ Line: 218 | Upvalues: p1 (copy), p2 (copy) ]]
			p1:ToggleTool(p2)
			p1:ShowInventory()
		end))
		v2:GiveTask(v1)
		v2:GiveTask(p2:GetPropertyChangedSignal("Parent"):Connect(function() --[[ Line: 225 | Upvalues: p2 (copy), LocalPlayer (ref), p1 (copy) ]]
			if p2:IsDescendantOf(game) and (p2.Parent == LocalPlayer.Backpack or p2.Parent == p1:GetCharacter()) then
				p1:RefreshVisuals()
			else
				p1:RemoveTool(p2)
			end
		end))
		p1:RenumberButtons()
		p1:RefreshVisuals()
	end
end
function t.RemoveTool(p1, p2) --[[ RemoveTool | Line: 237 ]]
	local v1 = p1.Tools[p2]
	if not v1 then
		return
	end
	if not v1.Maid then
		p1.Tools[p2] = nil
		p1:RenumberButtons()
		p1:RefreshVisuals()
		return
	end
	v1.Maid:DoCleaning()
	p1.Tools[p2] = nil
	p1:RenumberButtons()
	p1:RefreshVisuals()
end
function t.SetupKeyboard(p1) --[[ SetupKeyboard | Line: 250 | Upvalues: UserInputService (copy), t2 (copy) ]]
	if p1.Connections.Keyboard then
		p1.Connections.Keyboard:Disconnect()
	end
	p1.Connections.Keyboard = UserInputService.InputBegan:Connect(function(p12, p2) --[[ Line: 255 | Upvalues: t2 (ref), p1 (copy) ]]
		if p2 then
			return
		end
		local v1 = t2[p12.KeyCode]
		if not v1 then
			return
		end
		local v2 = p1:GetSortedTools()[v1]
		if not v2 then
			return
		end
		p1:ToggleTool(v2.Tool)
		p1:ShowInventory()
	end)
end
function t.SetupGamepad(p1) --[[ SetupGamepad | Line: 269 | Upvalues: ContextActionService (copy) ]]
	ContextActionService:UnbindAction("InventoryNext")
	ContextActionService:UnbindAction("InventoryPrevious")
	local function handleNext(p12, p2) --[[ handleNext | Line: 273 | Upvalues: p1 (copy) ]]
		if p2 == Enum.UserInputState.Begin then
			p1:CycleNext()
			return Enum.ContextActionResult.Sink
		else
			return Enum.ContextActionResult.Pass
		end
	end
	local function handlePrevious(p12, p2) --[[ handlePrevious | Line: 281 | Upvalues: p1 (copy) ]]
		if p2 == Enum.UserInputState.Begin then
			p1:CyclePrevious()
			return Enum.ContextActionResult.Sink
		else
			return Enum.ContextActionResult.Pass
		end
	end
	ContextActionService:BindAction("InventoryNext", handleNext, false, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("InventoryPrevious", handlePrevious, false, Enum.KeyCode.ButtonL1)
end
function t.Cleanup(p1) --[[ Cleanup | Line: 293 | Upvalues: Hotbar (copy), ContextActionService (copy) ]]
	for k, v in pairs(p1.Connections) do
		if v and k ~= "CharacterAdded" then
			v:Disconnect()
		end
	end
	for k, v in pairs(p1.Tools) do
		if v and v.Maid then
			v.Maid:DoCleaning()
		end
	end
	for i, v in ipairs(Hotbar:GetChildren()) do
		if v:IsA("GuiButton") then
			v:Destroy()
		end
	end
	p1.Tools = {}
	p1.ToolCounter = 0
	ContextActionService:UnbindAction("InventoryNext")
	ContextActionService:UnbindAction("InventoryPrevious")
	p1.Connections = {
		CharacterAdded = p1.Connections.CharacterAdded
	}
end
function t.Initialize(p1) --[[ Initialize | Line: 322 | Upvalues: StarterGui (copy), LocalPlayer (copy) ]]
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	local function setupCharacter(p12) --[[ setupCharacter | Line: 325 | Upvalues: p1 (copy), LocalPlayer (ref) ]]
		p1:Cleanup()
		p12:WaitForChild("Humanoid")
		local Backpack = LocalPlayer:WaitForChild("Backpack")
		for i, v in ipairs(Backpack:GetChildren()) do
			p1:AddTool(v)
		end
		for i, v in ipairs(p12:GetChildren()) do
			p1:AddTool(v)
		end
		p1.Connections.BackpackAdded = Backpack.ChildAdded:Connect(function(p12) --[[ Line: 338 | Upvalues: p1 (ref) ]]
			p1:AddTool(p12)
		end)
		p1.Connections.CharAdded = p12.ChildAdded:Connect(function(p12) --[[ Line: 341 | Upvalues: p1 (ref) ]]
			p1:AddTool(p12)
		end)
		p1:SetupKeyboard()
		p1:SetupGamepad()
		p1:RefreshVisuals()
	end
	p1.Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(setupCharacter)
	if not LocalPlayer.Character then
		return
	end
	setupCharacter(LocalPlayer.Character)
end
return function() --[[ Line: 357 | Upvalues: t (copy) ]]
	t:Initialize()
end