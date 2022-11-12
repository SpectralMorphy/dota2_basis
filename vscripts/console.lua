if IsClient() then
	return
end

local http = optional('http')

if http then
	http.panorama_module('basis/console', basis.panorama_url .. 'console.js')
	-- http.
end

basis.panorama_imprt('basis/console')