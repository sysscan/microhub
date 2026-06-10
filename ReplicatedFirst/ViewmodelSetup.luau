-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
local LocalPlayer = ({
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	Workspace = game:GetService("Workspace"),
	UserInputService = game:GetService("UserInputService"),
	ContextActionService = game:GetService("ContextActionService"),
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService"),
	SoundService = game:GetService("SoundService"),
	StarterGui = game:GetService("StarterGui")
}).Players.LocalPlayer
local v1 = false
function t.Setup(p1, p2) --[[ Setup | Line: 18 | Upvalues: LocalPlayer (copy), v1 (ref) ]]
	local v12 = workspace:GetAttribute("ViewmodelRealism") and script:WaitForChild("ViewmodelCloth"):Clone() or script:WaitForChild("Viewmodel"):Clone()
	local v2 = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	if not v2 then
		return nil
	end
	local BodyColors = v2:FindFirstChildOfClass("BodyColors")
	if BodyColors then
		BodyColors:Clone().Parent = v12
	end
	local Shirt = v2:FindFirstChildOfClass("Shirt")
	if Shirt and not v12:GetAttribute("NoShirt") then
		Shirt:Clone().Parent = v12
	end
	local v3 = v12:FindFirstChild("Humanoid") or v12:WaitForChild("Humanoid", 5)
	if v3 then
		v3.RequiresNeck = false
		v3.BreakJointsOnDeath = false
		v3:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		if not v1 then
			v1 = true
		end
	end
	local v4 = v12:FindFirstChild("Main") or (v12:FindFirstChild("RootPart") or v12.PrimaryPart)
	for i, v in ipairs(v12:GetDescendants()) do
		if v:IsA("BasePart") and v ~= v4 then
			v.Anchored = false
		end
	end
	if not v4 then
		v12:PivotTo(workspace.CurrentCamera.CFrame)
		return v12
	end
	v4.Anchored = true
	v12:PivotTo(workspace.CurrentCamera.CFrame)
	return v12
end
return t