-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local NVG = LocalPlayer.PlayerGui:WaitForChild("Main"):WaitForChild("CanvasInGame"):WaitForChild("NVG")
local v1 = NVG:WaitForChild("PVS-14")
local EffectModel = script:WaitForChild("EffectModel")
local v2 = nil
local t = {
	"rbxassetid://99972172717166",
	"rbxassetid://138966267206125",
	"rbxassetid://86592819700473",
	"rbxassetid://84792287808804",
	"rbxassetid://86468965397340",
	"rbxassetid://124866153868026",
	"rbxassetid://71908539345540",
	"rbxassetid://79477391348381",
	"rbxassetid://90306766851660",
	"rbxassetid://85630194168300"
}
return function() --[[ Line: 28 | Upvalues: v1 (copy), Lighting (copy), NVG (copy), RunService (copy), t (copy), LocalPlayer (copy), v2 (ref), EffectModel (copy) ]]
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 29 | Upvalues: v1 (ref), Lighting (ref) ]]
		if not workspace:GetAttribute("InMenu") then
			return
		end
		v1.Visible = false
		local PVS = Lighting:FindFirstChild("PVS")
		if PVS then
			PVS:Destroy()
		end
		Lighting.ExposureCompensation = 0.33
	end)
	v1:GetPropertyChangedSignal("Visible"):Connect(function() --[[ Line: 40 | Upvalues: NVG (ref), v1 (ref), RunService (ref), t (ref), LocalPlayer (ref), v2 (ref), EffectModel (ref), Lighting (ref) ]]
		local Grain = NVG:WaitForChild("Grain")
		if v1.Visible then
			Grain.Visible = true
			RunService:BindToRenderStep("Grain", 1, function() --[[ Line: 44 | Upvalues: Grain (copy), t (ref) ]]
				Grain.Image = t[math.random(1, #t)]
			end)
			if LocalPlayer:GetAttribute("FishEye") then
				v2 = EffectModel:Clone()
				v2.Parent = workspace.CurrentCamera
				RunService:BindToRenderStep("FishEye", Enum.RenderPriority.Camera.Value + 1, function() --[[ Line: 51 | Upvalues: v2 (ref) ]]
					local CurrentCamera = workspace.CurrentCamera
					local v3 = math.tan(math.rad(CurrentCamera.FieldOfView) / 2) * 6
					v2:ScaleTo(1.15 * (CurrentCamera.ViewportSize.Y / 1080) * (v3 / (math.tan(math.rad(workspace:GetAttribute("FieldOfView") or 70) / 2) * 6)))
					v2:PivotTo(CurrentCamera.CFrame * CFrame.new(0, 0, -3))
				end)
			end
			if Lighting:FindFirstChild("BlurEffect") then
				Lighting:FindFirstChild("BlurEffect").Enabled = true
			end
		else
			RunService:UnbindFromRenderStep("Grain")
			if LocalPlayer:GetAttribute("FishEye") then
				RunService:UnbindFromRenderStep("FishEye")
			end
			Grain.Visible = false
			if v2 then
				v2:Destroy()
			end
			if not Lighting:FindFirstChild("BlurEffect") then
				return
			end
			Lighting:FindFirstChild("BlurEffect").Enabled = false
		end
	end)
end