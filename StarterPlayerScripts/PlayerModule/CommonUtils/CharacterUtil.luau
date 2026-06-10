-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
t.__index = t
function t.new() --[[ new | Line: 25 | Upvalues: t (copy) ]]
	local v2 = setmetatable({}, t)
	v2._connections = {}
	return v2
end
function t.trackConnection(p1, p2, p3) --[[ trackConnection | Line: 33 ]]
	if p1._connections[p2] then
		p1._connections[p2]()
	end
	p1._connections[p2] = function() --[[ Line: 38 | Upvalues: p3 (copy) ]]
		p3:Disconnect()
	end
end
function t.trackBoundFunction(p1, p2, p3) --[[ trackBoundFunction | Line: 41 ]]
	if p1._connections[p2] then
		p1._connections[p2]()
	end
	p1._connections[p2] = p3
end
function t.disconnect(p1, p2) --[[ disconnect | Line: 48 ]]
	if not p1._connections[p2] then
		return
	end
	p1._connections[p2]()
	p1._connections[p2] = nil
end
function t.disconnectAll(p1) --[[ disconnectAll | Line: 55 ]]
	for k, v in pairs(p1._connections) do
		v()
	end
	p1._connections = {}
end
return t