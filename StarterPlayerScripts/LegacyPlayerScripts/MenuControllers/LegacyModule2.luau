-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Frames = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("Canvas"):WaitForChild("Frames")
local ScrollingFrame = Frames:FindFirstChild("Shop"):WaitForChild("Products"):WaitForChild("ScrollingFrame")
local Gift = Frames:FindFirstChild("Shop"):FindFirstChild("Gift")
local Skip = Gift:WaitForChild("Skip")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local Notify = require(ReplicatedStorage.Game.Modules:WaitForChild("Notify"))
local t = {}
return function() --[[ Line: 21 | Upvalues: ScrollingFrame (copy), MarketplaceService (copy), LocalPlayer (copy), Packets (copy), Gift (copy), Players (copy), t (copy), Notify (copy), Skip (copy) ]]
	for k, v in pairs(ScrollingFrame:GetDescendants()) do
		if type((tonumber(v.Name))) == "number" then
			local Button = v:FindFirstChild("Button")
			local Gift_2 = v:FindFirstChild("Gift")
			local ButtonAd = v:FindFirstChild("ButtonAd")
			Button.Activated:Connect(function() --[[ Line: 29 | Upvalues: v (copy), MarketplaceService (ref), LocalPlayer (ref) ]]
				if v:GetAttribute("Gamepass") == true then
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, (tonumber(v.Name)))
				else
					MarketplaceService:PromptProductPurchase(LocalPlayer, (tonumber(v.Name)))
				end
			end)
			if Gift_2 then
				Gift_2.Activated:Connect(function() --[[ Line: 38 | Upvalues: Packets (ref), v (copy), MarketplaceService (ref), LocalPlayer (ref), v (copy), Gift (ref), Players (ref), t (ref), Notify (ref) ]]
					if Packets.GetGiftTokens:Fire(v:GetAttribute("GiftID")) == 0 then
						MarketplaceService:PromptProductPurchase(LocalPlayer, v:GetAttribute("GiftID"))
						return
					end
					Gift.Visible = true
					for k, v2 in pairs(Players:GetPlayers()) do
						if v2 ~= LocalPlayer then
							local v1 = script.PlayerTemplate:Clone()
							v1.Parent = Gift.List
							v1:FindFirstChild("Display").Text = v2.DisplayName
							v1:FindFirstChild("User").Text = ("@%*"):format(v2.Name)
							v1:FindFirstChild("PlayerIcon").Image = Players:GetUserThumbnailAsync(v2.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
							local function f3() --[[ Line: 52 | Upvalues: Packets (ref), v (ref), v2 (copy), Notify (ref) ]]
								Notify("Gift", (Packets.GiftGamepass:Fire(tonumber(v.Name), v:GetAttribute("GiftID"), v2.Name)))
							end
							table.insert(t, v1.Button.Activated:Connect(f3))
						end
					end
				end)
			end
			if ButtonAd and tonumber(v.Name) == 3506671887 then
				local FrameLock = ButtonAd:FindFirstChild("FrameLock")
				local v4 = false
				if FrameLock then
					task.spawn(function() --[[ Line: 66 | Upvalues: Packets (ref), v4 (ref), FrameLock (copy) ]]
						local v1 = Packets.GetAdCooldown:Fire()
						if type(v1) == "number" and v1 > 0 then
							v4 = true
							FrameLock.Visible = true
							task.wait(v1)
						end
						FrameLock.Visible = false
						v4 = false
					end)
					ButtonAd.Activated:Connect(function() --[[ Line: 80 | Upvalues: v4 (ref), FrameLock (copy), Packets (ref) ]]
						if v4 then
							return
						end
						v4 = true
						FrameLock.Visible = true
						local v1, v2 = Packets.ShowAd:Fire(3506671887)
						if v1 then
							task.spawn(function() --[[ Line: 87 | Upvalues: v2 (copy), FrameLock (ref), v4 (ref) ]]
								task.wait(v2)
								FrameLock.Visible = false
								v4 = false
							end)
							return
						end
						local v3 = Packets.GetAdCooldown:Fire()
						if type(v3) == "number" and v3 > 0 then
							task.spawn(function() --[[ Line: 95 | Upvalues: v3 (copy), FrameLock (ref), v4 (ref) ]]
								task.wait(v3)
								FrameLock.Visible = false
								v4 = false
							end)
						else
							FrameLock.Visible = false
							v4 = false
						end
					end)
				end
			end
		end
	end
	Skip.Activated:Connect(function() --[[ Line: 111 | Upvalues: t (ref), Gift (ref) ]]
		for k, v in pairs(t) do
			v:Disconnect()
		end
		for k, v in pairs(Gift.List:GetChildren()) do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end
		table.clear(t)
		Gift.Visible = false
	end)
end