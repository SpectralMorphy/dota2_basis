if __basis_loaded then
	return __basis_loaded
end

local basis = {
	loaded = {},
}

local settings = LoadKeyValues('basis.kv')
basis.vscripts_root = settings.vscripts_root or ''

function basis.require(module, target, _optional)
	if basis.loaded[module] then
		return basis.loaded[module]
	end

	local path = module
	if basis.vscripts_root ~= '' then
		path = basis.vscripts_root .. '/' .. path
	end

	local f, err = loadfile(path)
	
	if err then
		if not _optional then
			error(err, 2)
		end
		return
	end

	local env = {
		require = basis.require,
		_M = {},
	}
	setmetatable(env, {
		__index = function(s, k)
			return rawget(env._M, k) or _G[k]
		end,
		__newindex = env._M,
	})
	
	setfenv(f, env)
	local mod = f()

	if mod == nil then
		mod = env._M
	end

	if target then
		for k, v in pairs(mod) do
			target[k] = v
		end
	end

	return mod
end

__basis_loaded = basis
return basis