-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
	return function() --[[ Line: 11 ]] end
end
local Main = PlayerGui:WaitForChild("Main", 10)
local v1 = if Main then Main:WaitForChild("CanvasInGame", 10) else Main
local v2 = v1 and v1:WaitForChild("Chat", 10)
local v3 = if v2 then v2:WaitForChild("Bar", 10) else v2
local v4 = if v3 then v3:WaitForChild("SendFrame", 10) else v3
local v5 = v4 and v4:WaitForChild("Button", 10)
local v6 = v3 and v3:WaitForChild("Type", 10)
local v7 = if v2 then v2:WaitForChild("GlobalChat", 10) else v2
local v8 = if v2 then v2:WaitForChild("TeamChat", 10) else v2
local v9 = v7 and v7:WaitForChild("Button", 10)
local v10 = v8 and v8:WaitForChild("Button", 10)
local Game = ReplicatedStorage:WaitForChild("Game", 10)
local v11 = if Game then Game:WaitForChild("Modules", 10) else Game
local v12 = if v11 then v11:WaitForChild("Packets", 10) else v11
local GlobalBox = v2 and v2:WaitForChild("Box", 10)
local Template = script:WaitForChild("Template", 10)
if v2 and (v3 and (v4 and (v5 and (v6 and (v7 and (v8 and (v9 and (v10 and (GlobalBox and (Template and v12)))))))))) then
	local v13 = require(v12)
	GlobalBox.Name = "GlobalBox"
	local TeamBox = GlobalBox:Clone()
	TeamBox.Name = "TeamBox"
	TeamBox.Visible = false
	TeamBox.Parent = v2
	for i, v in ipairs(TeamBox:GetChildren()) do
		if v:IsA("Frame") or v:IsA("TextLabel") then
			v:Destroy()
		end
	end
	local v14 = tick()
	local v15 = nil
	local v16 = false
	local v17 = "Global"
	local function ResetFadeTimer() --[[ ResetFadeTimer | Line: 67 | Upvalues: v14 (ref), v2 (copy), v15 (ref) ]]
		v14 = tick()
		v2.Visible = true
		if v15 then
			task.cancel(v15)
		end
		v15 = task.delay(10, function() --[[ Line: 75 | Upvalues: v14 (ref), v2 (ref) ]]
			if not (tick() - v14 >= 10) then
				return
			end
			v2.Visible = false
		end)
	end
	local function SwitchChannel(p1) --[[ SwitchChannel | Line: 82 | Upvalues: v17 (ref), GlobalBox (copy), TeamBox (copy), v6 (copy), ResetFadeTimer (copy) ]]
		v17 = p1
		if p1 == "Global" then
			GlobalBox.Visible = true
			TeamBox.Visible = false
			v6.PlaceholderText = "[Global] Type message here..."
		elseif p1 == "Team" then
			GlobalBox.Visible = false
			TeamBox.Visible = true
			v6.PlaceholderText = "[Team] Type message here..."
		end
		ResetFadeTimer()
	end
	local function CreateAMessage(p1, p2, p3, p4) --[[ CreateAMessage | Line: 96 | Upvalues: ResetFadeTimer (copy), Template (copy), GlobalBox (copy), v17 (ref), TeamBox (copy) ]]
		if not p1 or p2 == nil then
			return
		end
		ResetFadeTimer()
		local v1 = Template:Clone()
		local v2 = GlobalBox
		if p3 then
			v1.TextLabel.Text = p2
			v1.TextLabel.TextColor3 = Color3.fromRGB(139, 0, 0)
			v2 = v17 == "Team" and TeamBox or GlobalBox
		else
			if p4 == "Team" then
				v2 = TeamBox
			end
			local Color = p1.TeamColor.Color
			local v4 = Color3.new(Color.R * 0.75, Color.G * 0.75, Color.B * 0.75)
			v1.TextLabel.Text = ("%*<font color=\"rgb(%*,%*,%*)\">%*</font> | %*"):format(if p4 == "Team" then "<font color=\"rgb(0, 200, 255)\">[Team]</font> " else "", math.floor(v4.R * 255), math.floor(v4.G * 255), math.floor(v4.B * 255), p1.Name, p2)
			v1.TextLabel.RichText = true
			v1.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		v1.Parent = v2
		local t = {}
		for i, v in ipairs(v2:GetChildren()) do
			if v:IsA("Frame") or v:IsA("TextLabel") then
				table.insert(t, v)
			end
		end
		while #t > 10 do
			table.remove(t, 1):Destroy()
		end
	end
	local function SendMessage() --[[ SendMessage | Line: 141 | Upvalues: v6 (copy), CreateAMessage (copy), LocalPlayer (copy), v17 (ref), v13 (copy) ]]
		local Text = v6.Text
		v6.Text = ""
		if not Text or Text == "" then
			return
		end
		if #Text > 500 then
			CreateAMessage(LocalPlayer, "Message too long (max 500 characters)", true)
			return
		end
		local v2 = v13.ChatAction:Fire(if v17 == "Team" then "\1TEAM\1" .. Text else Text)
		if v2 == "COOLDOWN" then
			CreateAMessage(LocalPlayer, "No one will see this message you are on cooldown", true)
			return
		end
		if v2 == "FILTERED" then
			CreateAMessage(LocalPlayer, "No one will see this message it was filtered", true)
			return
		end
		if v2 ~= "NOTEAM" then
			return
		end
		CreateAMessage(LocalPlayer, "You are not in a team to use team chat!", true)
	end
	local function OpenChat(p1, p2, p3) --[[ OpenChat | Line: 164 | Upvalues: v16 (ref), v6 (copy) ]]
		if p2 ~= Enum.UserInputState.Begin or v16 then
			return Enum.ContextActionResult.Pass
		end
		v6:CaptureFocus()
		task.wait()
		if v6.Text ~= "/" then
			return Enum.ContextActionResult.Sink
		end
		v6.Text = ""
		return Enum.ContextActionResult.Sink
	end
	local v18 = false
	local function InitializeChat() --[[ InitializeChat | Line: 178 | Upvalues: v18 (ref), StarterGui (copy), ContextActionService (copy), OpenChat (copy), v5 (copy), SendMessage (copy), v9 (copy), v17 (ref), GlobalBox (copy), TeamBox (copy), v6 (copy), ResetFadeTimer (copy), v10 (copy), v16 (ref), v13 (copy), CreateAMessage (copy) ]]
		if not v18 then
			v18 = true
			pcall(function() --[[ Line: 184 | Upvalues: StarterGui (ref) ]]
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
			end)
			ContextActionService:BindAction("OpenChat", OpenChat, false, Enum.KeyCode.Slash)
			v5.Activated:Connect(SendMessage)
			v9.Activated:Connect(function() --[[ Line: 190 | Upvalues: v17 (ref), GlobalBox (ref), TeamBox (ref), v6 (ref), ResetFadeTimer (ref) ]]
				v17 = "Global"
				GlobalBox.Visible = true
				TeamBox.Visible = false
				v6.PlaceholderText = "[Global] Type message here..."
				ResetFadeTimer()
			end)
			v10.Activated:Connect(function() --[[ Line: 193 | Upvalues: v17 (ref), GlobalBox (ref), TeamBox (ref), v6 (ref), ResetFadeTimer (ref) ]]
				v17 = "Team"
				GlobalBox.Visible = false
				TeamBox.Visible = true
				v6.PlaceholderText = "[Team] Type message here..."
				ResetFadeTimer()
			end)
			v6.FocusLost:Connect(function(p1) --[[ Line: 197 | Upvalues: v16 (ref), SendMessage (ref), v6 (ref), ResetFadeTimer (ref) ]]
				v16 = false
				if p1 then
					SendMessage()
				else
					v6.Text = ""
				end
				ResetFadeTimer()
			end)
			v6.Focused:Connect(function() --[[ Line: 207 | Upvalues: v16 (ref), ResetFadeTimer (ref) ]]
				v16 = true
				ResetFadeTimer()
			end)
			v6:GetPropertyChangedSignal("Text"):Connect(function() --[[ Line: 212 | Upvalues: ResetFadeTimer (ref), v6 (ref), v17 (ref), GlobalBox (ref), TeamBox (ref) ]]
				ResetFadeTimer()
				local Text = v6.Text
				if Text:sub(1, 3):lower() == "/t " or Text:sub(1, 6):lower() == "/team " then
					v6.Text = ""
					v17 = "Team"
					GlobalBox.Visible = false
					TeamBox.Visible = true
					v6.PlaceholderText = "[Team] Type message here..."
				else
					if Text:sub(1, 3):lower() ~= "/g " and Text:sub(1, 8):lower() ~= "/global " then
						return
					end
					v6.Text = ""
					v17 = "Global"
					GlobalBox.Visible = true
					TeamBox.Visible = false
					v6.PlaceholderText = "[Global] Type message here..."
				end
				ResetFadeTimer()
			end)
			v13.ChatReceive.OnClientEvent:Connect(function(p1, p2) --[[ Line: 224 | Upvalues: CreateAMessage (ref) ]]
				local v1
				if p2:sub(1, 6) == "\1TEAM\1" then
					p2, v1 = p2:sub(7), "Team"
				else
					v1 = "Global"
				end
				CreateAMessage(p1, p2, false, v1)
			end)
			v6.PlaceholderText = "[Global] Type message here..."
			ResetFadeTimer()
		end
	end
	return function() --[[ Line: 237 | Upvalues: v2 (copy), StarterGui (copy), TextChatService (copy), LocalPlayer (copy), InitializeChat (copy) ]]
		v2.Visible = false
		pcall(function() --[[ Line: 239 | Upvalues: StarterGui (ref) ]]
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
		task.spawn(function() --[[ Line: 243 | Upvalues: TextChatService (ref), LocalPlayer (ref), InitializeChat (ref) ]]
			local v1, v2 = pcall(function() --[[ Line: 244 | Upvalues: TextChatService (ref), LocalPlayer (ref) ]]
				return TextChatService:CanUserChatAsync(LocalPlayer.UserId)
			end)
			if not (v1 and v2) then
				return
			end
			InitializeChat()
		end)
	end
else
	warn("Chat module skipped: required UI or packets were not available during startup")
	return function() --[[ Line: 32 | Upvalues: v2 (copy), StarterGui (copy) ]]
		if v2 then
			v2.Visible = false
		end
		pcall(function() --[[ Line: 36 | Upvalues: StarterGui (ref) ]]
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
	end
end