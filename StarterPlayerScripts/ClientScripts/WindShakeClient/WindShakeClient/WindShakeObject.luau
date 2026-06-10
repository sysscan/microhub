-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
return {
	new = function(p1) --[[ new | Line: 10 ]]
		local t = {}
		local v1 = p1:GetAttribute("WindPower")
		local v2 = p1:GetAttribute("WindSpeed")
		local v3 = p1:GetAttribute("WindDirection")
		t.WindPower = if typeof(v1) == "number" then v1 else nil
		t.WindSpeed = if typeof(v2) == "number" then v2 else nil
		t.WindDirection = if typeof(v3) == "Vector3" then if v3.Magnitude > 0 then v3.Unit else Vector3.new(0, 0, 0) else nil
		t.PivotOffset = if p1:IsA("BasePart") then p1.PivotOffset else nil
		t.PivotOffsetInverse = if typeof(t.PivotOffset) == "CFrame" then t.PivotOffset:Inverse() else nil
		local v9 = p1:GetAttributeChangedSignal("WindPower"):Connect(function() --[[ Line: 30 | Upvalues: v1 (ref), p1 (copy), t (copy) ]]
			v1 = p1:GetAttribute("WindPower")
			t.WindPower = if typeof(v1) == "number" then v1 else nil
		end)
		local v10 = p1:GetAttributeChangedSignal("WindSpeed"):Connect(function() --[[ Line: 35 | Upvalues: v2 (ref), p1 (copy), t (copy) ]]
			v2 = p1:GetAttribute("WindSpeed")
			t.WindSpeed = if typeof(v2) == "number" then v2 else nil
		end)
		local v11 = p1:GetAttributeChangedSignal("WindDirection"):Connect(function() --[[ Line: 40 | Upvalues: v3 (ref), p1 (copy), t (copy) ]]
			v3 = p1:GetAttribute("WindDirection")
			t.WindDirection = if typeof(v3) == "Vector3" then if v3.Magnitude > 0 then v3.Unit else Vector3.new(0, 0, 0) else nil
		end)
		local v12 = if p1:IsA("BasePart") then p1:GetPropertyChangedSignal("PivotOffset"):Connect(function() --[[ Line: 49 | Upvalues: t (copy), p1 (copy) ]]
	t.PivotOffset = p1.PivotOffset
	t.PivotOffsetInverse = t.PivotOffset:Inverse()
end) else nil
		function t.Destroy(p1) --[[ Destroy | Line: 57 | Upvalues: v9 (copy), v10 (copy), v11 (copy), v12 (ref), t (copy) ]]
			v9:Disconnect()
			v10:Disconnect()
			v11:Disconnect()
			if v12 then
				v12:Disconnect()
			end
			table.clear(t)
		end
		return t
	end
}