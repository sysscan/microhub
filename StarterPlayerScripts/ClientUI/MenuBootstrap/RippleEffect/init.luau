-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
local t2 = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	TweenService = game:GetService("TweenService"),
	Lighting = game:GetService("Lighting"),
	RunService = game:GetService("RunService")
}
local LocalPlayer = t2.Players.LocalPlayer
local Main = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main")
local Canvas = Main:WaitForChild("Canvas")
local Frames = Canvas:WaitForChild("Frames")
Frames:WaitForChild("Map")
Frames:WaitForChild("Loadout")
local Team = Frames:WaitForChild("Team")
local TopBar = Canvas:WaitForChild("TopBar")
local Profile = Canvas:WaitForChild("Profile")
local MouseClickEffect = require(script:WaitForChild("MouseClickEffect"))
local BlurFrame = require(t2.ReplicatedStorage:WaitForChild("UIModules"):WaitForChild("BlurFrame"))
require(t2.ReplicatedStorage:WaitForChild("UIModules"):WaitForChild("ViewportModelFitter"))
local t3 = {
	ButtonHoverScale = 1.05,
	ButtonDefaultScale = 1,
	HoverTweenTime = 0.125,
	LeaveTweenTime = 0.33
}
local v1 = nil
local v2 = Team
local t4 = {}
local v3 = false
workspace:SetAttribute("CurrentWindow", "Team")
local ClickUi = Instance.new("Sound", game:GetService("SoundService"))
ClickUi.Name = "ClickUi"
ClickUi.Volume = 0.25
ClickUi.SoundId = "rbxassetid://139420002530063"
local function CreateScale(p1) --[[ CreateScale | Line: 51 | Upvalues: t3 (copy) ]]
	local UIScale = Instance.new("UIScale")
	UIScale.Scale = t3.ButtonDefaultScale
	UIScale.Parent = p1
	return UIScale
end
local function TweenScale(p1, p2, p3) --[[ TweenScale | Line: 58 | Upvalues: t2 (copy) ]]
	return t2.TweenService:Create(p1, TweenInfo.new(p3), {
		Scale = p2
	})
end
local function SwitchWindow(p1) --[[ SwitchWindow | Line: 66 | Upvalues: v2 (ref), v3 (ref), v1 (ref), Main (copy), t4 (copy), t2 (copy) ]]
	if not p1 or (v2 == p1 or v3) then
		return
	end
	v3 = true
	if v1 and v1:FindFirstChild("Stroke") then
		v1.Stroke.Transparency = 0.9
	end
	for i, v in ipairs(Main:GetDescendants()) do
		if v:IsA("Frame") and v:GetAttribute("SizeButton") and (v:GetAttribute("SwitchTab") or (type(v:GetAttribute("FrameButton")) == "string" and v:GetAttribute("FrameButton") or string.gsub(v.Name, "Button", ""))) == p1.Name then
			v1 = v
			local Stroke = v:FindFirstChild("Stroke")
			if Stroke and not v:GetAttribute("SwitchTab") then
				Stroke.Transparency = 0.25
			end
			break
		end
	end
	local v22 = v2
	v2 = p1
	if v22 then
		local v32 = v22:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale", v22)
		local v4 = t4[v22]
		local v5 = UDim2.new(v4.Position.X.Scale - 1.2, v4.Position.X.Offset, v4.Position.Y.Scale, v4.Position.Y.Offset)
		local v6 = t2.TweenService:Create(v22, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Position = v5
		})
		t2.TweenService:Create(v32, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Scale = 0.95
		}):Play()
		v6:Play()
		v6.Completed:Wait()
		v22.Visible = false
	end
	local v7 = t4[p1]
	local v8 = p1:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale", p1)
	p1.Position = UDim2.new(v7.Position.X.Scale + 1.2, v7.Position.X.Offset, v7.Position.Y.Scale, v7.Position.Y.Offset)
	v8.Scale = 0.95
	p1.Visible = true
	local v9 = t2.TweenService:Create(p1, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = v7.Position
	})
	t2.TweenService:Create(v8, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Scale = 1
	}):Play()
	v9:Play()
	v9.Completed:Wait()
	v3 = false
end
local function SetupButton(p1) --[[ SetupButton | Line: 131 | Upvalues: t3 (copy), t2 (copy), v3 (ref), ClickUi (copy), MouseClickEffect (copy), LocalPlayer (copy), Frames (copy), v2 (ref), v1 (ref) ]]
	local Button = p1:FindFirstChild("Button")
	if Button then
		local UIScale = Instance.new("UIScale")
		UIScale.Scale = t3.ButtonDefaultScale
		UIScale.Parent = p1
		local v12 = UIScale
		local Stroke = p1:FindFirstChild("Stroke")
		Button.MouseEnter:Connect(function() --[[ Line: 138 | Upvalues: v12 (copy), p1 (copy), t3 (ref), t2 (ref) ]]
			local v2 = p1:GetAttribute("SizeButtonMulti") or t3.ButtonHoverScale
			t2.TweenService:Create(v12, TweenInfo.new(t3.HoverTweenTime), {
				Scale = v2
			}):Play()
		end)
		Button.MouseLeave:Connect(function() --[[ Line: 142 | Upvalues: v12 (copy), t3 (ref), t2 (ref) ]]
			t2.TweenService:Create(v12, TweenInfo.new(t3.LeaveTweenTime), {
				Scale = t3.ButtonDefaultScale
			}):Play()
		end)
		Button.Activated:Connect(function() --[[ Line: 146 | Upvalues: v3 (ref), ClickUi (ref), MouseClickEffect (ref), Button (copy), LocalPlayer (ref), p1 (copy), Frames (ref), v2 (ref), v1 (ref), Stroke (copy) ]]
			if v3 then
				return
			end
			ClickUi:Play()
			task.spawn(function() --[[ Line: 150 | Upvalues: MouseClickEffect (ref), Button (ref), LocalPlayer (ref) ]]
				MouseClickEffect.AddEffect(Button, LocalPlayer:GetMouse(), 0.25)
			end)
			if not (p1:GetAttribute("FrameButton") or p1:GetAttribute("SwitchTab")) then
				return
			end
			local v12 = p1:GetAttribute("SwitchTab")
			if not v12 then
				v12 = type(p1:GetAttribute("FrameButton")) == "string" and p1:GetAttribute("FrameButton") or string.gsub(p1.Name, "Button", "")
			end
			local v32 = Frames:FindFirstChild(v12)
			if not v32 or v2 == v32 then
				return
			end
			if v1 and v1:FindFirstChild("Stroke") then
				v1.Stroke.Transparency = 0.9
			end
			v1 = p1
			if Stroke and not p1:GetAttribute("SwitchTab") then
				Stroke.Transparency = 0.25
			end
			workspace:SetAttribute("CurrentWindow", v12)
		end)
	end
end
local function SetupProfile(p1) --[[ SetupProfile | Line: 174 | Upvalues: LocalPlayer (copy) ]]
	p1.Image = ("rbxthumb://type=AvatarHeadShot&id=%*&w=420&h=420"):format(LocalPlayer.UserId)
	p1.Parent:WaitForChild("DisplayName").Text = LocalPlayer.DisplayName
	p1.Parent.UserName.Text = "@" .. LocalPlayer.Name
end
local function Process(p1) --[[ Process | Line: 180 | Upvalues: BlurFrame (copy), SetupButton (copy), LocalPlayer (copy), t2 (copy) ]]
	if p1:IsA("Frame") then
		if p1:GetAttribute("Blur") then
			BlurFrame.CreateBlurFrame(p1)
		end
		if p1:GetAttribute("SizeButton") then
			SetupButton(p1)
		end
	else
		if p1:IsA("ImageLabel") and p1.Name == "IconUser" then
			p1.Image = ("rbxthumb://type=AvatarHeadShot&id=%*&w=420&h=420"):format(LocalPlayer.UserId)
			p1.Parent:WaitForChild("DisplayName").Text = LocalPlayer.DisplayName
			p1.Parent.UserName.Text = "@" .. LocalPlayer.Name
			return
		end
		if not (p1:IsA("UIGradient") and p1:GetAttribute("GradientRotation")) then
			return
		end
		p1.Rotation = 0
		t2.TweenService:Create(p1, TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {
			Rotation = 360
		}):Play()
	end
end
function t.Init() --[[ Init | Line: 201 | Upvalues: Frames (copy), t4 (copy), Team (copy), v2 (ref), Main (copy), Process (copy), v1 (ref), t2 (copy), TopBar (copy), Profile (copy), SwitchWindow (copy), Canvas (copy), BlurFrame (copy), LocalPlayer (copy) ]]
	for i, v in ipairs(Frames:GetChildren()) do
		if v:IsA("GuiObject") then
			t4[v] = {
				Position = v.Position
			}
			if v == Team then
				v.Visible = true
				continue
			end
			v.Visible = false
		end
	end
	v2 = Team
	workspace:SetAttribute("CurrentWindow", "Team")
	workspace:SetAttribute("HideTopBar", true)
	for i, v in ipairs(Main:GetDescendants()) do
		Process(v)
		if v:IsA("Frame") and (v.Name == "TeamButton" and v:GetAttribute("FrameButton")) then
			v1 = v
			if v:FindFirstChild("Stroke") then
				v.Stroke.Transparency = 0.25
			end
		end
	end
	if workspace:GetAttribute("HideTopBar") then
		t2.TweenService:Create(TopBar, TweenInfo.new(0.5), {
			Position = UDim2.new(-1, 0, 0, 0)
		}):Play()
		t2.TweenService:Create(Profile, TweenInfo.new(0.5), {
			Position = UDim2.new(2, 0, 0, 0)
		}):Play()
	else
		t2.TweenService:Create(TopBar, TweenInfo.new(0.5), {
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()
		t2.TweenService:Create(Profile, TweenInfo.new(0.5), {
			Position = UDim2.new(1, 0, 0, 0)
		}):Play()
	end
	workspace:GetAttributeChangedSignal("CurrentWindow"):Connect(function() --[[ Line: 238 | Upvalues: Frames (ref), SwitchWindow (ref) ]]
		SwitchWindow((Frames:FindFirstChild((workspace:GetAttribute("CurrentWindow")))))
	end)
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 244 | Upvalues: Canvas (ref), Main (ref), BlurFrame (ref), LocalPlayer (ref) ]]
		if workspace:GetAttribute("InMenu") then
			Canvas.Visible = true
			Main.CanvasInGame.Visible = false
			BlurFrame:Enable(true)
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		else
			Canvas.Visible = false
			Main.CanvasInGame.Visible = LocalPlayer:GetAttribute("GameUI") or true
			BlurFrame:Enable(false)
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		end
	end)
	Main:GetPropertyChangedSignal("Enabled"):Connect(function() --[[ Line: 258 | Upvalues: Main (ref), BlurFrame (ref) ]]
		if Main.Enabled then
			BlurFrame:Enable(true)
		else
			BlurFrame:Enable(false)
		end
	end)
	workspace:GetAttributeChangedSignal("HideTopBar"):Connect(function() --[[ Line: 266 | Upvalues: t2 (ref), TopBar (ref), Profile (ref) ]]
		if workspace:GetAttribute("HideTopBar") then
			t2.TweenService:Create(TopBar, TweenInfo.new(0.5), {
				Position = UDim2.new(-1, 0, 0, 0)
			}):Play()
			t2.TweenService:Create(Profile, TweenInfo.new(0.5), {
				Position = UDim2.new(2, 0, 0, 0)
			}):Play()
		else
			t2.TweenService:Create(TopBar, TweenInfo.new(0.5), {
				Position = UDim2.new(0, 0, 0, 0)
			}):Play()
			t2.TweenService:Create(Profile, TweenInfo.new(0.5), {
				Position = UDim2.new(1, 0, 0, 0)
			}):Play()
		end
	end)
end
return t