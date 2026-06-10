-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local function parsePath(p1) --[[ parsePath | Line: 4 ]]
	local v1 = string.split(p1, "/")
	for i = #v1, 1, -1 do
		if v1[i] == "" then
			table.remove(v1, i)
		end
	end
	return v1
end
local function isManifestResolved(p1, p2) --[[ isManifestResolved | Line: 14 ]]
	local count = 0
	for k in pairs(p1) do
		count = count + 1
	end
	assert(count <= p2, count)
	return count == p2
end
local function v1(p1, p2) --[[ unbindNodeDescend | Line: 24 | Upvalues: v1 (copy) ]]
	if p1.instance == nil then
		return
	end
	p1.instance = nil
	local connections = p1.connections
	if connections then
		for i, v in ipairs(connections) do
			v:Disconnect()
		end
		table.clear(connections)
	end
	if p2 and p1.alias then
		p2[p1.alias] = nil
	end
	local children = p1.children
	if not children then
		return
	end
	for k, v in pairs(children) do
		v1(v, p2)
	end
end
local t = {}
t.__index = t
function t.new(p1, p2) --[[ new | Line: 54 | Upvalues: parsePath (copy), t (copy) ]]
	local t2 = {}
	local count = 1
	for k, v in pairs(p1) do
		t2[k] = parsePath(v)
		count = count + 1
	end
	return setmetatable({
		_boundFn = p2,
		_parsedManifest = t2,
		_manifestSizeTarget = count,
		_dtorMap = {},
		_connections = {},
		_rootInstToRootNode = {},
		_rootInstToManifest = {}
	}, t)
end
function t._startBoundFn(p1, p2, p3) --[[ _startBoundFn | Line: 80 ]]
	local _dtorMap = p1._dtorMap
	local v1 = _dtorMap[p2]
	if v1 then
		v1()
		_dtorMap[p2] = nil
	end
	local v2 = p1._boundFn(p3)
	if not v2 then
		return
	end
	_dtorMap[p2] = v2
end
function t._stopBoundFn(p1, p2) --[[ _stopBoundFn | Line: 96 ]]
	local _dtorMap = p1._dtorMap
	local v1 = _dtorMap[p2]
	if not v1 then
		return
	end
	v1()
	_dtorMap[p2] = nil
end
function t.bindRoot(p1, p2) --[[ bindRoot | Line: 106 | Upvalues: v1 (copy) ]]
	debug.profilebegin("AtomicBinding:BindRoot")
	local _parsedManifest = p1._parsedManifest
	local _rootInstToManifest = p1._rootInstToManifest
	local _manifestSizeTarget = p1._manifestSizeTarget
	assert(_rootInstToManifest[p2] == nil)
	local t = {}
	_rootInstToManifest[p2] = t
	debug.profilebegin("BuildTree")
	local t2 = {
		alias = "root",
		instance = p2
	}
	if next(_parsedManifest) then
		t2.children = {}
		t2.connections = {}
	end
	p1._rootInstToRootNode[p2] = t2
	for k, v in pairs(_parsedManifest) do
		local v2 = t2
		for i, v3 in ipairs(v) do
			local v4 = v2.children[v3] or {}
			if if i == #v then true else false then
				if v4.alias ~= nil then
					error("Multiple aliases assigned to one instance")
				end
				v4.alias = k
			else
				v4.children = v4.children or {}
				v4.connections = v4.connections or {}
			end
			v2.children[v3] = v4
			v2 = v4
		end
	end
	debug.profileend()
	local function v7(p12) --[[ processNode | Line: 160 | Upvalues: t (copy), v7 (copy), p1 (copy), p2 (copy), v1 (ref), _manifestSizeTarget (copy) ]]
		local v12 = assert(p12.instance)
		local children = p12.children
		local alias = p12.alias
		local v2 = not children
		if alias then
			t[alias] = v12
		end
		if not v2 then
			local function processAddChild(p1) --[[ processAddChild | Line: 172 | Upvalues: children (copy), v7 (ref) ]]
				local v1 = children[p1.Name]
				if v1 and v1.instance == nil then
					v1.instance = p1
					v7(v1)
				end
			end
			local function processDeleteChild(p12) --[[ processDeleteChild | Line: 183 | Upvalues: children (copy), p1 (ref), p2 (ref), v1 (ref), t (ref), v12 (copy), v7 (ref) ]]
				local v13 = p12.Name
				local v2 = children[v13]
				if not v2 then
					return
				end
				if v2.instance ~= p12 then
					return
				end
				p1:_stopBoundFn(p2)
				v1(v2, t)
				assert(v2.instance == nil)
				local v3 = v12:FindFirstChild(v13)
				if not v3 then
					return
				end
				local v4 = children[v3.Name]
				if not v4 then
					return
				end
				if v4.instance ~= nil then
					return
				end
				v4.instance = v3
				v7(v4)
			end
			for i, v in ipairs(v12:GetChildren()) do
				local v3 = children[v.Name]
				if v3 and v3.instance == nil then
					v3.instance = v
					v7(v3)
				end
			end
			table.insert(p12.connections, v12.ChildAdded:Connect(processAddChild))
			table.insert(p12.connections, v12.ChildRemoved:Connect(processDeleteChild))
		end
		if not v2 then
			return
		end
		local v4 = t
		local v5 = _manifestSizeTarget
		local count = 0
		for k in pairs(v4) do
			count = count + 1
		end
		assert(count <= v5, count)
		if not (count == v5) then
			return
		end
		p1:_startBoundFn(p2, t)
	end
	debug.profilebegin("ResolveTree")
	v7(t2)
	debug.profileend()
	debug.profileend()
end
function t.unbindRoot(p1, p2) --[[ unbindRoot | Line: 236 | Upvalues: v1 (copy) ]]
	local _rootInstToRootNode = p1._rootInstToRootNode
	local _rootInstToManifest = p1._rootInstToManifest
	p1:_stopBoundFn(p2)
	local v12 = _rootInstToRootNode[p2]
	if v12 then
		v1(v12, (assert(_rootInstToManifest[p2])))
		_rootInstToRootNode[p2] = nil
	end
	_rootInstToManifest[p2] = nil
end
function t.destroy(p1) --[[ destroy | Line: 252 | Upvalues: v1 (copy) ]]
	debug.profilebegin("AtomicBinding:destroy")
	for k, v in pairs(p1._dtorMap) do
		v:destroy()
	end
	table.clear(p1._dtorMap)
	for i, v in ipairs(p1._connections) do
		v:Disconnect()
	end
	table.clear(p1._connections)
	local _rootInstToManifest = p1._rootInstToManifest
	for k, v in pairs(p1._rootInstToRootNode) do
		v1(v, (assert(_rootInstToManifest[k])))
	end
	table.clear(p1._rootInstToManifest)
	table.clear(p1._rootInstToRootNode)
	debug.profileend()
end
return t