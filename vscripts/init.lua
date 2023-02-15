local basis = {
	path = 'basis',
	origin = '',
	loaded = {},
}

local http

--[[


]]

function basis.getpath(module)
	if type(module) == 'string' then
		return basis.path .. '/' .. module
	elseif module == nil then
		return basis.path
	else
		error('basis.getpath arg #1: expected string or nil, got ' .. tostring(module))
	end
end

--[[

]]

function basis.setpath(path)
	if type(path) ~= 'string' then
		error('basis.setpath arg #1: expected string, got ' .. tostring(path), 2)
	end
	
	-- remove ending slashes from passed path
	path = path:gsub('[\\/]+$', '')

	-- clear old path loader
	package.preload[ basis.getpath('init') ] = nil

	-- set new path
	basis.path = path

	-- set new path loader
	package.preload[ basis.getpath('init') ] = function()
		return basis
	end

	-- reload http module
	http = nil
	pcall(function()
		http = basis.require('http')
	end)
end

--[[

]]

function basis.setorigin(url)
	if type(url) ~= 'string' then
		error('basis.setorigin arg #1: expected string, got ' .. tostring(url), 2)
	end
	

end

--[[

]]

function basis.require(module, target)
	if type(module) ~= 'string' then
		error('basis.require arg #1 (module): expected string, got ' .. tostring(target), 2)
	end
	if target ~= nil and type(target) ~= 'table' then
		error('basis.require arg #2 (target): expected table or nil, got ' .. tostring(target), 2)
	end

	local function clone(lib, target)
		if target then
			for k, v in pairs(lib) do
				target[k] = v
			end
		end
	end

	local loaded = basis.loaded[module]
	if loaded then
		clone(loaded, target)
		return loaded
	else
		loaded = {}
		basis.loaded[module] = loaded
	end

	local function perform(fcode)
		local env = {
			basis = basis,
			_M = loaded,
		}
		setmetatable(env, {
			__index = _G,
		})
		setfenv(fcode, env)

		local lib = fcode()

		clone(lib, target)
		
		return lib
	end
	
	local fcode
	local status, err = pcall(function()
		fcode = loadfile(basis.getpath(module))
	end)

	if http then
		if status then

		else

		end
	else
		if status then
			return perform(fcode)
		else
			error(err, 2)
		end
	end
end

-----------------------------------------------------------

basis.setpath(basis.path)

return basis