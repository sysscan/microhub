-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Slider = require(ReplicatedStorage.Game.Modules:WaitForChild("Slider"))
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local Settings = PlayerGui:WaitForChild("Main"):WaitForChild("Canvas"):WaitForChild("Frames"):WaitForChild("Settings")
local SettingsFrame = Settings:WaitForChild("SettingsFrame")
local ScrollingFrame = SettingsFrame:WaitForChild("Keybinds"):WaitForChild("ScrollingFrame")
local ScrollingFrame_2 = SettingsFrame:WaitForChild("Toggles"):WaitForChild("ScrollingFrame")
local KeyBinds = ReplicatedStorage:WaitForChild("Framework"):WaitForChild("KeyBinds")
local v1 = script.Parent.Parent.Assets.Sounds.Themes:GetChildren()
local Settings_2 = Packets.Settings
local t = {
	FieldOfView = {
		Start = 55,
		End = 90,
		Increment = 1,
		Default = 67
	},
	DesktopDroneSensitivity = {
		Start = 0.01,
		End = 3,
		Increment = 0.01,
		Default = 0.5
	},
	GamepadDroneSensitivity = {
		Start = 0.1,
		End = 6,
		Increment = 0.05,
		Default = 1.5
	},
	AnimationQuality = {
		Start = 1,
		End = 5,
		Increment = 1,
		Default = 1
	},
	DroneDifficulty = {
		Start = 1,
		End = 2,
		Increment = 1,
		Default = 2
	},
	LobbyMusicVolume = {
		Start = 0,
		End = 1,
		Increment = 0.01,
		Default = 0.015
	}
}
local t2 = { "Hard", "Easy" }
function GetEnumKey(p1) --[[ GetEnumKey | Line: 41 ]]
	local v1, v2 = pcall(function() --[[ Line: 42 | Upvalues: p1 (copy) ]]
		return Enum.UserInputType[p1]
	end)
	if v1 and typeof(v2) == "EnumItem" then
		return v2
	end
	local v3, v4 = pcall(function() --[[ Line: 45 | Upvalues: p1 (copy) ]]
		return Enum.KeyCode[p1]
	end)
	if v3 and typeof(v4) == "EnumItem" then
		return v4
	else
		return nil
	end
end
local t3 = {
	Settings = {},
	Device = ""
}
local function ApplyAllAttributes(p1) --[[ ApplyAllAttributes | Line: 55 | Upvalues: t (copy), t3 (copy), Players (copy) ]]
	workspace:SetAttribute("FieldOfView", (math.round(p1.FieldOfView or t.FieldOfView.Default)))
	local v4 = if t3 and t3.Device == "Gamepad" then "GamepadDroneSensitivity" else "DesktopDroneSensitivity"
	workspace:SetAttribute("DroneSensitivity", p1[v4] or t[v4].Default)
	workspace:SetAttribute("AnimationQuality", (math.round(p1.AnimationQuality or t.AnimationQuality.Default)))
	workspace:SetAttribute("DroneDifficulty", (math.round(p1.DroneDifficulty or t.DroneDifficulty.Default)))
	for k, v in pairs(p1) do
		if typeof(v) == "boolean" then
			workspace:SetAttribute(k, v)
			Players.LocalPlayer:SetAttribute(k, v)
		end
	end
end
local function BindCoolHoverEffect(p1) --[[ BindCoolHoverEffect | Line: 77 | Upvalues: TweenService (copy) ]]
	local Size = p1.Size
	p1.MouseEnter:Connect(function() --[[ Line: 79 | Upvalues: TweenService (ref), p1 (copy), Size (copy) ]]
		TweenService:Create(p1, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(Size.X.Scale * 1.05, 0, Size.Y.Scale * 1.05, 0)
		}):Play()
	end)
	p1.MouseLeave:Connect(function() --[[ Line: 82 | Upvalues: TweenService (ref), p1 (copy), Size (copy) ]]
		TweenService:Create(p1, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Size
		}):Play()
	end)
	p1.MouseButton1Down:Connect(function() --[[ Line: 85 | Upvalues: TweenService (ref), p1 (copy), Size (copy) ]]
		TweenService:Create(p1, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(Size.X.Scale * 0.95, 0, Size.Y.Scale * 0.95, 0)
		}):Play()
	end)
	p1.MouseButton1Up:Connect(function() --[[ Line: 88 | Upvalues: TweenService (ref), p1 (copy), Size (copy) ]]
		TweenService:Create(p1, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(Size.X.Scale * 1.05, 0, Size.Y.Scale * 1.05, 0)
		}):Play()
	end)
end
function t3.Init() --[[ Init | Line: 93 | Upvalues: t3 (copy), UserInputService (copy), ScrollingFrame_2 (copy), Packets (copy), Players (copy), ApplyAllAttributes (copy), t (copy), v1 (copy), KeyBinds (copy), Slider (copy), Settings_2 (copy), t2 (copy), ScrollingFrame (copy), BindCoolHoverEffect (copy), TweenService (copy), Settings (copy), SettingsFrame (copy) ]]
	task.wait(1)
	t3.Device = "Desktop"
	if UserInputService.GamepadEnabled then
		t3.Device = "Gamepad"
		if ScrollingFrame_2:FindFirstChild("DesktopDroneSensitivity") then
			ScrollingFrame_2.DesktopDroneSensitivity.Visible = false
		end
		if ScrollingFrame_2:FindFirstChild("GamepadDroneSensitivity") then
			ScrollingFrame_2.GamepadDroneSensitivity.Visible = true
		end
	elseif UserInputService.KeyboardEnabled then
		t3.Device = "Desktop"
		if ScrollingFrame_2:FindFirstChild("DesktopDroneSensitivity") then
			ScrollingFrame_2.DesktopDroneSensitivity.Visible = true
		end
		if ScrollingFrame_2:FindFirstChild("GamepadDroneSensitivity") then
			ScrollingFrame_2.GamepadDroneSensitivity.Visible = false
		end
	end
	t3.Settings = Packets.ReturnSettings:Fire()
	local Settings_3 = t3.Settings
	if type(Settings_3) ~= "table" then
		repeat
			t3.Settings = Packets.ReturnSettings:Fire()
			task.wait(0.5)
		until type(t3.Settings) == "table" and #t3.Settings > 0
	end
	for k, v in pairs(t3.Settings) do
		if t3.Settings[k] ~= nil then
			t3.Settings[k] = v
			if typeof(v) == "boolean" then
				Players.LocalPlayer:SetAttribute(k, v)
			end
		end
	end
	ApplyAllAttributes(t3.Settings)
	local v12 = workspace
	local v3 = t3.Settings.LobbyMusicVolume or t.LobbyMusicVolume.Default
	v12:SetAttribute("LobbyMusicVolume", v3)
	for k, v in pairs(v1) do
		v.Volume = workspace:GetAttribute("LobbyMusicVolume")
	end
	local v4 = require(KeyBinds)
	local t4 = {}
	if v4.InputBindings then
		for k, v in pairs(v4.InputBindings) do
			t4[k] = {
				Computer = v.Computer,
				Console = v.Console
			}
		end
	end
	local function SetupSliderUI(p1, p2) --[[ SetupSliderUI | Line: 146 | Upvalues: ScrollingFrame_2 (ref), t (ref), Slider (ref), t3 (ref), v1 (ref), Settings_2 (ref) ]]
		local v12 = ScrollingFrame_2:FindFirstChild(p1)
		if not v12 then
			return
		end
		local Slider_2 = v12:FindFirstChild("Slider", true)
		if not Slider_2 then
			return
		end
		local v2 = t[p1]
		local t2 = {}
		local t4 = {
			Start = v2.Start,
			End = v2.End,
			Increment = v2.Increment
		}
		t4.DefaultValue = t3.Settings[p1] or v2.Default
		t2.SliderData = t4
		t2.MoveInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local v5 = Slider.new(Slider_2, t2)
		local function UpdateText(p1) --[[ UpdateText | Line: 165 | Upvalues: v12 (copy), p2 (copy) ]]
			local Number = v12:FindFirstChild("Number", true)
			if not (Number and Number:IsA("TextLabel")) then
				return
			end
			Number.Text = p2 and p2(p1) or tostring(p1)
		end
		v5:Track()
		local v6 = v5:GetValue()
		local Number = v12:FindFirstChild("Number", true)
		if Number and Number:IsA("TextLabel") then
			Number.Text = p2 and p2(v6) or tostring(v6)
		end
		v5.Dragged:Connect(function(p12) --[[ Line: 175 | Upvalues: v12 (copy), p2 (copy), t3 (ref), p1 (copy), v1 (ref) ]]
			local Number = v12:FindFirstChild("Number", true)
			if Number and Number:IsA("TextLabel") then
				Number.Text = p2 and p2(p12) or tostring(p12)
			end
			t3.Settings[p1] = p12
			if p1 == "FieldOfView" then
				workspace:SetAttribute("FieldOfView", (math.round(p12)))
				return
			end
			if p1 == "AnimationQuality" then
				workspace:SetAttribute("AnimationQuality", (math.round(p12)))
				return
			end
			if p1 == "DroneDifficulty" then
				workspace:SetAttribute("DroneDifficulty", (math.round(p12)))
				return
			end
			if p1 == "DesktopDroneSensitivity" or p1 == "GamepadDroneSensitivity" then
				workspace:SetAttribute("DroneSensitivity", p12)
				return
			end
			if p1 ~= "LobbyMusicVolume" then
				return
			end
			workspace:SetAttribute("LobbyMusicVolume", p12)
			for k, v in pairs(v1) do
				v.Volume = p12
			end
		end)
		v5.Released:Connect(function(p12) --[[ Line: 196 | Upvalues: Settings_2 (ref), p1 (copy) ]]
			Settings_2:Fire(p1, "", p12)
		end)
	end
	SetupSliderUI("FieldOfView", function(p1) --[[ Line: 201 ]]
		return tostring((math.round(p1)))
	end)
	SetupSliderUI(t3.Device .. "DroneSensitivity", function(p1) --[[ Line: 207 ]]
		return tostring(math.round(p1 * 100) / 100)
	end)
	local t5 = {
		"High",
		"Medium",
		"Low",
		"Performance",
		"Potato"
	}
	SetupSliderUI("AnimationQuality", function(p1) --[[ Line: 219 | Upvalues: t5 (copy) ]]
		return t5[math.round(p1)] or "Unknown"
	end)
	SetupSliderUI("DroneDifficulty", function(p1) --[[ Line: 223 | Upvalues: t2 (ref) ]]
		return t2[math.round(p1)] or "Unknown"
	end)
	SetupSliderUI("LobbyMusicVolume", function(p1) --[[ Line: 227 ]]
		return tostring(math.round(p1 * 100) / 100)
	end)
	local tbl = {}
	for k, v in pairs(ScrollingFrame:GetChildren()) do
		table.insert(tbl, v)
	end
	for k, v in pairs(ScrollingFrame_2:GetChildren()) do
		table.insert(tbl, v)
	end
	for k, v in pairs(tbl) do
		if v:IsA("Frame") and not v:FindFirstChild("Slider", true) then
			local v5 = v:FindFirstChild("Button", true) or (v:FindFirstChildOfClass("TextButton", true) or v:FindFirstChildOfClass("ImageButton", true))
			if v5 then
				BindCoolHoverEffect(v5)
				local v6 = nil
				if v.Parent.Parent.Name == "Toggles" then
					v6 = v:FindFirstChild("ToggleText", true)
				elseif v.Parent.Parent.Name == "Keybinds" then
					local v7 = v:FindFirstChild("Kebind") or v:FindFirstChild("Keybind")
					if v7 then
						v6 = v7:FindFirstChild("Keybind")
					end
				end
				if not v6 then
					v6 = v:FindFirstChild("Number", true)
				end
				if v6 then
					v5.Active = true
					v5.Selectable = true
					v5.Interactable = true
					if v.Parent.Name == "ScrollingFrame" and v.Parent.Parent.Name == "Keybinds" then
						local v8 = t3.Settings.Keybinds and t3.Settings.Keybinds[t3.Device]
						if t3.Device == "Gamepad" and t3.Settings.Keybinds then
							v8 = t3.Settings.Keybinds.Console
						end
						local v9 = if t3.Device == "Desktop" then "Computer" else "Console"
						local v10 = if v8 then GetEnumKey(v8[v.Name]) else v8
						if v4.InputBindings[v.Name] and v10 then
							v4.InputBindings[v.Name][v9] = v10
						end
						v6.Text = v10 and v10.Name or "None"
						v5.Activated:Connect(function() --[[ Line: 294 | Upvalues: v6 (ref), UserInputService (ref), Settings_2 (ref), t3 (ref), v (copy), v4 (copy), v9 (copy), TweenService (ref) ]]
							v6.Text = "WAITING FOR INPUT"
							local v1
							repeat
								v1 = UserInputService.InputBegan:Wait()
							until v1.UserInputType == Enum.UserInputType.Keyboard or (string.find(v1.UserInputType.Name, "MouseButton") or string.find(v1.UserInputType.Name, "Gamepad"))
							local v2 = v1
							local v3 = v2.KeyCode ~= Enum.KeyCode.Unknown and v2.KeyCode.Name or v2.UserInputType.Name
							Settings_2:Fire(("Keybinds.%*.%*"):format(t3.Device, v.Name), v3, 0, false)
							v6.Text = v3
							if v4.InputBindings[v.Name] then
								v4.InputBindings[v.Name][v9] = v2.KeyCode ~= Enum.KeyCode.Unknown and v2.KeyCode or v2.UserInputType
							end
							if v6.TextScaled then
								return
							end
							TweenService:Create(v6, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								TextSize = v6.TextSize * 1.2
							}):Play()
							task.delay(0.2, function() --[[ Line: 328 | Upvalues: TweenService (ref), v6 (ref) ]]
								TweenService:Create(v6, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
									TextSize = v6.TextSize / 1.2
								}):Play()
							end)
						end)
						v5.MouseButton2Click:Connect(function() --[[ Line: 338 | Upvalues: t4 (copy), v (copy), v9 (copy), Settings_2 (ref), t3 (ref), v6 (ref), v4 (copy), TweenService (ref) ]]
							local v1 = t4[v.Name] and t4[v.Name][v9]
							local v2 = v1 and v1.Name or "None"
							Settings_2:Fire(("Keybinds.%*.%*"):format(t3.Device, v.Name), v2, 0, false)
							v6.Text = v2
							if v4.InputBindings[v.Name] then
								v4.InputBindings[v.Name][v9] = v1
							end
							if v6.TextScaled then
								return
							end
							TweenService:Create(v6, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								TextSize = v6.TextSize * 1.2
							}):Play()
							task.delay(0.2, function() --[[ Line: 357 | Upvalues: TweenService (ref), v6 (ref) ]]
								TweenService:Create(v6, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
									TextSize = v6.TextSize / 1.2
								}):Play()
							end)
						end)
					elseif v.Parent.Name == "ScrollingFrame" and v.Parent.Parent.Name == "Toggles" then
						v6.Text = if t3.Settings[v.Name] or false then "ENABLED" else "DISABLED"
						v5.Activated:Connect(function() --[[ Line: 372 | Upvalues: v6 (ref), Settings_2 (ref), v (copy), Players (ref), t3 (ref), TweenService (ref) ]]
							local isNotText = v6.Text ~= "ENABLED"
							local v1 = v6
							v1.Text = if isNotText then "ENABLED" else "DISABLED"
							Settings_2:Fire(v.Name, "", 0, isNotText)
							Players.LocalPlayer:SetAttribute(v.Name, isNotText)
							t3.Settings[v.Name] = isNotText
							workspace:SetAttribute(v.Name, isNotText)
							local v3 = isNotText and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
							TweenService:Create(v6, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
								TextColor3 = v3
							}):Play()
							task.delay(0.3, function() --[[ Line: 395 | Upvalues: TweenService (ref), v6 (ref) ]]
								TweenService:Create(v6, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
									TextColor3 = Color3.new(255/255, 255/255, 255/255)
								}):Play()
							end)
						end)
						v5.MouseButton2Click:Connect(function() --[[ Line: 404 | Upvalues: v6 (ref), Settings_2 (ref), v (copy), Players (ref), t3 (ref), TweenService (ref) ]]
							v6.Text = "DISABLED"
							Settings_2:Fire(v.Name, "", 0, false)
							Players.LocalPlayer:SetAttribute(v.Name, false)
							t3.Settings[v.Name] = false
							workspace:SetAttribute(v.Name, false)
							local v1 = Color3.fromRGB(255, 100, 100)
							TweenService:Create(v6, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
								TextColor3 = v1
							}):Play()
							task.delay(0.3, function() --[[ Line: 425 | Upvalues: TweenService (ref), v6 (ref) ]]
								TweenService:Create(v6, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
									TextColor3 = Color3.new(255/255, 255/255, 255/255)
								}):Play()
							end)
						end)
					else
						continue
					end
				end
			end
		end
	end
	local v13 = nil
	for k, v in pairs(Settings:GetChildren()) do
		if v:IsA("ImageButton") or v:IsA("TextButton") then
			local v14 = v:FindFirstChild("Label") or v:FindFirstChildOfClass("TextLabel")
			v.MouseEnter:Connect(function() --[[ Line: 444 | Upvalues: v13 (ref), v (copy), TweenService (ref), v14 (copy) ]]
				if v13 == v then
					return
				end
				TweenService:Create(v, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.new(255/255, 255/255, 255/255)
				}):Play()
				if not v14 then
					return
				end
				TweenService:Create(v14, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = Color3.new(0/255, 0/255, 0/255)
				}):Play()
			end)
			v.MouseLeave:Connect(function() --[[ Line: 464 | Upvalues: v13 (ref), v (copy), TweenService (ref), v14 (copy) ]]
				if v13 == v then
					return
				end
				TweenService:Create(v, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.new(0/255, 0/255, 0/255)
				}):Play()
				if not v14 then
					return
				end
				TweenService:Create(v14, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = Color3.new(255/255, 255/255, 255/255)
				}):Play()
			end)
			v.Activated:Connect(function() --[[ Line: 484 | Upvalues: SettingsFrame (ref), v (copy), v13 (ref), TweenService (ref), v14 (copy) ]]
				if SettingsFrame:FindFirstChild(v.Name) then
					for k, v2 in pairs(SettingsFrame:GetChildren()) do
						if v2:IsA("Frame") then
							v2.Visible = v2.Name == v.Name
						end
					end
				end
				if v13 then
					TweenService:Create(v13, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = Color3.new(0/255, 0/255, 0/255)
					}):Play()
					local v1 = v13:FindFirstChild("Label") or v13:FindFirstChildOfClass("TextLabel")
					if v1 then
						TweenService:Create(v1, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextColor3 = Color3.new(255/255, 255/255, 255/255)
						}):Play()
					end
				end
				v13 = v
				TweenService:Create(v, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.new(255/255, 255/255, 255/255)
				}):Play()
				if not v14 then
					return
				end
				TweenService:Create(v14, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = Color3.new(0/255, 0/255, 0/255)
				}):Play()
			end)
		end
	end
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 533 | Upvalues: t3 (ref), t (ref) ]]
		if workspace:GetAttribute("InMenu") == true then
			workspace.CurrentCamera.FieldOfView = 30
			return
		end
		workspace.CurrentCamera.FieldOfView = t3.Settings.FieldOfView or t.FieldOfView.Default
	end)
end
return t3