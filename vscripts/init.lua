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
end

return basis