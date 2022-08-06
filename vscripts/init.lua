if __basis_loaded then
	return __basis_loaded
end

local http
local settings = LoadKeyValues('basis.kv')

local basis = {
	loaded = {},
	vscripts_root = settings.vscripts_root or '',
	vscripts_url = 'https://raw.githubusercontent.com/SpectralMorphy/dota2_basis/main/vscripts/',
	required = {},
	onrequire_callbacks = {},
	REQUIRE_STATE = {
		LOADING = 1,
		DONE = 2,
		ERROR = 3,
		FAILED = 4,
	}
}

local function check_required()
	local ok = true
	for _, state in pairs(basis.required) do
		if state == basis.REQUIRE_STATE.LOADING then
			return
		elseif state == basis.REQUIRE_STATE.ERROR then
			ok = false
		end
	end
	for _, callback in ipairs(basis.onrequire_callbacks) do
		callback(ok)
	end
end

local __optional_require = false
function basis.require(module, target)
	if basis.loaded[module] then
		return basis.loaded[module]
	end

	basis.required[module] = basis.REQUIRE_STATE.LOADING

	local mod = {}

	local function onrequire(f, err)
		if err then
			basis.required[module] = basis.REQUIRE_STATE[__optional_require and 'FAILED' or 'ERROR']
			check_required()
			if __optional_require then
				print(err)
			else
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
		local _M = f()

		if _M == nil then
			_M = env._M
		end

		for _, target in ipairs({mod, target}) do
			for k, v in pairs(_M) do
				target[k] = v
			end
		end

		basis.required[module] = basis.REQUIRE_STATE.DONE
		check_required()
	end

	local path = module
	if basis.vscripts_root ~= '' then
		path = basis.vscripts_root .. '/' .. path
	end

	local f, err = loadfile(path)
	if not err or (err and not http) then
		onrequire(f, err)
	else
		local url = basis.vscripts_url .. path .. '.lua'
		http.require_url(
			url,
			__optional_require,
			function(f, err)
				onrequire(f, err)
			end
		)
	end

	return mod
end

function basis.optional(module, target)
	__optional_require = true
	local res = basis.require(module, target)
	__optional_require = false
	return res
end

function basis.onrequied(callback)
	table.insert(basis.onrequire_callbacks, callback)
	check_required()
end

http = basis.optional('http')

__basis_loaded = basis
return basis