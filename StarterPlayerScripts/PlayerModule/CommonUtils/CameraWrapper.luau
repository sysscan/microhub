-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local ConnectionUtil = require(script.Parent.ConnectionUtil)
local t = {}
t.__index = t
function t.new() --[[ new | Line: 39 | Upvalues: ConnectionUtil (copy), t (copy) ]]
	return setmetatable({
		_enabled = false,
		_camera = workspace.CurrentCamera,
		_callbacks = {},
		_connectionUtil = ConnectionUtil.new()
	}, t)
end
function t._connectCallbacks(p1) --[[ _connectCallbacks | Line: 52 ]]
	p1._camera = workspace.CurrentCamera
	if not p1._camera then
		return
	end
	for v1, v2 in p1._callbacks do
		p1._connectionUtil:trackConnection(v1, p1._camera:GetPropertyChangedSignal(v1):Connect(v2))
		v2()
	end
end
function t.Enable(p1) --[[ Enable | Line: 65 ]]
	if not p1._enabled then
		p1._enabled = true
		p1._cameraChangedConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() --[[ Line: 72 | Upvalues: p1 (copy) ]]
			p1:_connectCallbacks()
		end)
		p1:_connectCallbacks()
	end
end
function t.Disable(p1) --[[ Disable | Line: 79 ]]
	if not p1._enabled then
		return
	end
	p1._enabled = false
	if p1._cameraChangedConnection then
		p1._cameraChangedConnection:Disconnect()
		p1._cameraChangedConnection = nil
	end
	p1._connectionUtil:disconnectAll()
end
function t.Connect(p1, p2, p3) --[[ Connect | Line: 94 ]]
	p1._callbacks[p2] = p3
	if p1._camera then
		p1._connectionUtil:trackConnection(p2, p1._camera:GetPropertyChangedSignal(p2):Connect(p3))
	end
end
function t.Disconnect(p1, p2) --[[ Disconnect | Line: 104 ]]
	p1._connectionUtil:disconnect(p2)
	p1._callbacks[p2] = nil
end
function t.getCamera(p1) --[[ getCamera | Line: 110 ]]
	return p1._camera
end
return t