-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Promise = require(ReplicatedStorage:WaitForChild("Game").Modules:WaitForChild("Promise"))
local Maid = require(ReplicatedStorage.Game.Modules:WaitForChild("Maid"))
local LocalPlayer = Players.LocalPlayer
local FriendsList = LocalPlayer.PlayerGui:WaitForChild("Main"):WaitForChild("Canvas"):WaitForChild("Frames"):WaitForChild("Loadout"):WaitForChild("FriendsList")
local List = FriendsList:WaitForChild("List")
local Amount = FriendsList:WaitForChild("Amount")
local Template = List:WaitForChild("Template")
Template.Visible = false
local t = {}
local v1 = 0
local v2 = nil
local function CanSendInvite(p1) --[[ CanSendInvite | Line: 25 | Upvalues: SocialService (copy), LocalPlayer (copy) ]]
	local v1, v2 = pcall(function() --[[ Line: 26 | Upvalues: SocialService (ref), LocalPlayer (ref), p1 (copy) ]]
		return SocialService:CanSendGameInviteAsync(LocalPlayer, p1)
	end)
	return v1 and v2
end
return function() --[[ Line: 33 | Upvalues: Promise (copy), LocalPlayer (copy), v1 (ref), t (copy), v2 (ref), Maid (copy), Template (copy), List (copy), SocialService (copy), TweenService (copy), Players (copy), Amount (copy) ]]
	Promise.new(function(p1, p2) --[[ Line: 34 | Upvalues: LocalPlayer (ref) ]]
		local v1, v2 = pcall(LocalPlayer.GetFriendsOnline, LocalPlayer, 3)
		if v1 then
			p1(v2)
		else
			p2(v2)
		end
	end):catch(function() --[[ Line: 42 | Upvalues: LocalPlayer (ref) ]]
		local v1, v2 = pcall(LocalPlayer.GetFriendsOnline, LocalPlayer, 3)
		if v1 then
			return v2
		else
			error("Failed To Fetch Friends Online Twice")
		end
	end):andThen(function(p1) --[[ Line: 50 | Upvalues: v1 (ref), t (ref), v2 (ref), Maid (ref), Template (ref), List (ref), SocialService (ref), LocalPlayer (ref), TweenService (ref), Players (ref), Amount (ref) ]]
		v1 = 0
		table.clear(t)
		if v2 then
			v2:DoCleaning()
			v2 = nil
		end
		v2 = Maid.new()
		for i, v in ipairs(p1) do
			v1 = v1 + 1
			local v12 = Template:Clone()
			v12.Parent = List
			v12.Visible = true
			v12:FindFirstChild("LabelName").Text = v.DisplayName
			v12:FindFirstChild("LabelUser").Text = "@" .. v.UserName
			v12:FindFirstChild("Activity").Text = v.LastLocation
			local Activity = v12:FindFirstChild("Activity")
			Activity.TextColor3 = v12:FindFirstChild("Activity").Text == "Website" and Color3.fromRGB(71, 71, 71) or (v12:FindFirstChild("Activity").Text == "Studio" and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(4, 66, 116))
			v2:GiveTask(v12.Activated:Connect(function() --[[ Line: 70 | Upvalues: t (ref), v (copy), SocialService (ref), LocalPlayer (ref), TweenService (ref), v12 (copy) ]]
				if not t[v.VisitorId] then
					return
				end
				local VisitorId = v.VisitorId
				local v1, v2 = pcall(function() --[[ Line: 26 | Upvalues: SocialService (ref), LocalPlayer (ref), VisitorId (copy) ]]
					return SocialService:CanSendGameInviteAsync(LocalPlayer, VisitorId)
				end)
				if not (v1 and v2) then
					return
				end
				SocialService:PromptGameInvite(LocalPlayer, t[v.VisitorId].InviteOption)
				TweenService:Create(v12:FindFirstChild("Invite"), TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
					ImageColor3 = Color3.fromRGB(4, 66, 116)
				}):Play()
				task.wait(0.3)
				TweenService:Create(v12:FindFirstChild("Invite"), TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
					ImageColor3 = Color3.fromRGB(255, 255, 255)
				}):Play()
			end))
			v2:GiveTask(v12.MouseEnter:Connect(function() --[[ Line: 81 | Upvalues: TweenService (ref), v12 (copy) ]]
				TweenService:Create(v12:FindFirstChild("Invite"), TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageTransparency = 0
				}):Play()
			end))
			v2:GiveTask(v12.MouseLeave:Connect(function() --[[ Line: 85 | Upvalues: TweenService (ref), v12 (copy) ]]
				TweenService:Create(v12:FindFirstChild("Invite"), TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageTransparency = 0.7
				}):Play()
			end))
			v2:GiveTask(v12)
			local v3, v4 = pcall(function() --[[ Line: 91 | Upvalues: v12 (copy), Players (ref), v (copy) ]]
				v12:FindFirstChild("User").Image = Players:GetUserThumbnailAsync(v.VisitorId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			if not v3 then
				warn("Error While Fetching Profile Icon For " .. v.UserName .. " Result: " .. v4)
			end
			local v5 = t
			local ExperienceInviteOptions = Instance.new("ExperienceInviteOptions")
			ExperienceInviteOptions.InviteUser = v.VisitorId
			ExperienceInviteOptions.PromptMessage = "Join my game!"
			v5[v.VisitorId] = {
				InviteOption = ExperienceInviteOptions
			}
		end
		Amount.Text = tostring((("[ %* ]"):format(v1)))
	end)
end