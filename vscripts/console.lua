local basis = __basis_loaded
local http = optional('http')

if http then
	http.panorama_module('basis/console', basis.panorama_url .. 'console.js')
	-- http.
end

