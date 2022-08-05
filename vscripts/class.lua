--[[

• Both client and server

• May be required directly with lua's 'require'

• Requires:
	-- basic

]]

local _M = _M or _G
local basic = require('basic')

--[[

getsuper(instance): class

Get parent class of the given instance

]]

function getsuper(obj)
	return getbase(getclass(obj))
end

--[[

super(): class
• context dependent

Get parent class of the self

]]

function super()
	return getsuper(basic.getlocal(2, 'self'))
end

--[[

extend_class(): class

]]

function extend_class(basetable, inits, statics)
	
end

-----------------------------------------------------

return _M