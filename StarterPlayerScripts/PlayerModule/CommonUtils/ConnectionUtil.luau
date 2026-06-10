-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local v1 = script.Parent
local t = {
	_connectionUtil = require(v1:WaitForChild("ConnectionUtil")).new(),
	_boundEvents = {},
	getLocalPlayer = function() --[[ getLocalPlayer | Line: 53 | Upvalues: Players (copy) ]]
		return Players.LocalPlayer
	end
}
function t.onLocalPlayer(p1) --[[ onLocalPlayer | Line: 57 | Upvalues: t (copy), Players (copy) ]]
	local v1 = t.getLocalPlayer()
	if v1 then
		p1(v1)
	end
	t._connectionUtil:trackConnection("LOCAL_PLAYER", Players:GetPropertyChangedSignal("LocalPlayer"):Connect(function() --[[ Line: 66 | Upvalues: t (ref) ]]
		local v1 = t.getLocalPlayer()
		assert(v1)
		t._getOrCreateBoundEvent("LOCAL_PLAYER"):Fire(v1)
	end))
	return t._getOrCreateBoundEvent("LOCAL_PLAYER").Event:Connect(p1)
end
function t.getCharacter() --[[ getCharacter | Line: 77 | Upvalues: t (copy) ]]
	local v1 = t.getLocalPlayer()
	if v1 then
		return v1.Character
	else
		return nil
	end
end
function t.onCharacter(p1) --[[ onCharacter | Line: 85 | Upvalues: t (copy) ]]
	t._connectionUtil:trackConnection("ON_LOCAL_PLAYER", t.onLocalPlayer(function(p12) --[[ Line: 89 | Upvalues: t (ref), p1 (copy) ]]
		local v1 = t.getCharacter()
		if v1 then
			p1(v1)
		end
		t._connectionUtil:trackConnection("CHARACTER_ADDED", p12.CharacterAdded:Connect(function(p1) --[[ Line: 98 | Upvalues: t (ref) ]]
			assert(p1)
			t._getOrCreateBoundEvent("CHARACTER_ADDED"):Fire(p1)
		end))
	end))
	return t._getOrCreateBoundEvent("CHARACTER_ADDED").Event:Connect(p1)
end
function t.getChild(p1, p2) --[[ getChild | Line: 110 | Upvalues: t (copy) ]]
	local v1 = t.getCharacter()
	if not v1 then
		return nil
	end
	local v2 = v1:FindFirstChild(p1)
	if v2 and v2:IsA(p2) then
		return v2
	else
		return nil
	end
end
function t.onChild(p1, p2, p3) --[[ onChild | Line: 122 | Upvalues: t (copy) ]]
	t._connectionUtil:trackConnection("ON_CHARACTER", t.onCharacter(function(p12) --[[ Line: 126 | Upvalues: t (ref), p1 (copy), p2 (copy), p3 (copy) ]]
		local v1 = t.getChild(p1, p2)
		if not v1 then
			t._connectionUtil:trackConnection("CHARACTER_CHILD_ADDED", p12.ChildAdded:Connect(function(p12_2) --[[ Line: 135 | Upvalues: p1 (ref), p2 (ref), t (ref) ]]
				if p12_2.Name ~= p1 or not p12_2:IsA(p2) then
					return
				end
				t._getOrCreateBoundEvent("CHARACTER_CHILD_ADDED" .. p1 .. p2):Fire(p12_2)
			end))
			return
		end
		p3(v1)
		t._connectionUtil:trackConnection("CHARACTER_CHILD_ADDED", p12.ChildAdded:Connect(function(p12_2) --[[ Line: 135 | Upvalues: p1 (ref), p2 (ref), t (ref) ]]
			if p12_2.Name ~= p1 or not p12_2:IsA(p2) then
				return
			end
			t._getOrCreateBoundEvent("CHARACTER_CHILD_ADDED" .. p1 .. p2):Fire(p12_2)
		end))
	end))
	return t._getOrCreateBoundEvent("CHARACTER_CHILD_ADDED" .. p1 .. p2).Event:Connect(p3)
end
function t._getOrCreateBoundEvent(p1) --[[ _getOrCreateBoundEvent | Line: 149 | Upvalues: t (copy) ]]
	if not t._boundEvents[p1] then
		t._boundEvents[p1] = Instance.new("BindableEvent")
	end
	return t._boundEvents[p1]
end
return t