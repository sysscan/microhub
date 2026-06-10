-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local GroupService = game:GetService("GroupService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Client = Framework:WaitForChild("Models"):WaitForChild("Client")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local RippleAPI = require(ReplicatedStorage:WaitForChild("Game").Modules.RippleAPI)
local Notify = require(ReplicatedStorage.Game.Modules:WaitForChild("Notify"))
local Outfit = require(script.Parent.Outfit)
local ViewportManager = require(ReplicatedStorage.Game.Modules:WaitForChild("ViewportManager"))
local AttachmentsHandler = require(Framework:WaitForChild("Modules"):WaitForChild("AttachmentsHandler"))
local Canvas = PlayerGui:WaitForChild("Main"):WaitForChild("Canvas")
local Frames = Canvas:WaitForChild("Frames")
local Info = Canvas.Profile.Info
local PurchaseConfirmation = Frames.Loadout.PurchaseConfirmation
local SellConfirmation = Frames.Loadout.SellConfirmation
local Config = require(ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Config"))
local t = { "Primary", "Secondary", "Equipment" }
local t2 = { "Primary", "Secondary", "Equipment", "DroneCustomization" }
local v1 = TweenInfo.new(0.2)
TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
RunService:IsStudio()
local v2 = nil
local v3 = 1
local t3 = {
	{
		Primary = nil,
		Secondary = nil,
		Equipment = nil
	}
}
local v4 = nil
local Animation = Instance.new("Animation")
Animation.AnimationId = "rbxassetid://72893624490932"
local Animation_2 = Instance.new("Animation")
Animation_2.AnimationId = "rbxassetid://84341266924757"
local Animation_3 = Instance.new("Animation")
Animation_3.AnimationId = "rbxassetid://85554574022210"
local Animation_4 = Instance.new("Animation")
Animation_4.AnimationId = "rbxassetid://111530251970154"
local function TweenProperty(p1, p2, p3) --[[ TweenProperty | Line: 66 | Upvalues: TweenService (copy), v1 (copy) ]]
	TweenService:Create(p1, if p3 then p3 else v1, p2):Play()
end
local function CharacterHandle() --[[ CharacterHandle | Line: 70 | Upvalues: LocalPlayer (copy), v4 (ref), Client (copy), Animation (copy), Animation_2 (copy), Animation_3 (copy), Animation_4 (copy) ]]
	local v1 = workspace:GetAttribute("InMenu")
	local Character = LocalPlayer.Character
	if not Character then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not (Humanoid and Humanoid.Health > 0) then
		return
	end
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if Animator then
		for i, v in ipairs(Animator:GetPlayingAnimationTracks()) do
			v:Stop(0.2)
		end
	end
	if v4 then
		v4:Stop(0.2)
		v4 = nil
	end
	for k, v in pairs({
		Character:FindFirstChild("RightHand"),
		Character:FindFirstChild("Head"),
		Character:FindFirstChild("UpperTorso"),
		Character:FindFirstChild("Torso")
	}) do
		if v then
			for k2, v2 in pairs(v:GetChildren()) do
				if v2:IsA("Model") then
					v2:Destroy()
				end
			end
		end
	end
	if not v1 then
		return
	end
	local v2 = workspace:GetAttribute("Previewing") or "None"
	local v3 = workspace:GetAttribute(v2)
	if not v3 or (v3 == "N/A" or v3 == "") then
		return
	end
	local v42 = Client:FindFirstChild((tostring(v3)))
	if not v42 then
		return
	end
	local v5 = v42:Clone()
	local v6 = nil
	local v7 = nil
	if v2 == "Primary" then
		local RightHand = Character:FindFirstChild("RightHand")
		v7 = Animation
		v6 = RightHand
	elseif v2 == "Secondary" then
		local RightHand = Character:FindFirstChild("RightHand")
		v7 = Animation_2
		v6 = RightHand
	elseif v2 == "Equipment" then
		local v8 = string.lower(v3)
		if string.find(v8, "helmet") or (string.find(v8, "mask") or string.find(v8, "hat")) then
			local Head = Character:FindFirstChild("Head")
			v7 = Animation_3
			v6 = Head
		else
			v7 = Animation_4
			v6 = Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso")
		end
	end
	if not v6 then
		return
	end
	v5.Parent = v6
	v5:PivotTo(v6:GetPivot())
	local v10 = v5:FindFirstChild("Handle") or v5.PrimaryPart or v5:FindFirstChildWhichIsA("BasePart")
	if v10 then
		local Motor6D = Instance.new("Motor6D")
		Motor6D.Part0 = v6
		Motor6D.Part1 = v10
		Motor6D.Parent = v5
		v10.Anchored = false
		if v7 and Animator then
			v4 = Animator:LoadAnimation(v7)
			v4:Play(0)
		end
	end
	for k, v in pairs(v5:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = false
		end
	end
end
local function PlayOutfitAnimation(p1) --[[ PlayOutfitAnimation | Line: 165 | Upvalues: LocalPlayer (copy), v4 (ref) ]]
	local Character = LocalPlayer.Character
	if not Character then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not (Humanoid and Humanoid.Health > 0) then
		return
	end
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		return
	end
	if v4 then
		v4:Stop(0)
		v4 = nil
	end
	for i, v in ipairs(Animator:GetPlayingAnimationTracks()) do
		v:Stop(0)
	end
	v4 = Animator:LoadAnimation(p1)
	v4:Play(0)
end
local function LoadLoadout() --[[ LoadLoadout | Line: 188 | Upvalues: Packets (copy), v3 (ref), HttpService (copy), t3 (copy) ]]
	local v2 = Packets.ReturnLoadout:Fire((tostring(v3)))
	if type(v2) == "string" and v2 ~= "" then
		local v32, v4 = pcall(function() --[[ Line: 192 | Upvalues: HttpService (ref), v2 (copy) ]]
			return HttpService:JSONDecode(v2)
		end)
		if v32 and type(v4) == "table" then
			t3[v3] = v4
		else
			t3[v3] = {
				Primary = "AK-74",
				Secondary = nil,
				Equipment = nil
			}
		end
	else
		t3[v3] = {
			Primary = "AK-74",
			Secondary = nil,
			Equipment = nil
		}
	end
	if t3[v3].Primary and (t3[v3].Primary ~= "N/A" and t3[v3].Primary ~= "") then
		return
	end
	t3[v3].Primary = "AK-74"
end
local function SaveLoadout() --[[ SaveLoadout | Line: 221 | Upvalues: HttpService (copy), t3 (copy), v3 (ref), Packets (copy) ]]
	Packets.SaveLoadout:Fire(tostring((HttpService:JSONEncode(t3[v3]))), (tostring(v3)))
end
local function RefreshLoadout() --[[ RefreshLoadout | Line: 226 | Upvalues: t (copy), Frames (copy), t3 (copy), v3 (ref) ]]
	for k, v in pairs(t) do
		local v1 = t3[v3][v]
		for k2, v2 in pairs(Frames.Loadout[v].ScrollingFrame:GetChildren()) do
			if v2:IsA("Frame") then
				v2:SetAttribute("Pressed", v1 == v2.Name)
			end
		end
		workspace:SetAttribute(v, v1 or "N/A")
	end
end
local function UpdateSelectViewport(p1, p2) --[[ UpdateSelectViewport | Line: 241 | Upvalues: Frames (copy), Client (copy), ReplicatedStorage (copy), ViewportManager (copy) ]]
	local v1 = Frames.Loadout.SelectFrame:FindFirstChild(p1)
	if not v1 then
		return
	end
	local ViewportFrame = v1:FindFirstChild("ViewportFrame")
	local Button = v1:FindFirstChild("Button")
	if ViewportFrame and Button and (p2 and (p2 ~= "N/A" and p2 ~= "")) then
		local v2 = Client:FindFirstChild(p2)
		if p1 == "DroneCustomization" then
			local DroneSystem = ReplicatedStorage:FindFirstChild("DroneSystem")
			if DroneSystem then
				local Attachments = DroneSystem:FindFirstChild("Attachments")
				if Attachments then
					v2 = Attachments:FindFirstChild(p2)
				end
			end
		end
		if v2 then
			ViewportManager:Create(v2, ViewportFrame, Button)
		end
	elseif ViewportFrame and Button then
		ViewportManager:Clear(ViewportFrame)
	end
	local Gun = v1:FindFirstChild("Gun")
	if not Gun then
		return
	end
	Gun.Text = if p2 == "N/A" or p2 == "" then "None" else p2
end
local function SetupWeaponButton(p1, p2, p3, p4) --[[ SetupWeaponButton | Line: 275 | Upvalues: Config (copy), TweenService (copy), Info (copy), t3 (copy), v3 (ref), Notify (copy), SellConfirmation (copy), AttachmentsHandler (copy), LocalPlayer (copy), PurchaseConfirmation (copy), SoundService (copy), GroupService (copy), RippleAPI (copy), Client (copy), Frames (copy), HttpService (copy), Packets (copy), ViewportManager (copy), Framework (copy) ]]
	local v1 = script.TemplateWeapon:Clone()
	v1.Name = p1
	v1.Parent = p4
	v1:SetAttribute("Pressed", false)
	v1:FindFirstChild("Gun").Text = p1
	v1.Price.Text = "$" .. p2.Price
	v1.Level.Text = "LEVEL " .. p2.Level
	local Stats = v1:FindFirstChild("Stats")
	Stats.Gun.Text = p1
	Stats.AmmoType.Text = p2.Settings.BulletType or "N/A"
	Stats.FireRate.Text = "Firerate: " .. (p2.Settings.FireRate or "N/A") or "N/A"
	Stats["Muzzle Velocity"].Text = "Muzzle Velocity: " .. (p2.Settings.BSpeed or "1500") or "1500"
	pcall(function() --[[ Line: 293 | Upvalues: Stats (copy), Config (ref), p2 (copy) ]]
		Stats.LegsDamage.Text = "Legs Damage: " .. Config.BulletTypeDamage[p2.Settings.BulletType].Legs or "N/A"
		Stats.HeadDamage.Text = "Head Damage: " .. Config.BulletTypeDamage[p2.Settings.BulletType].Head or "N/A"
		Stats.TorsoDamage.Text = "Torso Damage: " .. Config.BulletTypeDamage[p2.Settings.BulletType].Torso or "N/A"
		Stats.ArmsDamage.Text = "Arms Damage: " .. Config.BulletTypeDamage[p2.Settings.BulletType].Arms or "N/A"
	end)
	local Sell = v1:FindFirstChild("Sell")
	local Edit = v1:FindFirstChild("Edit")
	if not p2.Owned and p1 == "G3A3" then
		p2.CantBuy = true
		v1.Price.Text = "JOIN OUR COMMUNITY"
		TweenService:Create(v1.Price, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			TextColor3 = Color3.fromRGB(255, 60, 60)
		}):Play()
	end
	p2.LevelUnlocked = false
	if not p2.Level then
		v1.Visible = false
		return
	end
	local v4 = (tonumber(p2.Level) or 0) * 1000000
	v1.LayoutOrder = v4 + (tonumber(p2.Price) or 0)
	if Info.Level.Text == "/" then
		repeat
			task.wait()
		until Info.Level.Text ~= "/"
	end
	local v5 = tonumber(Info.Level.Text)
	if p2.Level == 0 or v5 and p2.Level <= v5 then
		p2.LevelUnlocked = true
	end
	p2.TemplateInstance = v1
	v1.Price.Visible = p2.LevelUnlocked
	v1.Level.Visible = not p2.LevelUnlocked
	if t3[v3][p3] == p1 then
		v1:SetAttribute("Pressed", true)
	end
	Sell.ZIndex = 10
	Sell.Activated:Connect(function() --[[ Line: 343 | Upvalues: p2 (copy), p1 (copy), Notify (ref), p3 (copy), SellConfirmation (ref) ]]
		if not p2.Owned then
			print("Weapon not owned")
			return
		end
		if p1 == "AK-74" then
			Notify("Sell Weapon", "You cannot sell the default weapon!", 3)
		else
			workspace:SetAttribute("ToSell", p1)
			workspace:SetAttribute("SellWeaponType", p3)
			SellConfirmation.Visible = true
			local Info = SellConfirmation:FindFirstChild("Info")
			Info.Text = string.format("Are you sure you want to sell %s for $%d?", p1, (math.round(p2.Price / 3)))
		end
	end)
	if AttachmentsHandler:CanEditWeapon(p1) then
		Edit.Visible = true
	else
		Edit.Visible = false
	end
	Edit.Activated:Connect(function() --[[ Line: 366 | Upvalues: p2 (copy), AttachmentsHandler (ref), p1 (copy), LocalPlayer (ref) ]]
		if not p2.Owned then
			return
		end
		if AttachmentsHandler:CanEditWeapon(p1) then
			AttachmentsHandler:loadgun(LocalPlayer, p1)
		end
	end)
	v1.Button.MouseEnter:Connect(function() --[[ Line: 372 | Upvalues: TweenService (ref), Stats (copy) ]]
		TweenService:Create(Stats, TweenInfo.new(0.3), {
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()
	end)
	v1.Button.MouseLeave:Connect(function() --[[ Line: 376 | Upvalues: TweenService (ref), Stats (copy) ]]
		TweenService:Create(Stats, TweenInfo.new(0.3), {
			Position = UDim2.new(0, 0, 1, 0)
		}):Play()
	end)
	v1.Button.Activated:Connect(function() --[[ Line: 380 | Upvalues: p2 (copy), Notify (ref), p1 (copy), PurchaseConfirmation (ref), SoundService (ref), LocalPlayer (ref), GroupService (ref), RippleAPI (ref), v1 (copy), p4 (copy), p3 (copy), t3 (ref), v3 (ref), Client (ref), Frames (ref), HttpService (ref), Packets (ref) ]]
		if not p2.LevelUnlocked then
			Notify("Loadout", "You have not reached the level to unlock this weapon!", 4)
			return
		end
		if not (p2.Owned or p2.CantBuy) then
			workspace:SetAttribute("ToBuy", p1)
			PurchaseConfirmation:SetAttribute("Type", "Loadout")
			PurchaseConfirmation.Visible = true
			PurchaseConfirmation.Info.Text = string.format("Are you sure you want to purchase %s for $%d?", p1, p2.Price)
			SoundService.Menu.Error:Play()
			return
		end
		if p2.CantBuy and not LocalPlayer:IsInGroup(1029859683) then
			Notify("Loadout", "Join the C:\\GamesGames\\ roblox group!", 3)
			local v12, v2 = pcall(function() --[[ Line: 399 | Upvalues: GroupService (ref) ]]
				GroupService:PromptJoinAsync(1029859683)
			end)
			if not v12 or v2 ~= Enum.GroupMembershipStatus.Joined then
				return
			end
			Notify("Loadout", "Thank you!", 3)
			p2.CantBuy = false
		else
			RippleAPI.RoundRipple(v1, Color3.fromRGB(255, 255, 255), 0.7, 0.3)
			SoundService.Menu.Select:Play()
			for i, v in ipairs(p4:GetChildren()) do
				if v:IsA("ImageButton") and v ~= v1 then
					v:SetAttribute("Pressed", false)
				end
			end
			local v32 = not v1:GetAttribute("Pressed")
			v1:SetAttribute("Pressed", v32)
			if v32 or p3 ~= "Primary" then
				t3[v3][p3] = if v32 then v1.Name or nil else nil
				workspace:SetAttribute(p3, if v32 then v1.Name or "N/A" else "N/A")
			else
				t3[v3][p3] = "AK-74"
				workspace:SetAttribute(p3, "AK-74")
			end
			local v10 = Client:FindFirstChild(p1)
			local v11 = Frames.Loadout.Primary:FindFirstChild("EditAttachments") or Frames.Loadout.Secondary:FindFirstChild("EditAttachments")
			if v11 then
				v11.Visible = if v10 then v10:FindFirstChild("Attachments") ~= nil else v10
			end
			local v13
			if p2.Owned then
				v1.Price.Text = "Owned"
			end
			v13 = HttpService:JSONEncode(t3[v3])
			Packets.SaveLoadout:Fire(tostring(v13), (tostring(v3)))
		end
	end)
	local v6 = Client:FindFirstChild(p1)
	local ViewportFrame = v1:FindFirstChild("ViewportFrame")
	if ViewportFrame and v6 then
		ViewportManager:Create(v6, ViewportFrame, (v1:FindFirstChild("Button")))
	end
	Framework.Remotes.um.OnClientEvent:Connect(function(p12) --[[ Line: 454 | Upvalues: p1 (copy), Client (ref), v1 (copy), ViewportManager (ref) ]]
		if tostring(p12) ~= p1 then
			return
		end
		local v12 = Client:FindFirstChild(p1)
		local ViewportFrame = v1:FindFirstChild("ViewportFrame")
		if not (ViewportFrame and v12) then
			return
		end
		ViewportManager:Create(v12, ViewportFrame, (v1:FindFirstChild("Button")))
	end)
	if p2.Owned then
		v1.Price.Text = "Owned"
		v1.Sell.Visible = true
	end
	return v1
end
local function SetupDroneAttachmentButton(p1, p2) --[[ SetupDroneAttachmentButton | Line: 473 | Upvalues: Packets (copy), RippleAPI (copy), SoundService (copy), ViewportManager (copy) ]]
	local v1 = script.TemplateWeapon:Clone()
	v1.Name = p1.Name
	v1.Parent = p2
	v1:SetAttribute("Pressed", false)
	local Gun = v1:FindFirstChild("Gun")
	if Gun then
		Gun.Text = p1.Name
	end
	local Price = v1:FindFirstChild("Price")
	if Price then
		Price.Text = "Owned"
		Price.Visible = true
	end
	local Level = v1:FindFirstChild("Level")
	if Level then
		Level.Visible = false
	end
	local Sell = v1:FindFirstChild("Sell")
	if Sell then
		Sell.Visible = false
	end
	v1.Visible = true
	if workspace:GetAttribute("SelectedDroneAttachment") == p1.Name then
		v1:SetAttribute("Pressed", true)
	end
	v1.Button.Activated:Connect(function() --[[ Line: 506 | Upvalues: p1 (copy), Packets (ref), p2 (copy), v1 (copy), RippleAPI (ref), SoundService (ref) ]]
		if workspace:GetAttribute("SelectedDroneAttachment") == p1.Name then
			return
		end
		workspace:SetAttribute("SelectedDroneAttachment", p1.Name)
		Packets.DroneDataAction:Fire("Save", {
			FPV = p1.Name,
			MAVIC = p1.Name
		})
		for i, v in ipairs(p2:GetChildren()) do
			if v:IsA("Frame") or v:IsA("ImageButton") then
				v:SetAttribute("Pressed", false)
			end
		end
		v1:SetAttribute("Pressed", true)
		RippleAPI.RoundRipple(v1, Color3.fromRGB(255, 255, 255), 0.7, 0.3)
		SoundService.Menu.Select:Play()
	end)
	local ViewportFrame = v1:FindFirstChild("ViewportFrame")
	if ViewportFrame then
		ViewportManager:Create(p1, ViewportFrame, (v1:FindFirstChild("Button")))
	end
	return v1
end
return function() --[[ Line: 533 | Upvalues: v3 (ref), LoadLoadout (copy), v2 (ref), Packets (copy), t3 (copy), Client (copy), Frames (copy), RefreshLoadout (copy), Framework (copy), CharacterHandle (copy), Outfit (copy), t (copy), UpdateSelectViewport (copy), PlayOutfitAnimation (copy), Animation_3 (copy), Animation_4 (copy), Info (copy), SellConfirmation (copy), PurchaseConfirmation (copy), Notify (copy), MarketplaceService (copy), LocalPlayer (copy), SoundService (copy), t2 (copy), TweenService (copy), SetupWeaponButton (copy), ReplicatedStorage (copy), SetupDroneAttachmentButton (copy) ]]
	workspace:SetAttribute("SelectedDroneAttachment", "Rocket")
	workspace:SetAttribute("Previewing", "None")
	v3 = 1
	LoadLoadout()
	v2 = Packets.ReturnWeapons:Fire()
	workspace:SetAttribute("Primary", t3[v3].Primary)
	workspace:SetAttribute("Secondary", t3[v3].Secondary or "N/A")
	workspace:SetAttribute("Equipment", t3[v3].Equipment or "N/A")
	task.spawn(function() --[[ Line: 546 | Upvalues: Packets (ref) ]]
		local v1 = Packets.DroneDataAction:Fire("Retrieve", "")
		if type(v1) ~= "table" or not v1.FPV then
			return
		end
		workspace:SetAttribute("SelectedDroneAttachment", v1.FPV)
	end)
	task.spawn(function() --[[ Line: 553 | Upvalues: Packets (ref), LoadLoadout (ref), t3 (ref), v3 (ref), Client (ref), Frames (ref), RefreshLoadout (ref) ]]
		Packets.TeamService.OnClientEvent:Connect(function(p1, p2) --[[ Line: 554 | Upvalues: LoadLoadout (ref), t3 (ref), v3 (ref), Client (ref), Frames (ref), RefreshLoadout (ref) ]]
			if p1 ~= "AddPlayerToTeam" then
				return
			end
			if p2 == "Neutral" then
				return
			end
			LoadLoadout()
			local Primary = t3[v3].Primary
			workspace:SetAttribute("Primary", Primary)
			local v1 = Client:FindFirstChild(Primary)
			local v2 = Frames.Loadout.Primary:FindFirstChild("EditAttachments") or Frames.Loadout.Secondary:FindFirstChild("EditAttachments")
			if v2 then
				v2.Visible = if v1 then v1:FindFirstChild("Attachments") ~= nil else v1
			end
			task.delay(0.5, function() --[[ Line: 571 | Upvalues: RefreshLoadout (ref) ]]
				RefreshLoadout()
			end)
		end)
	end)
	Framework.Remotes.um.OnClientEvent:Connect(function() --[[ Line: 578 | Upvalues: CharacterHandle (ref) ]]
		CharacterHandle()
	end)
	workspace:GetAttributeChangedSignal("CurrentWindow"):Connect(function() --[[ Line: 582 | Upvalues: Frames (ref), Outfit (ref) ]]
		if workspace:GetAttribute("CurrentWindow") == "Loadout" then
			local Primary = Frames.Loadout.SelectFrame:FindFirstChild("Primary")
			if Primary and Primary.Visible then
				Outfit.Start()
			end
		else
			Outfit.End()
		end
	end)
	for k, v in pairs(t) do
		workspace:GetAttributeChangedSignal(v):Connect(function() --[[ Line: 594 | Upvalues: v (copy), UpdateSelectViewport (ref), CharacterHandle (ref) ]]
			UpdateSelectViewport(v, (workspace:GetAttribute(v)))
			if workspace:GetAttribute("Previewing") ~= v then
				return
			end
			CharacterHandle()
		end)
	end
	workspace:GetAttributeChangedSignal("SelectedDroneAttachment"):Connect(function() --[[ Line: 603 | Upvalues: UpdateSelectViewport (ref), Frames (ref) ]]
		local v1 = workspace:GetAttribute("SelectedDroneAttachment")
		UpdateSelectViewport("DroneCustomization", v1)
		local DroneCustomization = Frames.Loadout:FindFirstChild("DroneCustomization")
		if not DroneCustomization then
			return
		end
		local ScrollingFrame = DroneCustomization:FindFirstChild("ScrollingFrame")
		if not ScrollingFrame then
			return
		end
		for i, v in ipairs(ScrollingFrame:GetChildren()) do
			if v:IsA("Frame") and v.Name ~= "GoBack" then
				v:SetAttribute("Pressed", v.Name == v1)
			end
		end
	end)
	workspace:GetAttributeChangedSignal("Helmets"):Connect(function() --[[ Line: 620 | Upvalues: PlayOutfitAnimation (ref), Animation_3 (ref) ]]
		local v1 = workspace:GetAttribute("Helmets")
		if not v1 or (v1 == "N/A" or v1 == "") then
			return
		end
		PlayOutfitAnimation(Animation_3)
	end)
	workspace:GetAttributeChangedSignal("Vests"):Connect(function() --[[ Line: 627 | Upvalues: PlayOutfitAnimation (ref), Animation_4 (ref) ]]
		local v1 = workspace:GetAttribute("Vests")
		if not v1 or (v1 == "N/A" or v1 == "") then
			return
		end
		PlayOutfitAnimation(Animation_4)
	end)
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 634 | Upvalues: CharacterHandle (ref) ]]
		CharacterHandle()
	end)
	local v1
	if v2 then
		if type(v2) ~= "table" or next(v2) == nil then
			repeat
				repeat
					v2 = Packets.ReturnWeapons:Fire()
					task.wait(0.5)
				until v2
				v1 = v2
			until type(v2) == "table" and next(v2) ~= nil
		end
	else
		repeat
			repeat
				v2 = Packets.ReturnWeapons:Fire()
				task.wait(0.5)
			until v2
			v1 = v2
		until type(v2) == "table" and next(v2) ~= nil
	end
	Info.Level:GetPropertyChangedSignal("Text"):Connect(function() --[[ Line: 645 | Upvalues: Info (ref), v2 (ref) ]]
		local v1 = tonumber(Info.Level.Text)
		if not v1 then
			return
		end
		for k, v in pairs(v2) do
			if v and (v.Level and (v.Level <= v1 and v.TemplateInstance)) then
				v.LevelUnlocked = true
				v.TemplateInstance.Level.Visible = false
				v.TemplateInstance.Price.Visible = true
			end
		end
	end)
	SellConfirmation.Sell.Activated:Connect(function() --[[ Line: 658 | Upvalues: Packets (ref), v2 (ref), PurchaseConfirmation (ref), SellConfirmation (ref), Notify (ref) ]]
		local v22 = Packets.SellWeapon:Fire((workspace:GetAttribute("ToSell")))
		if v22 == "Sold" then
			v2[workspace:GetAttribute("ToSell")].Owned = false
			v2[workspace:GetAttribute("ToSell")].TemplateInstance.Sell.Visible = false
			local Price = v2[workspace:GetAttribute("ToSell")].TemplateInstance.Price
			local Price_2 = v2[workspace:GetAttribute("ToSell")].Price
			Price.Text = "$" .. tostring(Price_2)
			PurchaseConfirmation:SetAttribute("ToSell", "")
			SellConfirmation.Visible = false
			workspace:SetAttribute(workspace:GetAttribute("SellWeaponType"), "N/A")
			workspace:SetAttribute("SellWeaponType", "")
		else
			Notify("Sell Weapon", "Failed to sell weapon " .. v22, 6)
		end
	end)
	PurchaseConfirmation.Buy.Button.Activated:Connect(function() --[[ Line: 676 | Upvalues: Packets (ref), MarketplaceService (ref), LocalPlayer (ref), SoundService (ref), v2 (ref), PurchaseConfirmation (ref) ]]
		local v1 = workspace:GetAttribute("ToBuy")
		if v1 == "" then
			return
		end
		if Packets.PurchaseWeapon:Fire(v1) == false then
			MarketplaceService:PromptProductPurchase(LocalPlayer, 3506671887)
			SoundService.Menu.Error:Play()
		else
			v2[v1].Owned = true
			v2[v1].TemplateInstance.Price.Text = "Owned"
			v2[v1].TemplateInstance.Sell.Visible = true
			workspace:SetAttribute("ToBuy", "")
			SoundService.Menu.Buy:Play()
			task.wait(0.3)
			PurchaseConfirmation.Visible = false
		end
	end)
	PurchaseConfirmation.Cancel.Button.Activated:Connect(function() --[[ Line: 697 | Upvalues: PurchaseConfirmation (ref) ]]
		workspace:SetAttribute("ToBuy", "")
		PurchaseConfirmation:SetAttribute("Type", "")
		PurchaseConfirmation.Visible = false
	end)
	SellConfirmation.Cancel.Activated:Connect(function() --[[ Line: 703 | Upvalues: SellConfirmation (ref) ]]
		workspace:SetAttribute("ToSell", "")
		SellConfirmation.Visible = false
	end)
	for k, v in pairs(t2) do
		local v32 = Frames.Loadout.SelectFrame:FindFirstChild(v)
		if v32 then
			local Button = v32:FindFirstChild("Button")
			if Button then
				Button.Activated:Connect(function() --[[ Line: 715 | Upvalues: Outfit (ref), v (copy), CharacterHandle (ref), t2 (ref), Frames (ref), TweenService (ref) ]]
					Outfit.End()
					workspace:SetAttribute("Previewing", v)
					CharacterHandle()
					for k, v2 in pairs(t2) do
						local v1 = Frames.Loadout.SelectFrame:FindFirstChild(v2)
						if v1 then
							v1.Visible = false
						end
					end
					for k, v2 in pairs(t2) do
						local v22 = Frames.Loadout:FindFirstChild(v2)
						if v22 then
							if v2 == v then
								v22.Visible = true
								local AnimatedUIScale = v22:FindFirstChild("AnimatedUIScale")
								if not AnimatedUIScale then
									local AnimatedUIScale_2 = Instance.new("UIScale")
									AnimatedUIScale_2.Name = "AnimatedUIScale"
									AnimatedUIScale_2.Parent = v22
									AnimatedUIScale = AnimatedUIScale_2
								end
								AnimatedUIScale.Scale = 0.8
								TweenService:Create(AnimatedUIScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
									Scale = 1
								}):Play()
								continue
							end
							v22.Visible = false
						end
					end
				end)
			end
		end
	end
	for k, v in pairs(t2) do
		local v4 = Frames.Loadout:FindFirstChild(v)
		if v4 then
			local ScrollingFrame = v4:FindFirstChild("ScrollingFrame")
			if ScrollingFrame then
				local GoBack = ScrollingFrame:FindFirstChild("GoBack")
				if GoBack then
					local Button = GoBack:FindFirstChild("Button")
					if Button then
						Button.Activated:Connect(function() --[[ Line: 762 | Upvalues: Outfit (ref), CharacterHandle (ref), ScrollingFrame (copy), TweenService (ref), t2 (ref), Frames (ref) ]]
							Outfit.Start()
							workspace:SetAttribute("Previewing", "None")
							CharacterHandle()
							local v1 = ScrollingFrame.Parent
							local AnimatedUIScale = v1:FindFirstChild("AnimatedUIScale")
							if not AnimatedUIScale then
								AnimatedUIScale = Instance.new("UIScale")
								AnimatedUIScale.Name = "AnimatedUIScale"
								AnimatedUIScale.Parent = v1
							end
							TweenService:Create(AnimatedUIScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
								Scale = 0.8
							}):Play()
							task.delay(0.12, function() --[[ Line: 778 | Upvalues: v1 (copy), AnimatedUIScale (ref), t2 (ref), Frames (ref), TweenService (ref) ]]
								v1.Visible = false
								AnimatedUIScale.Scale = 1
								local sum = 0
								for i, v in ipairs(t2) do
									local v12 = Frames.Loadout.SelectFrame:FindFirstChild(v)
									if v12 then
										v12.Visible = true
										local AnimatedUIScale_2 = v12:FindFirstChild("AnimatedUIScale")
										if not AnimatedUIScale_2 then
											AnimatedUIScale_2 = Instance.new("UIScale")
											AnimatedUIScale_2.Name = "AnimatedUIScale"
											AnimatedUIScale_2.Parent = v12
										end
										AnimatedUIScale_2.Scale = 0.8
										task.delay(sum, function() --[[ Line: 796 | Upvalues: TweenService (ref), AnimatedUIScale_2 (ref) ]]
											TweenService:Create(AnimatedUIScale_2, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
												Scale = 1
											}):Play()
										end)
										sum = sum + 0.05
									end
								end
							end)
						end)
					end
				end
			end
		end
	end
	local t4 = {
		Primary = {},
		Secondary = {},
		Equipment = {}
	}
	for k, v in pairs(v2) do
		task.spawn(function() --[[ Line: 816 | Upvalues: Frames (ref), v (copy), SetupWeaponButton (ref), k (copy), t4 (copy) ]]
			local v1 = "Primary"
			local ScrollingFrame = Frames.Loadout.Primary.ScrollingFrame
			if v.Secondary then
				ScrollingFrame = Frames.Loadout.Secondary.ScrollingFrame
				v1 = "Secondary"
			elseif v.Equipment then
				ScrollingFrame = Frames.Loadout.Equipment.ScrollingFrame
				v1 = "Equipment"
			end
			local v2 = SetupWeaponButton(k, v, v1, ScrollingFrame)
			if not v2 then
				return
			end
			table.insert(t4[v1], v2)
		end)
	end
	local DroneSystem = ReplicatedStorage:FindFirstChild("DroneSystem")
	if DroneSystem then
		local Attachments = DroneSystem:FindFirstChild("Attachments")
		if Attachments then
			local DroneCustomization = Frames.Loadout:FindFirstChild("DroneCustomization")
			if DroneCustomization then
				local ScrollingFrame = DroneCustomization:FindFirstChild("ScrollingFrame")
				if ScrollingFrame then
					for k, v in pairs(Attachments:GetChildren()) do
						SetupDroneAttachmentButton(v, ScrollingFrame)
					end
				end
			end
		end
	end
	Outfit.Once()
	if workspace:GetAttribute("CurrentWindow") == "Loadout" then
		local Primary = Frames.Loadout.SelectFrame:FindFirstChild("Primary")
		if Primary and Primary.Visible then
			Outfit.Start()
		end
	end
	for k, v in pairs(Frames.Loadout:GetChildren()) do
		if v:IsA("Frame") and (v:FindFirstChild("Back") and v.Name ~= "Outfit") then
			v:FindFirstChild("Back").Activated:Connect(function() --[[ Line: 865 | Upvalues: v (copy), Frames (ref) ]]
				v.Visible = false
				Frames.Loadout.Points.Visible = true
			end)
		end
	end
	local v5 = workspace:GetAttribute("SelectedDroneAttachment")
	if v5 then
		UpdateSelectViewport("DroneCustomization", v5)
	end
	RefreshLoadout()
end