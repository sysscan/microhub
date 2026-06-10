-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local Maid = require(ReplicatedStorage.Game.Modules:WaitForChild("Maid"))
local TeamsService = require(ReplicatedStorage.Game.Modules:WaitForChild("TeamsService"))
local Frames = PlayerGui:WaitForChild("Main"):WaitForChild("Canvas"):WaitForChild("Frames")
local PurchaseConfirmation = Frames.Loadout.PurchaseConfirmation
local ToggleAccessoires = Frames.Loadout.Outfit.ToggleAccessoires
local Outfit = ReplicatedStorage.Game.Assets.Outfit
local t = {}
local CurrentCamera = workspace.CurrentCamera
local Terrain = workspace:WaitForChild("Terrain")
local v1 = Maid.new()
local v2 = false
local v3 = nil
local v4 = false
local v5 = nil
local v6 = 1
local v7 = nil
local v8 = false
local v9 = nil
local t2 = {}
local t3 = {
	{
		Accessories = nil,
		Bands = nil,
		Helmets = nil,
		LegAccessoires = nil,
		Pants = nil,
		Shirt = nil,
		Vests = nil
	}
}
local t4 = { "Blue Unit", "Red Unit" }
Color3.new(255/255, 255/255, 255/255)
Color3.new(0/255, 0/255, 0/255)
TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v10 = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v11 = TweenInfo.new(0.2)
local v12 = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local function UnanchorAll(p1) --[[ UnanchorAll | Line: 66 ]]
	for v1, v2 in p1:GetDescendants() do
		if v2:IsA("BasePart") then
			v2.Anchored = false
		end
	end
end
local function GetUniformScaleFromHumanoid(p1) --[[ GetUniformScaleFromHumanoid | Line: 74 ]]
	if not p1 then
		return 1
	end
	local BodyHeightScale = p1:FindFirstChild("BodyHeightScale")
	local BodyWidthScale = p1:FindFirstChild("BodyWidthScale")
	local BodyDepthScale = p1:FindFirstChild("BodyDepthScale")
	local v4 = (if BodyHeightScale then BodyHeightScale.Value or 1 else 1) * 0.5 + (BodyWidthScale and BodyWidthScale.Value or 1) * 0.25 + (BodyDepthScale and BodyDepthScale.Value or 1) * 0.25
	if v4 <= 0 then
		v4 = 1
	end
	return math.clamp(v4, 0.25, 4)
end
local function IsOverGuiObject() --[[ IsOverGuiObject | Line: 91 | Upvalues: UserInputService (copy), PlayerGui (copy) ]]
	local v1 = UserInputService:GetMouseLocation()
	return PlayerGui:GetGuiObjectsAtPosition(v1.X, v1.Y)
end
local function GetPieceByName(p1, p2) --[[ GetPieceByName | Line: 96 | Upvalues: t4 (copy), Outfit (copy) ]]
	for i = 1, #t4 do
		local v1 = Outfit:FindFirstChild(t4[i])
		if v1 then
			local v2 = v1:FindFirstChild(p1)
			if v2 then
				local v3 = v2:FindFirstChild(p2)
				if v3 then
					return v3:Clone()
				end
			end
		end
	end
	return nil
end
local function DisconnectIfExists(p1) --[[ DisconnectIfExists | Line: 112 ]]
	if not p1 then
		return nil
	end
	p1:Disconnect()
	return nil
end
local function CleanUp() --[[ CleanUp | Line: 119 | Upvalues: v4 (ref), v2 (ref), v3 (ref), Frames (copy), v7 (ref), v9 (ref), Terrain (copy), t2 (copy), v1 (copy), TweenService (copy), v10 (copy), v5 (ref) ]]
	v4 = true
	v2 = false
	v3 = nil
	Frames.Loadout.Points.Visible = false
	v7 = nil
	local v12 = v9
	if v12 then
		v12:Disconnect()
	end
	v9 = nil
	local MenuAssets = Terrain:FindFirstChild("MenuAssets")
	if MenuAssets then
		local Rig = MenuAssets:FindFirstChild("Rig")
		if Rig then
			local HumanoidRootPart = Rig:FindFirstChild("HumanoidRootPart")
			if HumanoidRootPart then
				HumanoidRootPart.CFrame = CFrame.new(617.035, 100.079, 3157.356) * CFrame.Angles(0, 1.5707963267948966, 0)
			end
		end
	end
	for k, v in pairs(Frames.Loadout.Points:GetChildren()) do
		v:SetAttribute("Click", false)
	end
	table.clear(t2)
	v1:DoCleaning()
	TweenService:Create(workspace.CurrentCamera, v10, {
		FieldOfView = 30
	}):Play()
	Frames.Loadout.SelectFrame.Visible = true
	Frames.Loadout.Outfit.Visible = false
	if not v5 or (not v5.TextLabel or v5.TextLabel.Text == "None") then
		return
	end
	local v22 = Frames.Loadout.Outfit:FindFirstChild(v5.TextLabel.Text)
	if v22 then
		v22.Visible = false
	end
	v5 = nil
end
local function UpdateVisibility() --[[ UpdateVisibility | Line: 159 | Upvalues: TeamsService (copy), LocalPlayer (copy), t (ref), t4 (copy), Outfit (copy), Frames (copy) ]]
	local v1 = TeamsService:GetPlayerTeam(LocalPlayer).Name
	print(t)
	for i = 1, #t4 do
		local v2 = t4[i]
		local v3 = t and t[v2]
		if v3 then
			local v4 = Outfit:FindFirstChild(v2)
			if v4 then
				for k, v in pairs(v4:GetChildren()) do
					local v5 = Frames.Loadout.Outfit:FindFirstChild(v.Name)
					if v5 then
						for k2, v6 in pairs(v3) do
							local v62 = v5:FindFirstChild(k2)
							if v62 then
								v62.Visible = v1 == v2
							end
						end
					end
				end
			end
		end
	end
end
local function Load() --[[ Load | Line: 185 | Upvalues: Packets (copy), v6 (ref), HttpService (copy), t3 (copy) ]]
	local v2 = Packets.ReturnSavedOutfits:Fire((tostring(v6)))
	if not v2 then
		return
	end
	local v3, v4 = pcall(HttpService.JSONDecode, HttpService, v2)
	if not (v3 and v4) then
		return
	end
	t3[v6] = v4
end
local function Save() --[[ Save | Line: 195 | Upvalues: HttpService (copy), t3 (copy), v6 (ref), Packets (copy) ]]
	local v1, v2 = pcall(HttpService.JSONEncode, HttpService, t3[v6])
	if not v1 then
		return
	end
	if Packets.SaveOutfit:Fire(tostring(v2), (tostring(v6))) then
		return
	end
	warn("Failed to save outfits")
end
local function LoadPieces() --[[ LoadPieces | Line: 206 | Upvalues: t3 (copy), v6 (ref), Packets (copy), Frames (copy), v8 (ref) ]]
	local v1 = t3[v6]
	if not v1 then
		return
	end
	for k, v in pairs(v1) do
		local v2 = if k == "Leg Accessoires" then "Leg-Accessoires" else k
		Packets.WearPiece:Fire(v, v2)
		workspace:SetAttribute(v2, v)
		local v3 = Frames.Loadout.Outfit:FindFirstChild(v2)
		if v3 then
			for k2, v4 in pairs(v3:GetChildren()) do
				if v4:IsA("Frame") and v4.Name == v then
					v4:SetAttribute("Pressed", true)
				end
			end
		end
	end
	if v8 ~= true then
		return
	end
	Packets.ToggleAccessoires:Fire(true)
end
local function UpdateBlobPositions() --[[ UpdateBlobPositions | Line: 234 | Upvalues: CurrentCamera (ref), t2 (copy) ]]
	local v1 = CurrentCamera
	for i = 1, #t2 do
		local v2 = t2[i]
		local Part = v2.Part
		local Frame = v2.Frame
		if Part and Part.Parent then
			local v3, v4 = v1:WorldToViewportPoint(Part.Position)
			Frame.Visible = v4
			if v4 then
				Frame.Position = UDim2.new(0, v3.X - Frame.AbsoluteSize.X * 0.5 - 15, 0, v3.Y - Frame.AbsoluteSize.Y * 0.5 + (tonumber(Frame:GetAttribute("Offset")) or 0))
			end
		end
	end
end
return {
	Once = function() --[[ Line: 254 | Upvalues: UpdateVisibility (copy), Packets (copy), v6 (ref), HttpService (copy), t3 (copy), LoadPieces (copy), t (ref), PurchaseConfirmation (copy), MarketplaceService (copy), LocalPlayer (copy), SoundService (copy), TeamsService (copy), ToggleAccessoires (copy), v8 (ref), Frames (copy), v5 (ref), t4 (copy), GetPieceByName (copy), GetUniformScaleFromHumanoid (copy), UnanchorAll (copy), TweenService (copy) ]]
		print("here")
		UpdateVisibility()
		task.spawn(function() --[[ Line: 258 | Upvalues: Packets (ref), v6 (ref), HttpService (ref), t3 (ref), LoadPieces (ref) ]]
			Packets.TeamService.OnClientEvent:Connect(function(p1, p2) --[[ Line: 259 | Upvalues: Packets (ref), v6 (ref), HttpService (ref), t3 (ref), LoadPieces (ref) ]]
				if p1 ~= "AddPlayerToTeam" then
					return
				end
				if p2 == "Neutral" then
					print("Joined neutral")
					return
				end
				local v2 = Packets.ReturnSavedOutfits:Fire((tostring(v6)))
				if v2 then
					local v3, v4 = pcall(HttpService.JSONDecode, HttpService, v2)
					if v3 and v4 then
						t3[v6] = v4
					end
				end
				v6 = 1
				task.wait(0.5)
				LoadPieces()
			end)
		end)
		for k, v in pairs(t3[v6]) do
			workspace:SetAttribute(k, "N/A")
		end
		t = Packets.ReturnOutfits:Fire(2)
		local v1
		if t then
			if type(t) ~= "table" then
				repeat
					repeat
						t = Packets.ReturnOutfits:Fire(1)
						task.wait(0.5)
					until t
					v1 = t
				until type(t) == "table" and (t["Blue Unit"] and t["Red Unit"])
			end
		else
			repeat
				repeat
					t = Packets.ReturnOutfits:Fire(1)
					task.wait(0.5)
				until t
				v1 = t
			until type(t) == "table" and (t["Blue Unit"] and t["Red Unit"])
		end
		Packets.TeamService.OnClientEvent:Connect(function() --[[ Line: 284 | Upvalues: UpdateVisibility (ref) ]]
			UpdateVisibility()
		end)
		PurchaseConfirmation.Buy.Button.Activated:Connect(function() --[[ Line: 288 | Upvalues: PurchaseConfirmation (ref), Packets (ref), MarketplaceService (ref), LocalPlayer (ref), SoundService (ref), TeamsService (ref), t (ref) ]]
			local v1 = workspace:GetAttribute("ToBuy")
			if v1 == "" then
				return
			end
			if PurchaseConfirmation:GetAttribute("Type") ~= "Outfit" then
				return
			end
			if Packets.PurchaseOutfit:Fire(v1) == false then
				MarketplaceService:PromptProductPurchase(LocalPlayer, 3506671887)
				SoundService.Menu.Error:Play()
				return
			end
			SoundService.Menu.Buy:Play()
			local v2 = TeamsService:GetPlayerTeam(LocalPlayer).Name
			if not (v2 and (t[v2] and t[v2][v1])) then
				workspace:SetAttribute("ToBuy", "")
				task.wait(0.3)
				PurchaseConfirmation.Visible = false
				return
			end
			t[v2][v1].Owned = true
			workspace:SetAttribute("ToBuy", "")
			task.wait(0.3)
			PurchaseConfirmation.Visible = false
		end)
		ToggleAccessoires.Activated:Connect(function() --[[ Line: 312 | Upvalues: v8 (ref), ToggleAccessoires (ref), Packets (ref) ]]
			v8 = not v8
			ToggleAccessoires.Label.Text = if v8 == true then "RESTORE ACCESSOIRES" else "REMOVE ACCESSOIRES"
			Packets.ToggleAccessoires:Fire(v8)
		end)
		Frames.Loadout.Outfit.Back.Button.Activated:Connect(function() --[[ Line: 318 | Upvalues: v5 (ref), Frames (ref) ]]
			if v5 then
				local v1 = Frames.Loadout.Outfit:FindFirstChild(v5.TextLabel.Text)
				if v1 then
					v1.Visible = false
				end
				v5 = nil
			end
			Frames.Loadout.Outfit.Visible = false
			Frames.Loadout.Points.Visible = true
			Frames.Loadout.SelectFrame.Visible = true
		end)
		for i = 1, #t4 do
			local v3 = t4[i]
			if not t[v3] then
				t[v3] = {}
			end
			for k, v in pairs(t[v3]) do
				if v and v.Type then
					local v4 = script.Template:Clone()
					v4.Parent = Frames.Loadout.Outfit[v.Type]
					v4:SetAttribute("Pressed", false)
					v4.Visible = TeamsService:GetPlayerTeam(LocalPlayer).Name == v3
					v4.Name = k
					local Rig = v4.ViewportFrame.Rig
					local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
					local UpperTorso = Rig.UpperTorso
					if v.Type == "Helmets" or v.Type == "Accessories" then
						UpperTorso = Rig.Head
						Rig:PivotTo(Rig:GetPivot() * CFrame.new(0, -1, 0))
					end
					local v52 = GetPieceByName(v.Type, k)
					if v52 then
						v52.Parent = Rig
						if v.Type == "Shirt" or v.Type == "Pants" then
							local v62 = v52:FindFirstChildOfClass("Shirt") or v52:FindFirstChildOfClass("Pants")
							if v62 then
								v62.Parent = Rig
							end
						else
							local Middle = v52:FindFirstChild("Middle")
							if Middle then
								v52.PrimaryPart = Middle
								Middle.Transparency = 1
								local v7 = CFrame.new()
								v52:PivotTo(UpperTorso.CFrame * v7)
								local v82 = GetUniformScaleFromHumanoid(Humanoid)
								if math.abs(v82 - 1) > 0.001 then
									pcall(function() --[[ Line: 378 | Upvalues: v52 (copy), v82 (copy) ]]
										v52:ScaleTo(v82)
									end)
									v52:PivotTo(UpperTorso.CFrame * v7)
								end
								local WeldConstraint = Instance.new("WeldConstraint")
								WeldConstraint.Part0 = UpperTorso
								WeldConstraint.Part1 = Middle
								WeldConstraint.Parent = Middle
								UnanchorAll(v52)
								Middle.Anchored = false
							end
						end
						v4:FindFirstChild("Name").Text = k
						v4:FindFirstChild("Type").Text = string.upper(v.Type)
						v4.Button.Activated:Connect(function() --[[ Line: 395 | Upvalues: TeamsService (ref), LocalPlayer (ref), t (ref), k (copy), PurchaseConfirmation (ref), TweenService (ref), SoundService (ref), v4 (copy), Packets (ref), v (copy), t3 (ref), v6 (ref), HttpService (ref), Frames (ref) ]]
							local v1 = TeamsService:GetPlayerTeam(LocalPlayer).Name
							local v2 = if v1 then t[v1] and t[v1][k] else v1
							if v2 and v2.Owned ~= false then
								local v3 = v4:GetAttribute("Pressed") == true
								if (v3 and Packets.WearPiece:Fire("Unequip", v.Type) or Packets.WearPiece:Fire(k, v.Type)) == false then
									SoundService.Menu.Error:Play()
									return
								end
								local v5 = not v3
								t3[v6][v.Type] = if v5 then k or nil else nil
								local v8, v9 = pcall(HttpService.JSONEncode, HttpService, t3[v6])
								if v8 and not Packets.SaveOutfit:Fire(tostring(v9), (tostring(v6))) then
									warn("Failed to save outfits")
								end
								for k2, v10 in pairs(Frames.Loadout.Outfit[v.Type]:GetChildren()) do
									if v10:IsA("Frame") and (v10 ~= v4 and v10:GetAttribute("Pressed") == true) then
										v10:SetAttribute("Pressed", false)
									end
								end
								SoundService.Menu.Select:Play()
								v4:SetAttribute("Pressed", v5)
								workspace:SetAttribute(v.Type, if v5 then k or "" else "")
							else
								PurchaseConfirmation:SetAttribute("Type", "Outfit")
								workspace:SetAttribute("ToBuy", k)
								PurchaseConfirmation.Visible = true
								TweenService:Create(PurchaseConfirmation, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									Position = UDim2.new(0.5, 0, 0.5, 0)
								}):Play()
								local v13 = if v2 then v2.Price or 0 else 0
								PurchaseConfirmation:FindFirstChild("Info").Text = string.format("Are u sure u want to purchase %s for %d$?", k, v13)
								SoundService.Menu.Error:Play()
							end
						end)
					end
				end
			end
		end
		LocalPlayer.CharacterAdded:Connect(function() --[[ Line: 438 | Upvalues: LoadPieces (ref) ]]
			task.delay(0.5, LoadPieces)
		end)
	end,
	Start = function() --[[ Line: 443 | Upvalues: Terrain (copy), CleanUp (copy), UpdateVisibility (copy), CurrentCamera (ref), Frames (copy), v4 (ref), LocalPlayer (copy), v1 (copy), TweenService (copy), v10 (copy), v5 (ref), v11 (copy), v2 (ref), v3 (ref), v7 (ref), t2 (copy), v12 (copy), v9 (ref), RunService (copy), UpdateBlobPositions (copy) ]]
		Terrain:WaitForChild("MenuAssets"):WaitForChild("Rig"):WaitForChild("HumanoidRootPart")
		CleanUp()
		UpdateVisibility()
		CurrentCamera = workspace.CurrentCamera
		Frames.Loadout.Points.Visible = true
		v4 = false
		local Character = LocalPlayer.Character
		if not Character then
			return
		end
		local Game = Instance.new("Highlight")
		Game.Name = "Game"
		Game.Parent = Character
		Game.Adornee = Character
		Game.FillTransparency = 1
		Game.OutlineTransparency = 1
		Game.OutlineColor = Color3.fromRGB(255, 255, 255)
		v1:GiveTask(Game)
		TweenService:Create(workspace.CurrentCamera, v10, {
			FieldOfView = 26
		}):Play()
		local Points = Frames.Loadout.Points
		for k, v in pairs(Character:GetChildren()) do
			for k2, v6 in pairs(Points:GetChildren()) do
				if v6.Name == v.Name then
					v1:GiveTask(v6.Button.Activated:Connect(function() --[[ Line: 475 | Upvalues: v5 (ref), v6 (copy), Frames (ref), TweenService (ref), Game (copy), v11 (ref) ]]
						if v5 == v6 then
							local v1 = Frames.Loadout.Outfit:FindFirstChild(v5.TextLabel.Text)
							if not v1 then
								Frames.Loadout.Outfit.Visible = false
								Frames.Loadout.SelectFrame.Visible = true
								TweenService:Create(Game, v11, {
									OutlineTransparency = 1
								}):Play()
								task.wait(0.35)
								v5 = nil
								return
							end
							v1.Visible = false
							Frames.Loadout.Outfit.Visible = false
							Frames.Loadout.SelectFrame.Visible = true
							TweenService:Create(Game, v11, {
								OutlineTransparency = 1
							}):Play()
							task.wait(0.35)
							v5 = nil
						else
							if v5 then
								local v2 = Frames.Loadout.Outfit:FindFirstChild(v5.TextLabel.Text)
								if v2 then
									v2.Visible = false
								end
							end
							v5 = v6
							Frames.Loadout.Outfit.Visible = true
							Frames.Loadout.SelectFrame.Visible = false
							local v3 = Frames.Loadout.Outfit:FindFirstChild(v6.TextLabel.Text)
							if not v3 then
								TweenService:Create(Game, v11, {
									OutlineTransparency = 0
								}):Play()
								return
							end
							v3.Visible = true
							TweenService:Create(Game, v11, {
								OutlineTransparency = 0
							}):Play()
						end
					end))
					v1:GiveTask(v6.Button.MouseEnter:Connect(function() --[[ Line: 510 | Upvalues: v2 (ref), v3 (ref), v6 (copy), v7 (ref), Frames (ref), TweenService (ref), Game (copy), v11 (ref) ]]
						v2 = true
						v3 = v6
						v7 = Frames.Loadout.Outfit:FindFirstChild(v6.TextLabel.Text)
						TweenService:Create(Game, v11, {
							OutlineTransparency = 0
						}):Play()
						TweenService:Create(v6.TextLabel.UIScale, v11, {
							Scale = 1
						}):Play()
					end))
					v1:GiveTask(v6.Button.MouseLeave:Connect(function() --[[ Line: 518 | Upvalues: v6 (copy), TweenService (ref), Game (copy), v11 (ref), v2 (ref), v3 (ref) ]]
						if v6:GetAttribute("Click") ~= true then
							TweenService:Create(Game, v11, {
								OutlineTransparency = 1
							}):Play()
							TweenService:Create(v6.TextLabel.UIScale, v11, {
								Scale = 0
							}):Play()
							v2 = false
							v3 = nil
						end
					end))
					table.insert(t2, {
						Part = v,
						Frame = v6
					})
				end
			end
		end
		task.defer(function() --[[ Line: 531 | Upvalues: v4 (ref), t2 (ref), TweenService (ref), v12 (ref) ]]
			local v1 = UDim2.new(1.383, 0, 1.383, 0)
			local v2 = UDim2.new(0, 0, 0, 0)
			while not v4 do
				for i = 1, #t2 do
					local v3 = t2[i]
					if v3.Frame:GetAttribute("Click") == false then
						local Drop = v3.Frame.Drop
						Drop.Visible = true
						TweenService:Create(Drop, v12, {
							Size = v2
						}):Play()
						task.delay(0.5, function() --[[ Line: 542 | Upvalues: Drop (copy), v1 (copy) ]]
							Drop.Visible = false
							Drop.Size = v1
						end)
					end
				end
				task.wait(2)
			end
		end)
		v9 = RunService.RenderStepped:Connect(UpdateBlobPositions)
		task.delay(0.5, function() --[[ Line: 554 | Upvalues: v9 (ref) ]]
			local v1 = v9
			if v1 then
				v1:Disconnect()
			end
			v9 = nil
		end)
	end,
	End = function() --[[ Line: 559 | Upvalues: CleanUp (copy) ]]
		CleanUp()
	end
}