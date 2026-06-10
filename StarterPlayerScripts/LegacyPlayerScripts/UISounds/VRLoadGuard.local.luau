-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GroupService = game:GetService("GroupService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local v1 = os.clock()
workspace:SetAttribute("InMenu", true)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
local Loading = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main", 10):WaitForChild("Loading")
Loading.Visible = true
local Holder = Loading:WaitForChild("Holder")
local TextLabel = Holder:WaitForChild("TextLabel")
local ViewportFrame = Holder:WaitForChild("ViewportFrame")
local function ViewportModel(p1, p2) --[[ ViewportModel | Line: 25 | Upvalues: RunService (copy) ]]
	p1:ClearAllChildren()
	local Model = Instance.new("Model")
	local v1 = p2:Clone()
	v1.Parent = Model
	Model.PrimaryPart = v1
	Model.Parent = p1
	local Camera = Instance.new("Camera")
	Camera.Parent = p1
	p1.CurrentCamera = Camera
	Camera.FieldOfView = 5
	local v2 = math.random(10, 30)
	local v3 = math.random(10, 30)
	local v4 = math.random(10, 30)
	local _, v5 = Model:GetBoundingBox()
	local v6 = math.max(v5.X, v5.Y, v5.Z)
	Camera.CFrame = CFrame.new(0, 0, v6 / 2 / math.tan((math.rad(Camera.FieldOfView / 2))) * 1.65)
	RunService:BindToRenderStep("ViewportRotate", Enum.RenderPriority.Camera.Value, function(p1) --[[ Line: 50 | Upvalues: Model (copy), v2 (copy), v3 (copy), v4 (copy) ]]
		local PrimaryPart = Model.PrimaryPart
		if PrimaryPart then
			local v1 = p1 * 5
			Model:PivotTo(PrimaryPart.CFrame * CFrame.Angles(math.rad(v2 * v1), math.rad(v3 * v1), (math.rad(v4 * v1))))
		end
	end)
end
local Part = script:WaitForChild("Part")
task.spawn(function() --[[ Line: 67 | Upvalues: GroupService (copy), Part (copy) ]]
	local v1, v2 = pcall(GroupService.GetGroupInfoAsync, GroupService, 1029859683)
	if not (v1 and v2) then
		return
	end
	local EmblemUrl = v2.EmblemUrl
	for v3, v4 in Part:GetChildren() do
		if v4:IsA("Decal") then
			v4.Texture = EmblemUrl
		end
	end
end)
pcall(function() --[[ Line: 77 | Upvalues: TextChatService (copy) ]]
	TextChatService.ChatInputBarConfiguration.Enabled = false
	TextChatService.ChatWindowConfiguration.Enabled = false
end)
ViewportModel(ViewportFrame, Part)
local t = {}
for v2, v3 in script.Parent.Parent:GetDescendants() do
	if v3:IsA("ModuleScript") then
		t[#t + 1] = v3
	end
end
local v4 = #t
local count = 0
local t2 = {}
local v5 = 0
local v6 = 1
local t3 = { "", ".", "..", "..." }
for i = 1, v4 do
	local v7 = t[i]
	local v8, v9 = pcall(function() --[[ Line: 99 | Upvalues: v7 (copy) ]]
		local v1 = require(v7)
		if type(v1) == "function" then
			v1()
			return
		end
		if type(v1) ~= "table" or not v1.Init then
			return
		end
		v1.Init()
	end)
	if v8 then
		count = count + 1
	else
		t2[#t2 + 1] = {
			Module = v7.Name,
			Message = v9
		}
	end
	if i % 3 == 0 then
		local v10 = os.clock()
		if v10 - v5 > 0.1 then
			v6, v5 = v6 % 4 + 1, v10
		end
		TextLabel.Text = ("LOADING %*%*"):format(string.upper(v7.Name), t3[v6])
		RunService.Heartbeat:Wait()
	end
end
local v12 = math.floor((os.clock() - v1) * 100) / 100
TextLabel.Text = ("COMPLETE \226\128\162 %*/%* MODULES \226\128\162 %*S"):format(count, v4, v12)
print((("Loaded %*/%* modules in %*s | %* errors"):format(count, v4, v12, #t2)))
game:GetService("ContentProvider")
print("STARTED LOADING MESHES")
game:GetService("ReplicatedFirst"):WaitForChild("ViewmodelSetup"):WaitForChild("Viewmodel", 60):WaitForChild("Humanoid", 60)
warn("Found Humanoid")
task.wait(0.5)
RunService:UnbindFromRenderStep("ViewportRotate")
Loading.Visible = false
for v13, v14 in t2 do
	warn((("Error in module %*: %*"):format(v14.Module, v14.Message)))
end
local function G() --[[ G | Line: 169 ]]
	local v1 = table.create(10)
	for i = 1, 10 do
		v1[i] = if math.random(1, 3) == 1 then "O" else "?"
	end
	return table.concat(v1)
end
local Game = ReplicatedStorage:FindFirstChild("Game")
if Game then
	local Modules = Game:FindFirstChild("Modules")
	if Modules then
		for v15, v16 in Modules:GetChildren() do
			v16.Name = G()
		end
	end
	for v17, v18 in Game:GetChildren() do
		v18.Name = G()
	end
end
for v19, v20 in script.Parent.Parent:GetDescendants() do
	if v20:IsA("ModuleScript") or v20:IsA("Folder") then
		v20.Name = G()
	end
end
for v21, v22 in StarterPlayer:GetDescendants() do
	local ClassName = v22.ClassName
	if ClassName == "ModuleScript" or (ClassName == "LocalScript" or ClassName == "Folder") then
		v22.Name = G()
	end
end