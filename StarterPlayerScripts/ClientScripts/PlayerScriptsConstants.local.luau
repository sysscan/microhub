-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local CorpseCamera = ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Remotes"):WaitForChild("CorpseCamera")
local v1 = nil
local function detach() --[[ detach | Line: 13 | Upvalues: v1 (ref), LocalPlayer (copy), CurrentCamera (copy) ]]
	if v1 then
		v1:Disconnect()
		v1 = nil
	end
	local Character = LocalPlayer.Character
	local v12 = if Character then Character:FindFirstChildOfClass("Humanoid") else Character
	CurrentCamera.CameraType = Enum.CameraType.Custom
	CurrentCamera.CameraSubject = v12
	LocalPlayer.CameraMinZoomDistance = 0.5
end
CorpseCamera.OnClientEvent:Connect(function(p1) --[[ Line: 25 | Upvalues: v1 (ref), CurrentCamera (copy), LocalPlayer (copy) ]]
	if v1 then
		v1:Disconnect()
		v1 = nil
	end
	local v12 = if p1 then p1:FindFirstChild("Head") else p1
	if v12 then
		CurrentCamera.CameraType = Enum.CameraType.Attach
		CurrentCamera.CameraSubject = v12
		LocalPlayer.CameraMinZoomDistance = 5
		v1 = p1.AncestryChanged:Connect(function(p1, p2) --[[ Line: 38 | Upvalues: v1 (ref), LocalPlayer (ref), CurrentCamera (ref) ]]
			if p2 then
				return
			end
			if v1 then
				v1:Disconnect()
				v1 = nil
			end
			local Character = LocalPlayer.Character
			local v12 = if Character then Character:FindFirstChildOfClass("Humanoid") else Character
			CurrentCamera.CameraType = Enum.CameraType.Custom
			CurrentCamera.CameraSubject = v12
			LocalPlayer.CameraMinZoomDistance = 0.5
		end)
	end
end)
LocalPlayer.CharacterAdded:Connect(function(p1) --[[ Line: 45 | Upvalues: v1 (ref), LocalPlayer (copy), CurrentCamera (copy) ]]
	if v1 then
		v1:Disconnect()
		v1 = nil
	end
	local Character = LocalPlayer.Character
	local v12 = if Character then Character:FindFirstChildOfClass("Humanoid") else Character
	CurrentCamera.CameraType = Enum.CameraType.Custom
	CurrentCamera.CameraSubject = v12
	LocalPlayer.CameraMinZoomDistance = 0.5
	local Humanoid = p1:WaitForChild("Humanoid", 5)
	if not Humanoid then
		return
	end
	CurrentCamera.CameraType = Enum.CameraType.Custom
	CurrentCamera.CameraSubject = Humanoid
end)