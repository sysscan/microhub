-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Main = Players.LocalPlayer.PlayerGui:WaitForChild("Main")
local v1 = nil
local v2 = nil
local function CreateInfoText(p1) --[[ CreateInfoText | Line: 11 | Upvalues: v1 (ref), v2 (ref), Main (copy), UserInputService (copy) ]]
	if v1 then
		v1:Destroy()
	end
	if v2 then
		v2:Disconnect()
	end
	v1 = script.HelpHover:Clone()
	v1.Text = p1
	v1.AnchorPoint = Vector2.new(0.5, 0)
	v1.Visible = true
	v1.Parent = Main
	v2 = UserInputService.InputChanged:Connect(function(p1) --[[ Line: 25 | Upvalues: v1 (ref) ]]
		if not v1 then
			return
		end
		if p1.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		v1.Position = UDim2.fromOffset(p1.Position.X, p1.Position.Y + 100)
	end)
end
local function ClearInfoText() --[[ ClearInfoText | Line: 36 | Upvalues: v2 (ref), v1 (ref) ]]
	if v2 then
		v2:Disconnect()
		v2 = nil
	end
	if not v1 then
		return
	end
	v1:Destroy()
	v1 = nil
end
return function() --[[ Line: 47 | Upvalues: Main (copy), CreateInfoText (copy), v2 (ref), v1 (ref) ]]
	for k, v in pairs(Main:GetDescendants()) do
		if v:IsA("ImageButton") and v:GetAttribute("Info") then
			v.MouseEnter:Connect(function() --[[ Line: 50 | Upvalues: CreateInfoText (ref), v (copy) ]]
				CreateInfoText(v:GetAttribute("Info") or v.Name .. " Button")
			end)
			v.MouseLeave:Connect(function() --[[ Line: 53 | Upvalues: v2 (ref), v1 (ref) ]]
				if v2 then
					v2:Disconnect()
					v2 = nil
				end
				if not v1 then
					return
				end
				v1:Destroy()
				v1 = nil
			end)
		end
	end
end