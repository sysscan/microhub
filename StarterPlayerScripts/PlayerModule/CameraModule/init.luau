-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
t.__index = t
local t2 = {
	"CameraMinZoomDistance",
	"CameraMaxZoomDistance",
	"CameraMode",
	"DevCameraOcclusionMode",
	"DevComputerCameraMode",
	"DevTouchCameraMode",
	"DevComputerMovementMode",
	"DevTouchMovementMode",
	"DevEnableMouseLock"
}
local t3 = { "ComputerCameraMovementMode", "ComputerMovementMode", "ControlMode", "GamepadCameraSensitivity", "MouseSensitivity", "RotationType", "TouchCameraMovementMode", "TouchMovementMode" }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local CommonUtils = script.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local CameraUtils = require(script:WaitForChild("CameraUtils"))
local CameraInput = require(script:WaitForChild("CameraInput"))
local ClassicCamera = require(script:WaitForChild("ClassicCamera"))
local OrbitalCamera = require(script:WaitForChild("OrbitalCamera"))
local LegacyCamera = require(script:WaitForChild("LegacyCamera"))
local VehicleCamera = require(script:WaitForChild("VehicleCamera"))
local VRCamera = require(script:WaitForChild("VRCamera"))
local VRVehicleCamera = require(script:WaitForChild("VRVehicleCamera"))
local Invisicam = require(script:WaitForChild("Invisicam"))
local Poppercam = require(script:WaitForChild("Poppercam"))
local TransparencyController = require(script:WaitForChild("TransparencyController"))
local MouseLockController = require(script:WaitForChild("MouseLockController"))
local t4 = {}
local t5 = {}
if Players.LocalPlayer then
	assert(Players.LocalPlayer, "Strict typing check")
	local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Follow)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Classic)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.CameraToggle)
	local UserRespectLegacyCameraOptions = FlagUtil.getUserFlag("UserRespectLegacyCameraOptions")
	local UserPlayerConnectionMemoryLeak = FlagUtil.getUserFlag("UserPlayerConnectionMemoryLeak")
	local UserPreferredInputPlayerScripts2 = FlagUtil.getUserFlag("UserPreferredInputPlayerScripts2")
	local UserPSFixCameraControllerReset = FlagUtil.getUserFlag("UserPSFixCameraControllerReset")
	function t.new() --[[ new | Line: 147 | Upvalues: TransparencyController (copy), UserPlayerConnectionMemoryLeak (copy), ConnectionUtil (copy), t (copy), Players (copy), UserInputService (copy), UserPreferredInputPlayerScripts2 (copy), MouseLockController (copy), UserRespectLegacyCameraOptions (copy), RunService (copy), t2 (copy), t3 (copy), UserGameSettings (copy) ]]
		local t4 = {
			activeTransparencyController = TransparencyController.new()
		}
		t4.connectionUtil = if UserPlayerConnectionMemoryLeak then ConnectionUtil.new() else nil
		local v3 = setmetatable(t4, t)
		v3.activeCameraController = nil
		v3.activeOcclusionModule = nil
		v3.activeMouseLockController = nil
		v3.currentComputerCameraMovementMode = nil
		v3.cameraSubjectChangedConn = nil
		v3.cameraTypeChangedConn = nil
		for k, v in pairs(Players:GetPlayers()) do
			v3:OnPlayerAdded(v)
		end
		Players.PlayerAdded:Connect(function(p1) --[[ Line: 170 | Upvalues: v3 (copy) ]]
			v3:OnPlayerAdded(p1)
		end)
		if UserPlayerConnectionMemoryLeak then
			Players.PlayerRemoving:Connect(function(p1) --[[ Line: 175 | Upvalues: v3 (copy) ]]
				v3:OnPlayerRemoving(p1)
			end)
		end
		v3.activeTransparencyController:Enable(true)
		if not UserInputService.TouchEnabled or UserPreferredInputPlayerScripts2 then
			v3.activeMouseLockController = MouseLockController.new()
			assert(v3.activeMouseLockController, "Strict typing check")
			local v4 = v3.activeMouseLockController:GetBindableToggleEvent()
			if v4 then
				v4:Connect(function() --[[ Line: 188 | Upvalues: v3 (copy) ]]
					v3:OnMouseLockToggled()
				end)
			end
		end
		if UserRespectLegacyCameraOptions then
			v3:ActivateCameraController()
		else
			v3:ActivateCameraController(v3:GetCameraControlChoice())
		end
		v3:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
		v3:OnCurrentCameraChanged()
		RunService:BindToRenderStep("cameraRenderUpdate", Enum.RenderPriority.Camera.Value, function(p1) --[[ Line: 201 | Upvalues: v3 (copy) ]]
			v3:Update(p1)
		end)
		for k, v in pairs(t2) do
			Players.LocalPlayer:GetPropertyChangedSignal(v):Connect(function() --[[ Line: 205 | Upvalues: v3 (copy), v (copy) ]]
				v3:OnLocalPlayerCameraPropertyChanged(v)
			end)
		end
		for k, v in pairs(t3) do
			UserGameSettings:GetPropertyChangedSignal(v):Connect(function() --[[ Line: 211 | Upvalues: v3 (copy), v (copy) ]]
				v3:OnUserGameSettingsPropertyChanged(v)
			end)
		end
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() --[[ Line: 215 | Upvalues: v3 (copy) ]]
			v3:OnCurrentCameraChanged()
		end)
		if UserPreferredInputPlayerScripts2 then
			UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() --[[ Line: 219 | Upvalues: v3 (copy) ]]
				v3:OnPreferredInputChanged()
			end)
		end
		return v3
	end
	function t.GetCameraMovementModeFromSettings(p1) --[[ GetCameraMovementModeFromSettings | Line: 227 | Upvalues: Players (copy), CameraUtils (copy), UserPreferredInputPlayerScripts2 (copy), UserInputService (copy), UserGameSettings (copy) ]]
		if Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
			return CameraUtils.ConvertCameraModeEnumToStandard(Enum.ComputerCameraMovementMode.Classic)
		end
		local v2, v3
		if if UserPreferredInputPlayerScripts2 then UserInputService.PreferredInput == Enum.PreferredInput.Touch else UserInputService.TouchEnabled then
			local v4 = CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevTouchCameraMode)
			v2, v3 = v4, CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
		else
			local v6 = CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevComputerCameraMode)
			v2, v3 = v6, CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)
		end
		if v2 == Enum.DevComputerCameraMovementMode.UserChoice then
			return v3
		else
			return v2
		end
	end
	function t.ActivateOcclusionModule(p1, p2) --[[ ActivateOcclusionModule | Line: 257 | Upvalues: Poppercam (copy), Invisicam (copy), t5 (copy), Players (copy) ]]
		local v1
		if p2 == Enum.DevCameraOcclusionMode.Zoom then
			v1 = Poppercam
		else
			if p2 ~= Enum.DevCameraOcclusionMode.Invisicam then
				warn("CameraScript ActivateOcclusionModule called with unsupported mode")
				return
			end
			v1 = Invisicam
		end
		p1.occlusionMode = p2
		if p1.activeOcclusionModule and p1.activeOcclusionModule:GetOcclusionMode() == p2 then
			if p1.activeOcclusionModule:GetEnabled() then
				return
			end
		else
			local activeOcclusionModule = p1.activeOcclusionModule
			p1.activeOcclusionModule = t5[v1]
			if not p1.activeOcclusionModule then
				p1.activeOcclusionModule = v1.new()
				if p1.activeOcclusionModule then
					t5[v1] = p1.activeOcclusionModule
				end
			end
			if not p1.activeOcclusionModule then
				return
			end
			if p1.activeOcclusionModule:GetOcclusionMode() ~= p2 then
				warn("CameraScript ActivateOcclusionModule mismatch: ", p1.activeOcclusionModule:GetOcclusionMode(), "~=", p2)
			end
			if activeOcclusionModule and activeOcclusionModule == p1.activeOcclusionModule then
				warn("CameraScript ActivateOcclusionModule failure to detect already running correct module")
			elseif activeOcclusionModule then
				activeOcclusionModule:Enable(false)
			end
			if p2 == Enum.DevCameraOcclusionMode.Invisicam then
				if Players.LocalPlayer.Character then
					p1.activeOcclusionModule:CharacterAdded(Players.LocalPlayer.Character, Players.LocalPlayer)
				end
			else
				for k, v in pairs(Players:GetPlayers()) do
					if v and v.Character then
						p1.activeOcclusionModule:CharacterAdded(v.Character, v)
					end
				end
				p1.activeOcclusionModule:OnCameraSubjectChanged(workspace.CurrentCamera.CameraSubject)
			end
		end
		p1.activeOcclusionModule:Enable(true)
	end
	function t.ShouldUseVehicleCamera(p1) --[[ ShouldUseVehicleCamera | Line: 336 ]]
		local CurrentCamera = workspace.CurrentCamera
		if not CurrentCamera then
			return false
		end
		local CameraType = CurrentCamera.CameraType
		local CameraSubject = CurrentCamera.CameraSubject
		local v1 = if CameraType == Enum.CameraType.Custom then true else CameraType == Enum.CameraType.Follow
		local v2 = CameraSubject and CameraSubject:IsA("VehicleSeat") or false
		return if v2 then if v1 then if p1.occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then false else true else v1 else v2
	end
	function t.ActivateCameraController(p1, p2, p3) --[[ ActivateCameraController | Line: 352 | Upvalues: UserRespectLegacyCameraOptions (copy), LegacyCamera (copy), VRService (copy), VRCamera (copy), ClassicCamera (copy), OrbitalCamera (copy), VRVehicleCamera (copy), VehicleCamera (copy), t4 (copy), UserPSFixCameraControllerReset (copy) ]]
		if UserRespectLegacyCameraOptions then
			p3 = workspace.CurrentCamera.CameraType
			p2 = p1:GetCameraMovementModeFromSettings()
		end
		local v2 = nil
		local v3 = if UserRespectLegacyCameraOptions then true elseif p3 == nil then false else true
		if v3 and p3 == Enum.CameraType.Scriptable then
			if not p1.activeCameraController then
				return
			end
			p1.activeCameraController:Enable(false)
			p1.activeCameraController = nil
			return
		elseif v3 and p3 == Enum.CameraType.Custom then
			p2 = p1:GetCameraMovementModeFromSettings()
		elseif v3 and p3 == Enum.CameraType.Track then
			p2 = Enum.ComputerCameraMovementMode.Classic
		elseif v3 and p3 == Enum.CameraType.Follow then
			p2 = Enum.ComputerCameraMovementMode.Follow
		elseif v3 and p3 == Enum.CameraType.Orbital then
			p2 = Enum.ComputerCameraMovementMode.Orbital
		elseif v3 and (p3 == Enum.CameraType.Attach or (p3 == Enum.CameraType.Watch or p3 == Enum.CameraType.Fixed)) then
			v2 = LegacyCamera
		elseif v3 then
			warn("CameraScript encountered an unhandled Camera.CameraType value: ", p3)
		end
		if not v2 and VRService.VREnabled then
			v2 = VRCamera
		elseif not v2 and (p2 == Enum.ComputerCameraMovementMode.Classic or (p2 == Enum.ComputerCameraMovementMode.Follow or (p2 == Enum.ComputerCameraMovementMode.Default or p2 == Enum.ComputerCameraMovementMode.CameraToggle))) then
			v2 = ClassicCamera
		elseif not v2 then
			if p2 ~= Enum.ComputerCameraMovementMode.Orbital then
				warn("ActivateCameraController did not select a module.")
				return
			end
			v2 = OrbitalCamera
		end
		if p1:ShouldUseVehicleCamera() then
			v2 = if VRService.VREnabled then VRVehicleCamera else VehicleCamera
		end
		local v5
		if t4[v2] then
			v5 = t4[v2]
			if UserPSFixCameraControllerReset then
				if v5.Reset and p1.activeCameraController ~= v5 then
					v5:Reset()
				end
			elseif v5.Reset then
				v5:Reset()
			end
		else
			local v6 = v2.new()
			t4[v2] = v6
			v5 = v6
		end
		if p1.activeCameraController then
			if p1.activeCameraController == v5 then
				if not p1.activeCameraController:GetEnabled() then
					p1.activeCameraController:Enable(true)
				end
			else
				p1.activeCameraController:Enable(false)
				p1.activeCameraController = v5
				p1.activeCameraController:Enable(true)
			end
		elseif v5 ~= nil then
			p1.activeCameraController = v5
			assert(p1.activeCameraController, "Strict typing check")
			p1.activeCameraController:Enable(true)
		end
		if not p1.activeCameraController then
			return
		end
		if UserRespectLegacyCameraOptions then
			p1.activeCameraController:SetCameraMovementMode(p2)
			p1.activeCameraController:SetCameraType(p3)
			return
		end
		if p2 ~= nil then
			p1.activeCameraController:SetCameraMovementMode(p2)
			return
		end
		if p3 == nil then
			return
		end
		p1.activeCameraController:SetCameraType(p3)
	end
	function t.OnCameraSubjectChanged(p1) --[[ OnCameraSubjectChanged | Line: 472 ]]
		local CurrentCamera = workspace.CurrentCamera
		local v1 = if CurrentCamera then CurrentCamera.CameraSubject else nil
		if p1.activeTransparencyController then
			p1.activeTransparencyController:SetSubject(v1)
		end
		if p1.activeOcclusionModule then
			p1.activeOcclusionModule:OnCameraSubjectChanged(v1)
		end
		p1:ActivateCameraController(nil, if CurrentCamera then CurrentCamera.CameraType else nil)
	end
	function t.OnCameraTypeChanged(p1, p2) --[[ OnCameraTypeChanged | Line: 487 | Upvalues: UserInputService (copy), CameraUtils (copy) ]]
		if p2 ~= Enum.CameraType.Scriptable or UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			p1:ActivateCameraController(nil, p2)
			return
		end
		CameraUtils.restoreMouseBehavior()
		p1:ActivateCameraController(nil, p2)
	end
	function t.OnCurrentCameraChanged(p1) --[[ OnCurrentCameraChanged | Line: 499 ]]
		local CurrentCamera = workspace.CurrentCamera
		if not CurrentCamera then
			return
		end
		if p1.cameraSubjectChangedConn then
			p1.cameraSubjectChangedConn:Disconnect()
		end
		if p1.cameraTypeChangedConn then
			p1.cameraTypeChangedConn:Disconnect()
		end
		p1.cameraSubjectChangedConn = CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function() --[[ Line: 511 | Upvalues: p1 (copy) ]]
			p1:OnCameraSubjectChanged()
		end)
		p1.cameraTypeChangedConn = CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function() --[[ Line: 515 | Upvalues: p1 (copy), CurrentCamera (copy) ]]
			p1:OnCameraTypeChanged(CurrentCamera.CameraType)
		end)
		p1:OnCameraSubjectChanged()
		p1:OnCameraTypeChanged(CurrentCamera.CameraType)
	end
	function t.OnLocalPlayerCameraPropertyChanged(p1, p2) --[[ OnLocalPlayerCameraPropertyChanged | Line: 523 | Upvalues: Players (copy), CameraUtils (copy) ]]
		if p2 == "CameraMode" then
			if Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
				if not p1.activeCameraController or p1.activeCameraController:GetModuleName() ~= "ClassicCamera" then
					p1:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard(Enum.DevComputerCameraMovementMode.Classic))
				end
				if p1.activeCameraController then
					p1.activeCameraController:UpdateForDistancePropertyChange()
				end
			elseif Players.LocalPlayer.CameraMode == Enum.CameraMode.Classic then
				p1:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard((p1:GetCameraMovementModeFromSettings())))
			else
				warn("Unhandled value for property player.CameraMode: ", Players.LocalPlayer.CameraMode)
			end
		else
			if p2 == "DevComputerCameraMode" or p2 == "DevTouchCameraMode" then
				p1:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard((p1:GetCameraMovementModeFromSettings())))
				return
			end
			if p2 == "DevCameraOcclusionMode" then
				p1:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
				return
			end
			if p2 == "CameraMinZoomDistance" or p2 == "CameraMaxZoomDistance" then
				if p1.activeCameraController then
					p1.activeCameraController:UpdateForDistancePropertyChange()
				end
			else
				if p2 == "DevTouchMovementMode" then
					return
				end
				if p2 == "DevComputerMovementMode" then
				end
			end
		end
	end
	function t.OnUserGameSettingsPropertyChanged(p1, p2) --[[ OnUserGameSettingsPropertyChanged | Line: 567 | Upvalues: CameraUtils (copy) ]]
		if p2 ~= "ComputerCameraMovementMode" then
			return
		end
		p1:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard((p1:GetCameraMovementModeFromSettings())))
	end
	function t.OnPreferredInputChanged(p1) --[[ OnPreferredInputChanged | Line: 574 | Upvalues: CameraUtils (copy) ]]
		p1:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard((p1:GetCameraMovementModeFromSettings())))
	end
	function t.Update(p1, p2) --[[ Update | Line: 585 | Upvalues: CameraInput (copy) ]]
		if not p1.activeCameraController then
			return
		end
		p1.activeCameraController:UpdateMouseBehavior()
		local v1, v2 = p1.activeCameraController:Update(p2)
		if p1.activeOcclusionModule then
			local v3, v4 = p1.activeOcclusionModule:Update(p2, v1, v2)
			v1 = v3
			v2 = v4
		end
		local CurrentCamera = workspace.CurrentCamera
		CurrentCamera.CFrame = v1
		CurrentCamera.Focus = v2
		if p1.activeTransparencyController then
			p1.activeTransparencyController:Update(p2)
		end
		if not CameraInput.getInputEnabled() then
			return
		end
		CameraInput.resetInputForFrameEnd()
	end
	function t.GetCameraControlChoice(p1) --[[ GetCameraControlChoice | Line: 613 | Upvalues: UserRespectLegacyCameraOptions (copy), UserInputService (copy), Players (copy), CameraUtils (copy), UserGameSettings (copy) ]]
		assert(not UserRespectLegacyCameraOptions, "CameraModule:GetCameraControlChoice should not be called when FFlagUserRespectLegacyCameraOptions is enabled")
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch or UserInputService.TouchEnabled then
			if Players.LocalPlayer.DevTouchCameraMode == Enum.DevTouchCameraMovementMode.UserChoice then
				return CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
			else
				return CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevTouchCameraMode)
			end
		elseif Players.LocalPlayer.DevComputerCameraMode == Enum.DevComputerCameraMovementMode.UserChoice then
			return CameraUtils.ConvertCameraModeEnumToStandard((CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)))
		else
			return CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevComputerCameraMode)
		end
	end
	function t.OnCharacterAdded(p1, p2, p3) --[[ OnCharacterAdded | Line: 633 ]]
		if not p1.activeOcclusionModule then
			return
		end
		p1.activeOcclusionModule:CharacterAdded(p2, p3)
	end
	function t.OnCharacterRemoving(p1, p2, p3) --[[ OnCharacterRemoving | Line: 639 ]]
		if not p1.activeOcclusionModule then
			return
		end
		p1.activeOcclusionModule:CharacterRemoving(p2, p3)
	end
	function t.OnPlayerAdded(p1, p2) --[[ OnPlayerAdded | Line: 645 | Upvalues: UserPlayerConnectionMemoryLeak (copy) ]]
		if UserPlayerConnectionMemoryLeak then
			if p1.connectionUtil then
				p1.connectionUtil:trackConnection(("%*CharacterAdded"):format(p2.UserId), p2.CharacterAdded:Connect(function(p12) --[[ Line: 649 | Upvalues: p1 (copy), p2 (copy) ]]
					p1:OnCharacterAdded(p12, p2)
				end))
				p1.connectionUtil:trackConnection(("%*CharacterRemoving"):format(p2.UserId), p2.CharacterRemoving:Connect(function(p12) --[[ Line: 652 | Upvalues: p1 (copy), p2 (copy) ]]
					p1:OnCharacterRemoving(p12, p2)
				end))
			end
		else
			p2.CharacterAdded:Connect(function(p12) --[[ Line: 657 | Upvalues: p1 (copy), p2 (copy) ]]
				p1:OnCharacterAdded(p12, p2)
			end)
			p2.CharacterRemoving:Connect(function(p12) --[[ Line: 660 | Upvalues: p1 (copy), p2 (copy) ]]
				p1:OnCharacterRemoving(p12, p2)
			end)
		end
	end
	function t.OnPlayerRemoving(p1, p2) --[[ OnPlayerRemoving | Line: 666 ]]
		if not p1.connectionUtil then
			return
		end
		p1.connectionUtil:disconnect((("%*CharacterAdded"):format(p2.UserId)))
		p1.connectionUtil:disconnect((("%*CharacterRemoving"):format(p2.UserId)))
	end
	function t.OnMouseLockToggled(p1) --[[ OnMouseLockToggled | Line: 674 ]]
		if not p1.activeMouseLockController then
			return
		end
		local v1 = p1.activeMouseLockController:GetIsMouseLocked()
		local v2 = p1.activeMouseLockController:GetMouseLockOffset()
		if not p1.activeCameraController then
			return
		end
		p1.activeCameraController:SetIsMouseLocked(v1)
		p1.activeCameraController:SetMouseLockOffset(v2)
	end
	t.new()
end
return {}