-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
function t.new(p1) --[[ new | Line: 47 | Upvalues: t (copy) ]]
	local v1 = p1 or 0
	return setmetatable({
		_damper = 1,
		_speed = 1,
		_time0 = tick(),
		_position0 = v1,
		_velocity0 = 0 * v1,
		_target = v1
	}, t)
end
function t.Impulse(p1, p2) --[[ Impulse | Line: 62 ]]
	p1.Velocity = p1.Velocity + p2
end
function t.TimeSkip(p1, p2) --[[ TimeSkip | Line: 68 ]]
	local v1 = tick()
	local v2, v3 = p1:_positionVelocity(v1 + p2)
	p1._position0 = v2
	p1._velocity0 = v3
	p1._time0 = v1
end
function t.__index(p1, p2) --[[ __index | Line: 76 | Upvalues: t (copy) ]]
	if t[p2] then
		return t[p2]
	end
	if p2 == "Value" or (p2 == "Position" or p2 == "p") then
		local v1, _ = p1:_positionVelocity(tick())
		return v1
	end
	if p2 == "Velocity" or p2 == "v" then
		local _, v2 = p1:_positionVelocity(tick())
		return v2
	end
	if p2 == "Target" or p2 == "t" then
		return p1._target
	end
	if p2 == "Damper" or p2 == "d" then
		return p1._damper
	end
	if p2 == "Speed" or p2 == "s" then
		return p1._speed
	else
		error(("%q is not a valid member of Spring"):format((tostring(p2))), 2)
	end
end
function t.__newindex(p1, p2, p3) --[[ __newindex | Line: 96 ]]
	local v1 = tick()
	if p2 == "Value" or (p2 == "Position" or p2 == "p") then
		local _, v2 = p1:_positionVelocity(v1)
		p1._position0 = p3
		p1._velocity0 = v2
	elseif p2 == "Velocity" or p2 == "v" then
		local v3, _ = p1:_positionVelocity(v1)
		p1._position0 = v3
		p1._velocity0 = p3
	elseif p2 == "Target" or p2 == "t" then
		local v4, v5 = p1:_positionVelocity(v1)
		p1._position0 = v4
		p1._velocity0 = v5
		p1._target = p3
	elseif p2 == "Damper" or p2 == "d" then
		local v6, v7 = p1:_positionVelocity(v1)
		p1._position0 = v6
		p1._velocity0 = v7
		p1._damper = math.clamp(p3, 0, 1)
	elseif p2 == "Speed" or p2 == "s" then
		local v8, v9 = p1:_positionVelocity(v1)
		p1._position0 = v8
		p1._velocity0 = v9
		p1._speed = if p3 < 0 then 0 else p3
	else
		error(("%q is not a valid member of Spring"):format((tostring(p2))), 2)
	end
	p1._time0 = v1
end
function t._positionVelocity(p1, p2) --[[ _positionVelocity | Line: 129 ]]
	local _position0 = p1._position0
	local _velocity0 = p1._velocity0
	local _target = p1._target
	local _damper = p1._damper
	local _speed = p1._speed
	local v1 = _speed * (p2 - p1._time0)
	local v2 = _damper * _damper
	local v3, v4, v5
	if v2 < 1 then
		local v6 = math.sqrt(1 - v2)
		local v7 = math.exp(-_damper * v1) / v6
		v3 = v7 * math.cos(v6 * v1)
		v4 = v7 * math.sin(v6 * v1)
		v5 = v6
	elseif v2 == 1 then
		v5 = 1
		local v8 = math.exp(-_damper * v1) / v5
		v3 = v8
		v4 = v8 * v1
	else
		local v9 = math.sqrt(v2 - 1)
		local v10 = math.exp((-_damper + v9) * v1) / (2 * v9)
		local v11 = math.exp((-_damper - v9) * v1) / (2 * v9)
		v5 = v9
		v3 = v10 + v11
		v4 = v10 - v11
	end
	return (v5 * v3 + _damper * v4) * _position0 + (1 - (v5 * v3 + _damper * v4)) * _target + v4 / _speed * _velocity0, -_speed * v4 * _position0 + _speed * v4 * _target + (v5 * v3 - _damper * v4) * _velocity0
end
return t