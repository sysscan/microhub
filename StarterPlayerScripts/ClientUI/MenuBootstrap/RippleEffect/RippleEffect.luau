-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
local function Tween(p1, p2, p3) --[[ Tween | Line: 3 ]]
	game:GetService("TweenService"):Create(p1, TweenInfo.new(p3), p2):Play()
end
function t.AddEffect(p1, p2, p3) --[[ AddEffect | Line: 9 ]]
	local X = p1.AbsoluteSize.X
	local Y = p1.AbsoluteSize.Y
	local v1 = UDim2.new(0, p2.X - p1.AbsolutePosition.X, 0, p2.Y - p1.AbsolutePosition.Y)
	local BackgroundColor3 = p1.BackgroundColor3
	local R = BackgroundColor3.R
	local G = BackgroundColor3.G
	local B = BackgroundColor3.B
	p1.ClipsDescendants = true
	local Ripple = Instance.new("Frame", p1)
	Ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Ripple.BackgroundTransparency = 1
	Ripple.Name = "Ripple"
	Ripple.Interactable = false
	Ripple.ZIndex = 999999
	Ripple.Size = UDim2.new(0, 50, 0, 50)
	local ImageLabel = Instance.new("ImageLabel")
	ImageLabel.Size = UDim2.new(1, 0, 1, 0)
	ImageLabel.ImageTransparency = 0.5
	ImageLabel.BackgroundTransparency = 1
	ImageLabel.Image = "rbxassetid://92093897423387"
	ImageLabel.Parent = Ripple
	ImageLabel.ScaleType = Enum.ScaleType.Fit
	Ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	Ripple.Position = v1
	Ripple:TweenSize(UDim2.fromOffset(math.max(X, Y), (math.max(X, Y))), "Out", "Sine", p3)
	game:GetService("TweenService"):Create(ImageLabel, TweenInfo.new(p3), {
		ImageTransparency = 1
	}):Play()
	wait(p3)
	Ripple:Destroy()
end
return t