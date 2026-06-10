-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer
local Map = LocalPlayer.PlayerGui:WaitForChild("Main", 10):WaitForChild("Canvas"):WaitForChild("Frames"):WaitForChild("Map")
local TemplatePointFrame = Map:WaitForChild("TemplatePointFrame")
local TemplateBaseFrame = Map:WaitForChild("TemplateBaseFrame")
local CurrentCamera = workspace.CurrentCamera
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local TeamsService = require(ReplicatedStorage.Game.Modules:WaitForChild("TeamsService"))
local Notify = require(ReplicatedStorage.Game.Modules:WaitForChild("Notify"))
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Config = require(Framework:WaitForChild("Config"))
local Game = workspace:WaitForChild("Game", 10)
local v1 = Game:WaitForChild("Capture Points", 10)
local GameSpawns = Game:WaitForChild("GameSpawns", 10)
local BaseDeploy = Game:WaitForChild("BaseDeploy", 10)
local v2 = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Spawn Points")
local BridgeNet2 = Framework:WaitForChild("Modules"):WaitForChild("BridgeNet2")
local v3 = require(BridgeNet2).ReferenceBridge("DroneEvent")
local v4 = RunService:IsStudio()
local v5 = false
local v6 = 0
local v7 = 0
local v8 = false
local v9 = nil
local function CheckDroneOwnershipSync() --[[ CheckDroneOwnershipSync | Line: 60 | Upvalues: v9 (ref), LocalPlayer (copy), v4 (copy), Packets (copy), MarketplaceService (copy) ]]
	if v9 == true then
		return true
	end
	if LocalPlayer.UserId == 0 or v4 then
		v9 = true
		return true
	end
	if Packets.OwnsSpecificGamepass:Fire("1406003009") == true then
		v9 = true
		return true
	end
	if Packets.OwnsSpecificGamepass:Fire("1663036633") == true then
		v9 = true
		return true
	end
	local v1, v2 = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, LocalPlayer.UserId, 1663036633)
	if v1 and v2 then
		v9 = true
		return true
	else
		v9 = false
		return false
	end
end
local function CheckDroneOwnership() --[[ CheckDroneOwnership | Line: 90 | Upvalues: v9 (ref) ]]
	if v9 == nil then
		return false
	else
		return v9
	end
end
task.spawn(CheckDroneOwnershipSync)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p1, p2, p3) --[[ Line: 99 | Upvalues: LocalPlayer (copy), v9 (ref) ]]
	if p1 ~= LocalPlayer or (p2 ~= 1663036633 or not p3) then
		return
	end
	v9 = true
end)
local function ValidateSpawnPoint(p1) --[[ ValidateSpawnPoint | Line: 105 | Upvalues: v1 (copy), TeamsService (copy), LocalPlayer (copy) ]]
	if not p1 or p1 == "N/A" then
		return false, "No spawn point selected"
	end
	if p1 == "Base" then
		return true, nil
	end
	local v12 = v1:FindFirstChild(p1)
	if not v12 then
		return false, string.format("Point %s does not exist", p1)
	end
	if v12:GetAttribute("Conflicted") then
		return false, string.format("Point %s is under attack! Choose another spawn point.", p1)
	end
	if TeamsService:GetPlayerTeam(LocalPlayer).Name == v12:GetAttribute("CapturedTeam") then
		return true, nil
	else
		return false, string.format("Point %s is not controlled by your team.", p1)
	end
end
local function GetLocalSpawnPoint(p1) --[[ GetLocalSpawnPoint | Line: 131 | Upvalues: TeamsService (copy), LocalPlayer (copy), Notify (copy), v2 (copy) ]]
	if not p1 then
		return nil
	end
	local v1 = TeamsService:GetPlayerTeam(LocalPlayer).Name
	if not v1 then
		Notify("Error", "You are not on a valid team.", 3)
		return nil
	end
	local v22 = v2:FindFirstChild(v1)
	if not v22 then
		Notify("Error", string.format("No spawn points found for team %s", v1), 3)
		return nil
	end
	if p1 == "Base" then
		local Base = v22:FindFirstChild("Base")
		if not Base then
			Notify("Error", "Base spawn folder not found", 3)
			return nil
		end
		local v3 = Base:GetChildren()
		if #v3 == 0 then
			Notify("Error", "No spawn points in base folder", 3)
			return nil
		else
			return v3[math.random(1, #v3)].Value
		end
	else
		local v4 = v22:FindFirstChild(p1)
		if not v4 then
			Notify("Error", string.format("No spawn folder found for %s", p1), 3)
			return nil
		end
		local v5 = v4:GetChildren()
		if #v5 == 0 then
			Notify("Error", string.format("No spawn points found for %s", p1), 3)
			return nil
		else
			return v5[math.random(1, #v5)].Value
		end
	end
end
local function IsDeployAllowed() --[[ IsDeployAllowed | Line: 181 | Upvalues: TeamsService (copy), LocalPlayer (copy) ]]
	if workspace:GetAttribute("DeployAllowed") == false then
		return false
	else
		return TeamsService:GetPlayerTeam(LocalPlayer).Name ~= "Neutral"
	end
end
local function PerformDeploy(p1, p2, p3) --[[ PerformDeploy | Line: 194 | Upvalues: v5 (ref), v6 (ref), TeamsService (copy), LocalPlayer (copy), Notify (copy), ValidateSpawnPoint (copy), Packets (copy), GetLocalSpawnPoint (copy), Config (copy) ]]
	if v5 then
		return
	end
	local v1 = if p3 == "Red" or p3 == "Blue" then "Base" else p3
	if tick() - v6 < 1 then
		return
	end
	if not (if workspace:GetAttribute("DeployAllowed") == false then false else TeamsService:GetPlayerTeam(LocalPlayer).Name ~= "Neutral") then
		Notify("Attention", "Deploying is currently not allowed.", 2)
		script.Cancel:Play()
		return
	end
	local v3, v4 = ValidateSpawnPoint(v1)
	if not v3 then
		Notify("Warning!", v4, 3)
		script.Cancel:Play()
		return
	end
	local Character = LocalPlayer.Character
	if not Character then
		Notify("Error!", "No character found, please wait...", 2)
		return
	end
	if Character:FindFirstChildOfClass("ForceField") then
		Character.ForceField:Destroy()
	end
	task.delay(5, function() --[[ Line: 229 | Upvalues: Character (copy) ]]
		if not Character:FindFirstChildOfClass("ForceField") then
			return
		end
		Character.ForceField:Destroy()
	end)
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then
		Notify("Error!", "Character not fully loaded, please wait...", 2)
		return
	end
	v5 = true
	v6 = tick()
	local v52 = Packets.Deploy:Fire(workspace:GetAttribute("Primary") or "N/A", workspace:GetAttribute("Secondary") or "N/A", workspace:GetAttribute("Equipment") or "N/A", v1)
	if v52 == "Success" then
		local v62 = GetLocalSpawnPoint(v1)
		if v62 then
			workspace:SetAttribute("InMenu", false)
			workspace:SetAttribute("TimeSinceLeftMenu", tick())
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.FieldOfView = 70
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				workspace.CurrentCamera.CameraSubject = Humanoid
				Humanoid.WalkSpeed = Config.Movement.DefaultWalkspeed or 11
				Humanoid.JumpPower = Config.JumpPower or 50
			end
			HumanoidRootPart.CFrame = v62
		end
	else
		Notify("Error!", v52 or "Unknown error occurred", 5)
		script.Cancel:Play()
	end
	v5 = false
end
local function DeployAsDrone() --[[ DeployAsDrone | Line: 280 | Upvalues: v7 (ref), LocalPlayer (copy), Notify (copy), CheckDroneOwnershipSync (copy), MarketplaceService (copy), TeamsService (copy), GameSpawns (copy), v8 (ref), v3 (copy), Packets (copy) ]]
	if tick() - v7 < 120 and LocalPlayer.UserId ~= 0 then
		Notify("Error", "Drone on cooldown! Wait: " .. math.floor(120 - (tick() - v7)), 3)
		return false, "Drone on cooldown"
	end
	if LocalPlayer:GetAttribute("InDrone") then
		return false, "Already in drone"
	end
	if not CheckDroneOwnershipSync() then
		MarketplaceService:PromptGamePassPurchase(LocalPlayer, 1663036633)
		return false, "No gamepass"
	end
	local v32 = TeamsService:GetPlayerTeam(LocalPlayer).Name
	if not v32 then
		return false, "No team"
	end
	local v4 = GameSpawns:FindFirstChild(v32)
	if not v4 then
		return false, "Team folder not found"
	end
	local Base = v4:FindFirstChild("Base")
	if not Base then
		return false, "Base folder not found"
	end
	local v5 = Base:GetChildren()
	if #v5 == 0 then
		return false, "No spawns found"
	end
	if v8 then
		return
	end
	v8 = true
	v7 = tick()
	local v6 = v5[math.random(1, #v5)]
	v3:Fire({
		Action = "Start",
		TypeDrone = workspace:GetAttribute("SelectedDroneEdit") or "FPV",
		PivotTo = v6.CFrame * CFrame.new(0, 200, 0),
		SelectedDroneAttachment = workspace:GetAttribute("SelectedDroneAttachment") or "For_Kamikaze"
	})
	LocalPlayer:SetAttribute("InDrone", true)
	Packets.Deploy:Fire(workspace:GetAttribute("Primary") or "N/A", workspace:GetAttribute("Secondary") or "N/A", workspace:GetAttribute("Equipment") or "N/A", "NONTP")
	local Character = LocalPlayer.Character
	if not Character then
		workspace:SetAttribute("InMenu", false)
		workspace:SetAttribute("TimeSinceLeftMenu", tick())
		workspace:SetAttribute("InRoom", false)
		task.delay(1, function() --[[ Line: 350 | Upvalues: v8 (ref) ]]
			v8 = false
		end)
		return true, nil
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		workspace:SetAttribute("InMenu", false)
		workspace:SetAttribute("TimeSinceLeftMenu", tick())
		workspace:SetAttribute("InRoom", false)
		task.delay(1, function() --[[ Line: 350 | Upvalues: v8 (ref) ]]
			v8 = false
		end)
		return true, nil
	end
	workspace.CurrentCamera.CameraSubject = Humanoid
	workspace:SetAttribute("InMenu", false)
	workspace:SetAttribute("TimeSinceLeftMenu", tick())
	workspace:SetAttribute("InRoom", false)
	task.delay(1, function() --[[ Line: 350 | Upvalues: v8 (ref) ]]
		v8 = false
	end)
	return true, nil
end
local function setupCapturePoint(p1) --[[ setupCapturePoint | Line: 357 | Upvalues: TemplatePointFrame (copy), CurrentCamera (copy), Map (copy), TeamsService (copy), LocalPlayer (copy), Notify (copy), TweenService (copy), PerformDeploy (copy), RunService (copy) ]]
	if p1:IsA("Model") then
		task.spawn(function() --[[ Line: 359 | Upvalues: p1 (copy), TemplatePointFrame (ref), CurrentCamera (ref), Map (ref), TeamsService (ref), LocalPlayer (ref), Notify (ref), TweenService (ref), PerformDeploy (ref), RunService (ref) ]]
			local Main = p1:WaitForChild("Main", (1 / 0))
			if not Main then
				return
			end
			local Point = p1:WaitForChild("Point", (1 / 0))
			if not Point then
				return
			end
			local BillboardGui = Point:WaitForChild("BillboardGui", (1 / 0))
			local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12_2, v13, v14, v15, v16, v17, v18
			if not BillboardGui then
				v1 = TemplatePointFrame:Clone()
				v1.Name = p1.Name
				v2 = v1.InfoFrame
				v3 = v1.DeployFrame
				v2.PointName.Text = ("POINT %*"):format(p1.Name)
				v3.PointName.Text = ("POINT %*"):format(p1.Name)
				v4, v5 = CurrentCamera:WorldToScreenPoint(Main.Position)
				v1.Visible = v5
				v1.Position = UDim2.fromOffset(v4.X, v4.Y)
				v1.Parent = Map
				v2.Visible = true
				v3.Visible = false
				v6 = {}
				v7 = v2.Button.Activated
				v8 = function() --[[ Line: 389 | Upvalues: TeamsService (ref), LocalPlayer (ref), p1 (ref), Notify (ref), v3 (copy), v2 (copy) ]]
					if TeamsService:GetPlayerTeam(LocalPlayer).Name ~= p1:GetAttribute("CapturedTeam") then
						Notify("Warning!", "Point " .. p1.Name .. " is not controlled by your team.", 3)
						return
					end
					if p1:GetAttribute("Conflicted") then
						Notify("Warning!", "Point " .. p1.Name .. " is under attack!", 3)
					else
						v3.Visible = true
						v2.Visible = false
						workspace:SetAttribute("SelectedPoint", p1.Name)
						workspace:SetAttribute("HideTopBar", true)
						script.Click:Play()
					end
				end
				table.insert(v6, v7:Connect(v8))
				v9 = v2.Button.MouseEnter
				v10 = function() --[[ Line: 408 | Upvalues: TweenService (ref), v1 (copy) ]]
					TweenService:Create(v1.UIScale, TweenInfo.new(0.2), {
						Scale = 1.1
					}):Play()
					v1.ZIndex = 5
				end
				table.insert(v6, v9:Connect(v10))
				v11 = v2.Button.MouseLeave
				v12_2 = function() --[[ Line: 413 | Upvalues: TweenService (ref), v1 (copy) ]]
					TweenService:Create(v1.UIScale, TweenInfo.new(0.4), {
						Scale = 1
					}):Play()
					v1.ZIndex = 1
				end
				table.insert(v6, v11:Connect(v12_2))
				v13 = v3.Deploy.Button.Activated
				v14 = function() --[[ Line: 418 | Upvalues: v3 (copy), v2 (copy), PerformDeploy (ref) ]]
					v3.Visible = false
					v2.Visible = true
					PerformDeploy(v3.Deploy.Button, nil, workspace:GetAttribute("SelectedPoint"))
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Confirm:Play()
				end
				table.insert(v6, v13:Connect(v14))
				v15 = v3.GoBack.Button.Activated
				table.insert(v6, v15:Connect(function() --[[ Line: 427 | Upvalues: v3 (copy), v2 (copy) ]]
					v3.Visible = false
					v2.Visible = true
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Cancel:Play()
				end))
				v16 = function() --[[ UpdatePointColor | Line: 435 | Upvalues: p1 (ref), v2 (copy) ]]
					local v1 = p1:GetAttribute("CapturedTeam")
					if v1 == "Blue Unit" then
						v2.ImageLabel.ImageColor3 = Color3.fromRGB(0, 110, 255)
						return
					end
					if v1 == "Red Unit" then
						v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 32, 36)
						return
					end
					v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
				end
				v17 = p1:GetAttributeChangedSignal("CapturedTeam")
				table.insert(v6, v17:Connect(v16))
				v16()
				RunService:BindToRenderStep(p1.Name .. "_Point", 1, function() --[[ Line: 452 | Upvalues: CurrentCamera (ref), Main (copy), p1 (ref), v1 (copy) ]]
					local v12, v2 = CurrentCamera:WorldToScreenPoint(Main.Position)
					local v3 = workspace:GetAttribute("SelectedPoint")
					if v3 and v3 ~= p1.Name then
						v1.Visible = false
					else
						v1.Visible = v2
					end
					v1.Position = UDim2.fromOffset(v12.X, v12.Y)
				end)
				v18 = nil
				v18 = p1.AncestryChanged:Connect(function(p12_2_2_2, p2_2_2_2) --[[ Line: 466 | Upvalues: RunService (ref), p1 (ref), v1 (copy), v6 (copy), v18 (ref) ]]
					if p2_2_2_2 then
						return
					end
					RunService:UnbindFromRenderStep(p1.Name .. "_Point")
					v1:Destroy()
					for i2, v_2 in ipairs(v6) do
						v_2:Disconnect()
					end
					v18:Disconnect()
				end)
				return
			end
			BillboardGui.Enabled = not workspace:GetAttribute("InMenu")
			v1 = TemplatePointFrame:Clone()
			v1.Name = p1.Name
			v2 = v1.InfoFrame
			v3 = v1.DeployFrame
			v2.PointName.Text = ("POINT %*"):format(p1.Name)
			v3.PointName.Text = ("POINT %*"):format(p1.Name)
			v4, v5 = CurrentCamera:WorldToScreenPoint(Main.Position)
			v1.Visible = v5
			v1.Position = UDim2.fromOffset(v4.X, v4.Y)
			v1.Parent = Map
			v2.Visible = true
			v3.Visible = false
			v6 = {}
			v7 = v2.Button.Activated
			v8 = function() --[[ Line: 389 | Upvalues: TeamsService (ref), LocalPlayer (ref), p1 (ref), Notify (ref), v3 (copy), v2 (copy) ]]
				if TeamsService:GetPlayerTeam(LocalPlayer).Name ~= p1:GetAttribute("CapturedTeam") then
					Notify("Warning!", "Point " .. p1.Name .. " is not controlled by your team.", 3)
					return
				end
				if p1:GetAttribute("Conflicted") then
					Notify("Warning!", "Point " .. p1.Name .. " is under attack!", 3)
				else
					v3.Visible = true
					v2.Visible = false
					workspace:SetAttribute("SelectedPoint", p1.Name)
					workspace:SetAttribute("HideTopBar", true)
					script.Click:Play()
				end
			end
			table.insert(v6, v7:Connect(v8))
			v9 = v2.Button.MouseEnter
			v10 = function() --[[ Line: 408 | Upvalues: TweenService (ref), v1 (copy) ]]
				TweenService:Create(v1.UIScale, TweenInfo.new(0.2), {
					Scale = 1.1
				}):Play()
				v1.ZIndex = 5
			end
			table.insert(v6, v9:Connect(v10))
			v11 = v2.Button.MouseLeave
			v12_2 = function() --[[ Line: 413 | Upvalues: TweenService (ref), v1 (copy) ]]
				TweenService:Create(v1.UIScale, TweenInfo.new(0.4), {
					Scale = 1
				}):Play()
				v1.ZIndex = 1
			end
			table.insert(v6, v11:Connect(v12_2))
			v13 = v3.Deploy.Button.Activated
			v14 = function() --[[ Line: 418 | Upvalues: v3 (copy), v2 (copy), PerformDeploy (ref) ]]
				v3.Visible = false
				v2.Visible = true
				PerformDeploy(v3.Deploy.Button, nil, workspace:GetAttribute("SelectedPoint"))
				workspace:SetAttribute("SelectedPoint", nil)
				workspace:SetAttribute("HideTopBar", false)
				script.Confirm:Play()
			end
			table.insert(v6, v13:Connect(v14))
			v15 = v3.GoBack.Button.Activated
			table.insert(v6, v15:Connect(function() --[[ Line: 427 | Upvalues: v3 (copy), v2 (copy) ]]
				v3.Visible = false
				v2.Visible = true
				workspace:SetAttribute("SelectedPoint", nil)
				workspace:SetAttribute("HideTopBar", false)
				script.Cancel:Play()
			end))
			v16 = function() --[[ UpdatePointColor | Line: 435 | Upvalues: p1 (ref), v2 (copy) ]]
				local v1 = p1:GetAttribute("CapturedTeam")
				if v1 == "Blue Unit" then
					v2.ImageLabel.ImageColor3 = Color3.fromRGB(0, 110, 255)
					return
				end
				if v1 == "Red Unit" then
					v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 32, 36)
					return
				end
				v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end
			v17 = p1:GetAttributeChangedSignal("CapturedTeam")
			table.insert(v6, v17:Connect(v16))
			v16()
			RunService:BindToRenderStep(p1.Name .. "_Point", 1, function() --[[ Line: 452 | Upvalues: CurrentCamera (ref), Main (copy), p1 (ref), v1 (copy) ]]
				local v12, v2 = CurrentCamera:WorldToScreenPoint(Main.Position)
				local v3 = workspace:GetAttribute("SelectedPoint")
				if v3 and v3 ~= p1.Name then
					v1.Visible = false
				else
					v1.Visible = v2
				end
				v1.Position = UDim2.fromOffset(v12.X, v12.Y)
			end)
			v18 = nil
			v18 = p1.AncestryChanged:Connect(function(p12_2_2_2, p2_2_2_2) --[[ Line: 466 | Upvalues: RunService (ref), p1 (ref), v1 (copy), v6 (copy), v18 (ref) ]]
				if p2_2_2_2 then
					return
				end
				RunService:UnbindFromRenderStep(p1.Name .. "_Point")
				v1:Destroy()
				for i2, v_2 in ipairs(v6) do
					v_2:Disconnect()
				end
				v18:Disconnect()
			end)
		end)
	end
end
local function setupBaseDeploy(p1) --[[ setupBaseDeploy | Line: 479 | Upvalues: TemplateBaseFrame (copy), CurrentCamera (copy), Map (copy), TweenService (copy), PerformDeploy (copy), v7 (ref), LocalPlayer (copy), v4 (copy), CheckDroneOwnershipSync (copy), Notify (copy), DeployAsDrone (copy), RunService (copy), v9 (ref) ]]
	if p1:IsA("Model") then
		task.spawn(function() --[[ Line: 481 | Upvalues: p1 (copy), TemplateBaseFrame (ref), CurrentCamera (ref), Map (ref), TweenService (ref), PerformDeploy (ref), v7 (ref), LocalPlayer (ref), v4 (ref), CheckDroneOwnershipSync (ref), Notify (ref), DeployAsDrone (ref), RunService (ref), v9 (ref) ]]
			local Main = p1:WaitForChild("Main", (1 / 0))
			if not Main then
				return
			end
			local v1 = TemplateBaseFrame:Clone()
			v1.Name = p1.Name
			local InfoFrame = v1.InfoFrame
			local DeployFrame = v1.DeployFrame
			local v2, v3 = CurrentCamera:WorldToScreenPoint(Main.Position)
			v1.Visible = v3
			v1.Position = UDim2.fromOffset(v2.X, v2.Y)
			v1.Parent = Map
			local v42 = if p1.Name == "Red" then "Red" elseif p1.Name == "Blue" then "Blue" else nil
			InfoFrame.ImageLabel.ImageColor3 = v42 == "Red" and Color3.fromRGB(255, 32, 36) or (if v42 == "Blue" then Color3.fromRGB(0, 110, 255) else false)
			InfoFrame.Visible = true
			DeployFrame.Visible = false
			local t2 = {}
			local function f62() --[[ Line: 505 | Upvalues: DeployFrame (copy), InfoFrame (copy), p1 (ref) ]]
				DeployFrame.Visible = true
				InfoFrame.Visible = false
				workspace:SetAttribute("SelectedPoint", p1.Name)
				workspace:SetAttribute("HideTopBar", true)
				script.Click:Play()
			end
			table.insert(t2, InfoFrame.Button.Activated:Connect(f62))
			local function f72() --[[ Line: 513 | Upvalues: TweenService (ref), v1 (copy) ]]
				TweenService:Create(v1.UIScale, TweenInfo.new(0.2), {
					Scale = 1.1
				}):Play()
				v1.ZIndex = 5
			end
			table.insert(t2, InfoFrame.Button.MouseEnter:Connect(f72))
			local function f82() --[[ Line: 518 | Upvalues: TweenService (ref), v1 (copy) ]]
				TweenService:Create(v1.UIScale, TweenInfo.new(0.4), {
					Scale = 1
				}):Play()
				v1.ZIndex = 1
			end
			table.insert(t2, InfoFrame.Button.MouseLeave:Connect(f82))
			local function f92() --[[ Line: 523 | Upvalues: DeployFrame (copy), InfoFrame (copy), PerformDeploy (ref) ]]
				DeployFrame.Visible = false
				InfoFrame.Visible = true
				PerformDeploy(DeployFrame.Deploy.Button, nil, workspace:GetAttribute("SelectedPoint"))
				workspace:SetAttribute("SelectedPoint", nil)
				workspace:SetAttribute("HideTopBar", false)
				script.Confirm:Play()
			end
			table.insert(t2, DeployFrame.Deploy.Button.Activated:Connect(f92))
			table.insert(t2, DeployFrame.GoBack.Button.Activated:Connect(function() --[[ Line: 532 | Upvalues: DeployFrame (copy), InfoFrame (copy) ]]
				DeployFrame.Visible = false
				InfoFrame.Visible = true
				workspace:SetAttribute("SelectedPoint", nil)
				workspace:SetAttribute("HideTopBar", false)
				script.Cancel:Play()
			end))
			local function f102() --[[ Line: 540 | Upvalues: v7 (ref), LocalPlayer (ref), v4 (ref), CheckDroneOwnershipSync (ref), Notify (ref), DeployFrame (copy), InfoFrame (copy), DeployAsDrone (ref) ]]
				local v1 = if tick() - v7 < 120 and LocalPlayer.UserId ~= 0 then not v4 else false
				if CheckDroneOwnershipSync() and not v1 then
					DeployFrame.Visible = false
					InfoFrame.Visible = true
					local _, _2_2 = DeployAsDrone()
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Confirm:Play()
					return
				end
				if not v1 then
					return
				end
				Notify("Warning!", "Drone is currently on cooldown!", 3)
			end
			table.insert(t2, DeployFrame.DeployAsDrone.Button.Activated:Connect(f102))
			RunService:BindToRenderStep(p1.Name .. "_Point", 1, function() --[[ Line: 558 | Upvalues: CurrentCamera (ref), Main (copy), LocalPlayer (ref), v7 (ref), v4 (ref), DeployFrame (copy), v9 (ref), v42 (copy), v1 (copy), p1 (ref) ]]
				local v12, v2 = CurrentCamera:WorldToScreenPoint(Main.Position)
				local v3 = workspace:GetAttribute("SelectedPoint")
				local v43 = LocalPlayer:GetAttribute("Team")
				DeployFrame.DeployAsDrone.FrameLock.Visible = not (if v9 == nil then false else v9) or (if tick() - v7 < 120 and LocalPlayer.UserId ~= 0 then not v4 else false)
				local v72 = false
				if v43 == "Red Unit" and v42 == "Red" or v43 == "Blue Unit" and v42 == "Blue" then
					v72 = true
				end
				if v72 then
					if v3 and v3 ~= p1.Name then
						v1.Visible = false
					else
						v1.Visible = v2
					end
				else
					v1.Visible = false
				end
				v1.Position = UDim2.fromOffset(v12.X, v12.Y)
			end)
			local v11 = nil
			v11 = p1.AncestryChanged:Connect(function(p12_2, p2_2) --[[ Line: 586 | Upvalues: RunService (ref), p1 (ref), v1 (copy), t2 (copy), v11 (ref) ]]
				if p2_2 then
					return
				end
				RunService:UnbindFromRenderStep(p1.Name .. "_Point")
				v1:Destroy()
				for i2, v_2 in ipairs(t2) do
					v_2:Disconnect()
				end
				v11:Disconnect()
			end)
		end)
	end
end
function t.Init() --[[ Init | Line: 599 | Upvalues: v1 (copy), TemplatePointFrame (copy), CurrentCamera (copy), Map (copy), TeamsService (copy), LocalPlayer (copy), Notify (copy), TweenService (copy), PerformDeploy (copy), RunService (copy), setupCapturePoint (copy), BaseDeploy (copy), TemplateBaseFrame (copy), v7 (ref), v4 (copy), CheckDroneOwnershipSync (copy), DeployAsDrone (copy), v9 (ref), setupBaseDeploy (copy) ]]
	for k, v in pairs(v1:GetChildren()) do
		if v:IsA("Model") then
			task.spawn(function() --[[ Line: 359 | Upvalues: v (copy), TemplatePointFrame (ref), CurrentCamera (ref), Map (ref), TeamsService (ref), LocalPlayer (ref), Notify (ref), TweenService (ref), PerformDeploy (ref), RunService (ref) ]]
				local Main = v:WaitForChild("Main", (1 / 0))
				if not Main then
					return
				end
				local Point = v:WaitForChild("Point", (1 / 0))
				if not Point then
					return
				end
				local BillboardGui = Point:WaitForChild("BillboardGui", (1 / 0))
				local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12_2, v13, v14, v15, v16, v17, v18
				if not BillboardGui then
					v1 = TemplatePointFrame:Clone()
					v1.Name = v.Name
					v2 = v1.InfoFrame
					v3 = v1.DeployFrame
					v2.PointName.Text = ("POINT %*"):format(v.Name)
					v3.PointName.Text = ("POINT %*"):format(v.Name)
					v4, v5 = CurrentCamera:WorldToScreenPoint(Main.Position)
					v1.Visible = v5
					v1.Position = UDim2.fromOffset(v4.X, v4.Y)
					v1.Parent = Map
					v2.Visible = true
					v3.Visible = false
					v6 = {}
					v7 = v2.Button.Activated
					v8 = function() --[[ Line: 389 | Upvalues: TeamsService (ref), LocalPlayer (ref), v (ref), Notify (ref), v3 (copy), v2 (copy) ]]
						if TeamsService:GetPlayerTeam(LocalPlayer).Name ~= p1:GetAttribute("CapturedTeam") then
							Notify("Warning!", "Point " .. p1.Name .. " is not controlled by your team.", 3)
							return
						end
						if p1:GetAttribute("Conflicted") then
							Notify("Warning!", "Point " .. p1.Name .. " is under attack!", 3)
						else
							v3.Visible = true
							v2.Visible = false
							workspace:SetAttribute("SelectedPoint", p1.Name)
							workspace:SetAttribute("HideTopBar", true)
							script.Click:Play()
						end
					end
					table.insert(v6, v7:Connect(v8))
					v9 = v2.Button.MouseEnter
					v10 = function() --[[ Line: 408 | Upvalues: TweenService (ref), v1 (copy) ]]
						TweenService:Create(v1.UIScale, TweenInfo.new(0.2), {
							Scale = 1.1
						}):Play()
						v1.ZIndex = 5
					end
					table.insert(v6, v9:Connect(v10))
					v11 = v2.Button.MouseLeave
					v12_2 = function() --[[ Line: 413 | Upvalues: TweenService (ref), v1 (copy) ]]
						TweenService:Create(v1.UIScale, TweenInfo.new(0.4), {
							Scale = 1
						}):Play()
						v1.ZIndex = 1
					end
					table.insert(v6, v11:Connect(v12_2))
					v13 = v3.Deploy.Button.Activated
					v14 = function() --[[ Line: 418 | Upvalues: v3 (copy), v2 (copy), PerformDeploy (ref) ]]
						v3.Visible = false
						v2.Visible = true
						PerformDeploy(v3.Deploy.Button, nil, workspace:GetAttribute("SelectedPoint"))
						workspace:SetAttribute("SelectedPoint", nil)
						workspace:SetAttribute("HideTopBar", false)
						script.Confirm:Play()
					end
					table.insert(v6, v13:Connect(v14))
					v15 = v3.GoBack.Button.Activated
					table.insert(v6, v15:Connect(function() --[[ Line: 427 | Upvalues: v3 (copy), v2 (copy) ]]
						v3.Visible = false
						v2.Visible = true
						workspace:SetAttribute("SelectedPoint", nil)
						workspace:SetAttribute("HideTopBar", false)
						script.Cancel:Play()
					end))
					v16 = function() --[[ UpdatePointColor | Line: 435 | Upvalues: v (ref), v2 (copy) ]]
						local v1 = p1:GetAttribute("CapturedTeam")
						if v1 == "Blue Unit" then
							v2.ImageLabel.ImageColor3 = Color3.fromRGB(0, 110, 255)
							return
						end
						if v1 == "Red Unit" then
							v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 32, 36)
							return
						end
						v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
					end
					v17 = v:GetAttributeChangedSignal("CapturedTeam")
					table.insert(v6, v17:Connect(v16))
					v16()
					RunService:BindToRenderStep(v.Name .. "_Point", 1, function() --[[ Line: 452 | Upvalues: CurrentCamera (ref), Main (copy), v (ref), v1 (copy) ]]
						local v12, v2 = CurrentCamera:WorldToScreenPoint(Main.Position)
						local v3 = workspace:GetAttribute("SelectedPoint")
						if v3 and v3 ~= p1.Name then
							v1.Visible = false
						else
							v1.Visible = v2
						end
						v1.Position = UDim2.fromOffset(v12.X, v12.Y)
					end)
					v18 = nil
					v18 = v.AncestryChanged:Connect(function(p12_2_2_2, p2_2_2_2) --[[ Line: 466 | Upvalues: RunService (ref), v (ref), v1 (copy), v6 (copy), v18 (ref) ]]
						if p2_2_2_2 then
							return
						end
						RunService:UnbindFromRenderStep(p1.Name .. "_Point")
						v1:Destroy()
						for i2, v_2 in ipairs(v6) do
							v_2:Disconnect()
						end
						v18:Disconnect()
					end)
					return
				end
				BillboardGui.Enabled = not workspace:GetAttribute("InMenu")
				v1 = TemplatePointFrame:Clone()
				v1.Name = v.Name
				v2 = v1.InfoFrame
				v3 = v1.DeployFrame
				v2.PointName.Text = ("POINT %*"):format(v.Name)
				v3.PointName.Text = ("POINT %*"):format(v.Name)
				v4, v5 = CurrentCamera:WorldToScreenPoint(Main.Position)
				v1.Visible = v5
				v1.Position = UDim2.fromOffset(v4.X, v4.Y)
				v1.Parent = Map
				v2.Visible = true
				v3.Visible = false
				v6 = {}
				v7 = v2.Button.Activated
				v8 = function() --[[ Line: 389 | Upvalues: TeamsService (ref), LocalPlayer (ref), v (ref), Notify (ref), v3 (copy), v2 (copy) ]]
					if TeamsService:GetPlayerTeam(LocalPlayer).Name ~= p1:GetAttribute("CapturedTeam") then
						Notify("Warning!", "Point " .. p1.Name .. " is not controlled by your team.", 3)
						return
					end
					if p1:GetAttribute("Conflicted") then
						Notify("Warning!", "Point " .. p1.Name .. " is under attack!", 3)
					else
						v3.Visible = true
						v2.Visible = false
						workspace:SetAttribute("SelectedPoint", p1.Name)
						workspace:SetAttribute("HideTopBar", true)
						script.Click:Play()
					end
				end
				table.insert(v6, v7:Connect(v8))
				v9 = v2.Button.MouseEnter
				v10 = function() --[[ Line: 408 | Upvalues: TweenService (ref), v1 (copy) ]]
					TweenService:Create(v1.UIScale, TweenInfo.new(0.2), {
						Scale = 1.1
					}):Play()
					v1.ZIndex = 5
				end
				table.insert(v6, v9:Connect(v10))
				v11 = v2.Button.MouseLeave
				v12_2 = function() --[[ Line: 413 | Upvalues: TweenService (ref), v1 (copy) ]]
					TweenService:Create(v1.UIScale, TweenInfo.new(0.4), {
						Scale = 1
					}):Play()
					v1.ZIndex = 1
				end
				table.insert(v6, v11:Connect(v12_2))
				v13 = v3.Deploy.Button.Activated
				v14 = function() --[[ Line: 418 | Upvalues: v3 (copy), v2 (copy), PerformDeploy (ref) ]]
					v3.Visible = false
					v2.Visible = true
					PerformDeploy(v3.Deploy.Button, nil, workspace:GetAttribute("SelectedPoint"))
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Confirm:Play()
				end
				table.insert(v6, v13:Connect(v14))
				v15 = v3.GoBack.Button.Activated
				table.insert(v6, v15:Connect(function() --[[ Line: 427 | Upvalues: v3 (copy), v2 (copy) ]]
					v3.Visible = false
					v2.Visible = true
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Cancel:Play()
				end))
				v16 = function() --[[ UpdatePointColor | Line: 435 | Upvalues: v (ref), v2 (copy) ]]
					local v1 = p1:GetAttribute("CapturedTeam")
					if v1 == "Blue Unit" then
						v2.ImageLabel.ImageColor3 = Color3.fromRGB(0, 110, 255)
						return
					end
					if v1 == "Red Unit" then
						v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 32, 36)
						return
					end
					v2.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
				end
				v17 = v:GetAttributeChangedSignal("CapturedTeam")
				table.insert(v6, v17:Connect(v16))
				v16()
				RunService:BindToRenderStep(v.Name .. "_Point", 1, function() --[[ Line: 452 | Upvalues: CurrentCamera (ref), Main (copy), v (ref), v1 (copy) ]]
					local v12, v2 = CurrentCamera:WorldToScreenPoint(Main.Position)
					local v3 = workspace:GetAttribute("SelectedPoint")
					if v3 and v3 ~= p1.Name then
						v1.Visible = false
					else
						v1.Visible = v2
					end
					v1.Position = UDim2.fromOffset(v12.X, v12.Y)
				end)
				v18 = nil
				v18 = v.AncestryChanged:Connect(function(p12_2_2_2, p2_2_2_2) --[[ Line: 466 | Upvalues: RunService (ref), v (ref), v1 (copy), v6 (copy), v18 (ref) ]]
					if p2_2_2_2 then
						return
					end
					RunService:UnbindFromRenderStep(p1.Name .. "_Point")
					v1:Destroy()
					for i2, v_2 in ipairs(v6) do
						v_2:Disconnect()
					end
					v18:Disconnect()
				end)
			end)
		end
	end
	v1.ChildAdded:Connect(setupCapturePoint)
	for k, v in pairs(BaseDeploy:GetChildren()) do
		if v:IsA("Model") then
			task.spawn(function() --[[ Line: 481 | Upvalues: v (copy), TemplateBaseFrame (ref), CurrentCamera (ref), Map (ref), TweenService (ref), PerformDeploy (ref), v7 (ref), LocalPlayer (ref), v4 (ref), CheckDroneOwnershipSync (ref), Notify (ref), DeployAsDrone (ref), RunService (ref), v9 (ref) ]]
				local Main = v:WaitForChild("Main", (1 / 0))
				if not Main then
					return
				end
				local v1 = TemplateBaseFrame:Clone()
				v1.Name = v.Name
				local InfoFrame = v1.InfoFrame
				local DeployFrame = v1.DeployFrame
				local v2, v3 = CurrentCamera:WorldToScreenPoint(Main.Position)
				v1.Visible = v3
				v1.Position = UDim2.fromOffset(v2.X, v2.Y)
				v1.Parent = Map
				local v42 = if v.Name == "Red" then "Red" elseif v.Name == "Blue" then "Blue" else nil
				InfoFrame.ImageLabel.ImageColor3 = v42 == "Red" and Color3.fromRGB(255, 32, 36) or (if v42 == "Blue" then Color3.fromRGB(0, 110, 255) else false)
				InfoFrame.Visible = true
				DeployFrame.Visible = false
				local t2 = {}
				local function f62() --[[ Line: 505 | Upvalues: DeployFrame (copy), InfoFrame (copy), v (ref) ]]
					DeployFrame.Visible = true
					InfoFrame.Visible = false
					workspace:SetAttribute("SelectedPoint", p1.Name)
					workspace:SetAttribute("HideTopBar", true)
					script.Click:Play()
				end
				table.insert(t2, InfoFrame.Button.Activated:Connect(f62))
				local function f72() --[[ Line: 513 | Upvalues: TweenService (ref), v1 (copy) ]]
					TweenService:Create(v1.UIScale, TweenInfo.new(0.2), {
						Scale = 1.1
					}):Play()
					v1.ZIndex = 5
				end
				table.insert(t2, InfoFrame.Button.MouseEnter:Connect(f72))
				local function f82() --[[ Line: 518 | Upvalues: TweenService (ref), v1 (copy) ]]
					TweenService:Create(v1.UIScale, TweenInfo.new(0.4), {
						Scale = 1
					}):Play()
					v1.ZIndex = 1
				end
				table.insert(t2, InfoFrame.Button.MouseLeave:Connect(f82))
				local function f92() --[[ Line: 523 | Upvalues: DeployFrame (copy), InfoFrame (copy), PerformDeploy (ref) ]]
					DeployFrame.Visible = false
					InfoFrame.Visible = true
					PerformDeploy(DeployFrame.Deploy.Button, nil, workspace:GetAttribute("SelectedPoint"))
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Confirm:Play()
				end
				table.insert(t2, DeployFrame.Deploy.Button.Activated:Connect(f92))
				table.insert(t2, DeployFrame.GoBack.Button.Activated:Connect(function() --[[ Line: 532 | Upvalues: DeployFrame (copy), InfoFrame (copy) ]]
					DeployFrame.Visible = false
					InfoFrame.Visible = true
					workspace:SetAttribute("SelectedPoint", nil)
					workspace:SetAttribute("HideTopBar", false)
					script.Cancel:Play()
				end))
				local function f102() --[[ Line: 540 | Upvalues: v7 (ref), LocalPlayer (ref), v4 (ref), CheckDroneOwnershipSync (ref), Notify (ref), DeployFrame (copy), InfoFrame (copy), DeployAsDrone (ref) ]]
					local v1 = if tick() - v7 < 120 and LocalPlayer.UserId ~= 0 then not v4 else false
					if CheckDroneOwnershipSync() and not v1 then
						DeployFrame.Visible = false
						InfoFrame.Visible = true
						local _, _2_2 = DeployAsDrone()
						workspace:SetAttribute("SelectedPoint", nil)
						workspace:SetAttribute("HideTopBar", false)
						script.Confirm:Play()
						return
					end
					if not v1 then
						return
					end
					Notify("Warning!", "Drone is currently on cooldown!", 3)
				end
				table.insert(t2, DeployFrame.DeployAsDrone.Button.Activated:Connect(f102))
				RunService:BindToRenderStep(v.Name .. "_Point", 1, function() --[[ Line: 558 | Upvalues: CurrentCamera (ref), Main (copy), LocalPlayer (ref), v7 (ref), v4 (ref), DeployFrame (copy), v9 (ref), v42 (copy), v1 (copy), v (ref) ]]
					local v12, v2 = CurrentCamera:WorldToScreenPoint(Main.Position)
					local v3 = workspace:GetAttribute("SelectedPoint")
					local v43 = LocalPlayer:GetAttribute("Team")
					DeployFrame.DeployAsDrone.FrameLock.Visible = not (if v9 == nil then false else v9) or (if tick() - v7 < 120 and LocalPlayer.UserId ~= 0 then not v4 else false)
					local v72 = false
					if v43 == "Red Unit" and v42 == "Red" or v43 == "Blue Unit" and v42 == "Blue" then
						v72 = true
					end
					if v72 then
						if v3 and v3 ~= p1.Name then
							v1.Visible = false
						else
							v1.Visible = v2
						end
					else
						v1.Visible = false
					end
					v1.Position = UDim2.fromOffset(v12.X, v12.Y)
				end)
				local v11 = nil
				v11 = v.AncestryChanged:Connect(function(p12_2, p2_2) --[[ Line: 586 | Upvalues: RunService (ref), v (ref), v1 (copy), t2 (copy), v11 (ref) ]]
					if p2_2 then
						return
					end
					RunService:UnbindFromRenderStep(p1.Name .. "_Point")
					v1:Destroy()
					for i2, v_2 in ipairs(t2) do
						v_2:Disconnect()
					end
					v11:Disconnect()
				end)
			end)
		end
	end
	BaseDeploy.ChildAdded:Connect(setupBaseDeploy)
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 610 | Upvalues: v1 (ref) ]]
		for k, v in pairs(v1:GetChildren()) do
			if v:IsA("Model") then
				local Point = v:FindFirstChild("Point")
				if Point then
					local BillboardGui = Point:FindFirstChild("BillboardGui")
					if BillboardGui then
						BillboardGui.Enabled = not workspace:GetAttribute("InMenu")
					end
				end
			end
		end
	end)
end
return t