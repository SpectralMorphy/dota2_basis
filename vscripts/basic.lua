local basic = _M

-- local debug
local function dp(...)
	-- print(...)
end
local d = {
	dp = function(...)
		-- dprint(...)
	end
}

--[[

# stringify(any): string

Convert object to a string.
Quotes actual strings, to distinguish them from other types.

]]

function basic.stringify(v)
	if isstring(v) then
		return '"' .. v:gsub('"', '\\"') .. '"'
	end
	return tostring(v)
end

--[[

# unpack(args, left?, right?): any...

Adequate unpack without loosing random arguments

@ args: {any...}		-- Array of arguments to unpack
@ left: number = 1		-- First element index
@ right: number			-- Last element index

]]

local __unpack_size
function basic.unpack(args, left, right)
	basic.validate(args, 'table', 'args')
	basic.validate(left, 'int nil', 'left')
	basic.validate(right, 'int nil', 'right')
	local size = __unpack_size
	left = left or 1
	if not size then
		size = 0
		for k, v in pairs(args) do
			if basic.isint(k) and (not size or k > size) then
				size = k
			end
		end
		right = math.min(right or size, size)
	end
	if right < left then
		__unpack_size = nil
	else
		return args[left], basic.unpack(args, left + 1, right)
	end
end

--[[

# ETYPE CONCEPT

Etypes are extension for the basic lua types. They define some extra properties or generalisations.
Etypes have a tree-like structure. Each etype, except of 'any', is based on another etype.
Besides the 8 basic lua types, here are also 9 predefined additional etypes: 2 generalizing, and 7 extending.

Structure of predefined etypes:
• any
	• nil
	• some -- anything which is not nil
		• boolean
		• number
			• int -- integer numbers
		• string
			• etypename -- name of one of the defined etypes.
				• typename -- name of one of the basic lua types.
		• function
		• table
			• complex -- tables with any metadata
				• regex -- compiled regular expression
			• map -- raw tables (without any metadata)
				• array -- table with ordered numeric keys, starting from 1. (table, which can be iterated through 'ipairs')
		• userdata
		• thread

NOTE:
Empty map will be considered as array, while array with nils in the middle will be considered as map.

Here are some functions to establish relations between objects and etypes:

-----------------------------------------------------

# isetype(object, etype): boolean

Check if the given object belongs to the specified etype.

@ object: any
@ etype: etypename

-----------------------------------------------------

# etype(object): etypename

Get the last descendant etype, which the given object belongs to.

@ object: any

-----------------------------------------------------

# USER DEFINED ETYPES

It's possible to define new etypes, using 'defetype' function.
Each etype must be based on any other etype.
etype is determined by its function, which checks if the given object belongs to this etype.
Here is no need in this function to check for an object to belong to parenting etypes. It will be done automatically. (When checking, ascendants conditions will be called before, in descending order)
When defining multiple etypes based on the same one, make sure their check functions does not intersect (cannot both return true for the same object), otherwise it will contradict to etype concept and will not work correctly.

NOTE:
Due to the last term, 'table' etype cannot be used as base, because any of its instance will belong to either 'map' or 'complex'.
By the similar logic, etypes 'any' and 'some' also cannot be extended.

NOTE:
Be attentive with 'etype' function usage. Its behavior is affected every time a new etype is created.

-----------------------------------------------------

# defetype(name, basetype, check)

Define new etype.

@ name: string			-- Name of etype to be created. This string will become a etypename after function call
@ basetype: etypename	-- Etype, on which new etype will be based.
@ check: f(any): boolean	-- Check function. Must return whether the passed object belongs to this etype.

-----------------------------------------------------

EXAMPLE:
```
defetype(
	'falsestring', -- create new etype named 'falsestring'
	'string', -- based on the 'string' etype
	function(v) -- value will have 'falsestring' etype, if matches this condition.
		return v == '' or v == '0' or v == 'false'
	end
)

local s = 'false'
print(etype(s))						--> falsestring
print(isetype(s, 'falsestring'))	--> true
print(isetype(s, 'string'))			--> true
print(isetype(s, 'boolean'))		--> false
```

# SHORTCUTS

An is-like function is assigned to each built-in etype (except of 'any').
This function checks if the object belongs to the appropriate etype, and is just a shortcut for 'isetype' with specific etype parameter.

List of the defined is-like functions goes bellow:

-----------------------------------------------------

# isnil(any): boolean

Check if the given object is nil.

-----------------------------------------------------

# issome(any): boolean

Check if the given object is not nil.

-----------------------------------------------------

# isboolean(any): boolean

Check if the given object is boolean.

-----------------------------------------------------

# isnumber(any): boolean

Check if the given object is a number.

-----------------------------------------------------

# isint(any): boolean

Check if the given object is an integer.

-----------------------------------------------------

# isstring(any): boolean

Check if the given object is a string.

-----------------------------------------------------

# isetypename(any): boolean

Check if the given object is one of the defined etype names.

-----------------------------------------------------

# istypename(any): boolean

Check if the given object is one of the 8 basic lua type names.

-----------------------------------------------------

# isfunction(any): boolean

Check if the given object is a function.

-----------------------------------------------------

# istable(any): boolean

Check if the given object is a table.

-----------------------------------------------------

# iscomplex(any): boolean

Check if the given object is a complex table.

-----------------------------------------------------

# isregex(any): boolean

Check if the given object is a compiled regular expression.

-----------------------------------------------------

# ismap(any): boolean

Check if the given object is a raw table.

-----------------------------------------------------

# isarray(any): boolean

Check if the given object is pure array.

-----------------------------------------------------

# isuserdata(any): boolean

Check if the given object is a userdata.

-----------------------------------------------------

# isthread(any): boolean

Check if the given object is a coroutine.

]]

local etypes = {any = {children = {}}}
local luatypes = {}
local genetypechecker = true

function basic.defetype(typename, basetype, check)
	if type(typename) ~= 'string' then
		basic.argerror( typename, 'string', '1 (etype name)')
	end
	if etypes[typename] then
		basic.argerror( 'etype with passed name already exist (' .. typename .. ')', '1 (etype name)')
	end
	
	local basedata = etypes[basetype]
	if not basedata then
		basic.argerror( basetype, 'etypename', '2 (base etype)')
	end

	if type(check) ~= 'function' then
		basic.argerror( check, 'function', '3 (check function)')
	end
	
	table.insert(basedata.children, typename)
	
	etypes[typename] = {
		check = check,
		base = basetype,
		children = {},
	}

	if genetypechecker then
		basic['is' .. typename] = function(v)
			return basic.isetype(v, typename)
		end
	end
end

function basic.isetype(v, typename)
	local data = etypes[typename]
	if not data then
		basic.argerror( typename, 'etypename', '1 (etype name)')
	end

	if data.base and not basic.isetype(v, data.base) then
		return false
	end
	if data.check then
		return data.check(v)
	end
	return true
end

function basic.etype(v)
	local lastetype = 'any'
	local etypelist = etypes.any.children
	for _ = 1, 99999 do
		local nextetype
		for _, typename in ipairs(etypelist) do
			local data = etypes[typename]
			if data.check(v) then
				nextetype = typename
				etypelist = data.children
				break
			end
		end
		if nextetype then
			lastetype = nextetype
		else
			return lastetype
		end
	end
end

local function typetoetype(typename, base)
	luatypes[typename] = true
	basic.defetype(typename, base, function(v)
		return type(v) == typename
	end)
end

basic.defetype('some', 'any', function(v)
	return v ~= nil
end)

typetoetype('nil', 'any')
typetoetype('boolean', 'some')
typetoetype('number', 'some')
typetoetype('string', 'some')
typetoetype('function', 'some')
typetoetype('table', 'some')
typetoetype('userdata', 'some')
typetoetype('thread', 'some')

basic.defetype('int', 'number', function(v)
	return math.floor(v) == v
end)

basic.defetype('etypename', 'string', function(v)
	return etypes[v] and true or false
end)

basic.defetype('typename', 'etypename', function(v)
	return luatypes[v] or false
end)

basic.defetype('complex', 'table', function(v)
	return getmetatable(v) ~= nil
end)

basic.defetype('map', 'table', function(v)
	return getmetatable(v) == nil
end)

basic.defetype('array', 'map', function(v)
	local i = 1
	for _ in pairs(v) do
		if v[i] then
			i = i + 1
		else
			return false
		end
	end
	return true
end)

genetypechecker = false

--[[

# use(...any)

Define upvalues for usage. Affects some context dependent functions.
Function does nothing by itself. But listed upvalues become registered by the engine, since they are used.

]]

function use()
end

--[[

# locals(level?): map

Get map of all local variables at the given stack level. (including used upvalues)

@ level: int = 1

]]

function basic.locals(level)
	level = (level or 1) + 1
	local vars = {}
	local i

	i = 1
	local f = debug.getinfo(level).func
	while true do
		local name, value = debug.getupvalue(f, i)
		if name == nil then
			break
		else
			vars[name] = value
		end
		i = i + 1
	end

	i = 1
	while true do
		local name, value = debug.getlocal(level, i)
		if name == nil then
			break
		else
			vars[name] = value
		end
		i = i + 1
	end

	return vars
end

--[[

# envcopy(level): table

Generate environment simulation of the given stack level, including local variables and used upvalues.

@ level: int = 1

]]

function basic.envcopy(level)
	level = (level or 1) + 1
	local env = basic.locals(level)
	local genv = getfenv(level)
	setmetatable(env, {
		__index = genv,
		__newindex = genv,
	})
	return env
end

--[[

# quoteout(code): newcode, quotes

@ code: string
@ newcode: string
@ quotes: {string...}

]]

function basic.quoteout(code)
	basic.validate(code, 'string', 'code')

	local quotes = {}
	local new = ''
	local next = 1

	while true do
		local l, r = code:find('[%-%["\']', next)
		if l then
			local case, close
			local c = code:sub(l,r)
			if c == '-' then
				local l2, r2 = code:find('^%-%-%[=*%[', l)
				if l2 then
					r = r2 + 1
					case = 1
					close = '.-%]' .. ('='):rep(r-l-4) .. '%]'
				else
					local match = code:sub(l, l+1)
					if match == '--' then
						r = l + 2
						case = 2
						close = '.-\n'
					end
				end
			elseif c == '[' then
				local l2, r2 = code:find('^%[=*%[', l)
				if l2 then
					r = r2 + 1
					case = 3
					close = '.-%]' .. ('='):rep(r-l-2) .. '%]'
				end
			else
				case = 4
				close = '[^\n]-[^\n\\]' .. c
			end

			if close then
				local cl, cr = code:find('^' .. close, r)
				if case == 2 then
					if cr then
						cr = cr - 1
					end
				elseif not cr then
					basic.argerror('Failed to parse quotes', 'code')
				end

				new = new .. code:sub(next, l-1)

				if case == 1 then
					new = new .. ' '
				elseif case > 2 then
					table.insert(quotes, code:sub(l, cr))
					new = new .. '""'
				end

				if cr then
					next = cr + 1
				else
					break
				end
			else
				new = new .. code:sub(next, l)
				next = r + 1
			end
		else
			new = new .. code:sub(next)
			break
		end
	end

	return new, quotes
end

--[[

# quotein(code, quotes): newcode

@ code: string
@ quotes: {~string...}
@ newcode: string

]]

function basic.quotein(code, quotes)
	basic.validate(code, 'string', 'code')
	basic.validate(quotes, 'array', 'quotes')
	local i = 0
	return code:gsub('""', function()
		i = i + 1
		return quotes[i]
	end)
end

--[[

# braceout(code): newcode, braces

]]

function basic.braceout(code)
	basic.validate(code, 'string', 'code')

	local code, quotes = basic.quoteout(code)
	local braces = {}
	local new = ''
	local next = 1

	local iquote = 0
	local function fquote()
		iquote = iquote + 1
		return quotes[iquote]
	end

	while true do
		local l, r = code:find('[%(%[{]', next)
		if l then
			local close = ({
				['('] = '%)',
				['['] = '%]',
				['{'] = '}',
			})[code:sub(l,r)]
			local cl, cr = code:find(close, r+1)
			if cl then
				local add = code:sub(next, l-1):gsub('""', fquote)
				new = new .. add .. '()'
				local brace = code:sub(l, cr):gsub('""', fquote)
				table.insert(braces, brace)
				next = cr + 1
			else
				basic.argerror('Failed to parse braces', 'code')
			end
		else
			new = new .. code:sub(next):gsub('""', fquote)
			break
		end
	end
	
	return new, braces
end

--[[

# bracein(code, braces): newcode

]]

function basic.bracein(code, brace)
	basic.validate(code, 'string', 'code')
	basic.validate(brace, 'array', 'braces')
	
	local code, quotes = basic.quoteout(code)
	local next = 1
	local index = 1
	local new = ''

	local function f()
		return table.remove(quotes, 1)
	end

	while true do
		local l, r = code:find('%(%)', next)
		if l then
			new = new .. code:sub(next, l-1):gsub('""', f) .. tostring(brace[index])
			index = index + 1
			next = r + 1
		else
			new = new .. code:sub(next):gsub('""', f)
			break
		end
	end

	return new
end

--[[

# splitcode(code, delim): {string...}

@ code: string
@ delim: string	-- Delimiter pattern

]]

function basic.splitcode(code, delim)
	local code, quotes = basic.quoteout(code)
	local code, braces = basic.braceout(code)
	local split = {}
	local next = 1
	local ibrace = 0
	local function fbrace()
		ibrace = ibrace + 1
		return braces[ibrace]
	end
	local iquote = 0
	local function fquote()
		iquote = iquote + 1
		return quotes[iquote]
	end
	local function restore(s)
		local r = s:gsub('%(%)', fbrace):gsub('""', fquote)
		return r
	end
	while true do
		local l, r = code:find(delim, next)
		if l then
			table.insert(split, restore(code:sub(next, l-1)))
			next = r + 1
		else
			table.insert(split, restore(code:sub(next)))
			break
		end
	end
	return split
end

--[[

# runstring(code, env?, vars?, stack?): any...
# runstring(code, env?, stack?): any...
# runstring(code, stack?): any...



]]

function basic.runstring(code, env, vars, stack)
	if basic.isint(env) then
		stack = env
		vars = nil
		env = nil
	elseif basic.isint(vars) then
		stack = vars
		vars = nil
	end
	
	basic.validate(code, 'string', 'code')
	basic.validate(env, 'table boolean nil', 'env')
	basic.validate(vars, 'table nil', 'vars')
	basic.validate(stack, 'int nil', 'vars')

	local metaindex = {}
	stack = (stack or 1) + 1

	if basic.isboolean(env) then
		if env then
			env = basic.envcopy(stack)
		else
			env = {}
		end
	end

	if vars and #vars > 0 then
		local parse, quotes = basic.quoteout(code)
		code = parse:gsub('%$+[%a%d_]+', function(ref)
			return " getfenv(1)['" .. ref:match('%$+') .. "']['" .. ref:match('[%a%d_]+') .. "']"
		end)
		code = basic.quotein(code, quotes)

		env = env or {}
		if env.getfenv ~= getfenv then
			metaindex.getfenv = getfenv
		end

		for level, data in pairs(vars) do
			if not basic.istable(data) then
				basic.argerror('Variables level should be a table, got ' .. basic.stringify(data), 'vars') 
			elseif basic.isint(level) and level > 0 then
				local context = {}
				metaindex[('$'):rep(level)] = context
				for k, v in pairs(data) do
					if basic.isstring(k) or basic.isnumber(k) then
						context[tostring(k)] = v
					else
						basic.argerror('Only string or number keys are allowed, got ' .. basic.stringify(k), 'vars')
					end
				end
			else
				basic.argerror('Contains incorrect level ' .. basic.stringify(level), 'vars')
			end
		end
	end

	local retcode = 'return ' .. code
	local f, err = load(retcode)
	if err then
		f, err = load(code)
		if err then
			error(err, stack)
		end
	end

	if env then
		setmetatable(metaindex, {
			__index = env,
			__newindex = env,
		})
		setfenv(f, metaindex)
	end

	local result = {pcall(f)}

	if result[1] then
		return basic.unpack(result, 2)
	else
		error(result[2], stack)
	end
end

--[[

# argerror(got, expected, argname, stack?, funcname?)
# argerror(msg, argname, stack?, funcname?)

Throw templated error about function argument

@ msg: ~string			-- freely generated main part of the error message
@ got: any				-- incorrect passed argument in error message
@ expected: string		-- list of space-separated expected etype names in error message
@ argname: string		-- argument identifier in error message
@ stack: int = 2		-- error stack trace level
@ funcname: ~string		-- function name in error message

]]

function basic.argerror(got, expected, argname, stack, funcname)
	local fullmsg
	if basic.isint(argname) or basic.isnil(argname) then
		funcname = stack
		stack = argname
		argname = expected
		fullmsg = got
		expected = nil
		got = nil
	end

	if not basic.isstring(argname) then
		basic.argerror( argname, 'string', 'argname')
	end
	if not basic.isnil(stack) and not basic.isint(stack) then
		basic.argerror( stack, 'int nil', 'stack')
	end

	stack = stack or 2
	funcname = funcname or debug.getinfo(stack, 'n').name or 'main'
	
	local msg = tostring(funcname) .. '() arg #' .. argname .. ': '

	if fullmsg then
		error(msg .. tostring(fullmsg), stack + 1)
	else
		error(msg .. 'expected ' .. expected:gsub('%s+', ' or ') .. ', got ' .. basic.stringify(got), stack + 1)
	end
end

--[[

# validate(object, expect, argname, stack?, funcname?)
# validate(object, expect, safe)

Check if function argument matches expected etypes. Throw error otherwise. 

@ object: any			-- check object
@ expect: stirng		-- list of expected etype names, separated by spaces
@ safe: boolean			-- just return false instead of throwing a error
@ argname: string		-- argument identifier in error message
@ stack: int = 2		-- error stack trace level
@ funcname: ~string		-- function name in error message

]]

function basic.validate(object, expect, argname, stack, funcname)
	local safe = false
	if basic.isboolean(argname) then
		safe = argname
		funcname = nil
		stack = nil
		argname = nil
	end
	if not basic.isstring(expect) then
		basic.argerror( expect, 'string', 'expect')
	end
	if not basic.isnil(stack) and not basic.isint(stack) then
		basic.argerror( stack, 'int nil', 'stack')
	end
	for etype in expect:gmatch('%S+') do
		if not basic.isetypename(etype) then
			basic.argerror( 'contains name of unknown etype (' .. etype .. ')', 'expect')
		end
		if basic.isetype(object, etype) then
			return true
		end
	end
	if safe then
		return false
	end
	basic.argerror(object, expect, argname, (stack or 2) + 1)
end

--[[

# args(input, template): output...

]]


function basic.args(args, format, env, stack, funcname)
	basic.validate(args, 'table', '1')
	basic.validate(format, 'string array', 'format')
	basic.validate(env, 'table boolean nil', 'env')
	basic.validate(stack, 'int nil', 'stack')

	stack = stack or 1

	if basic.isboolean(env) then
		if env then
			env = basic.envcopy(stack + 1)
		else
			env = {}
		end
	end

	local conds
	if basic.isstring(format) then
		conds = basic.splitcode(format, ',')
	else
		conds = format
	end

	local output = {}
	local argi = 1

	local function run(code)
		if code then
			return basic.runstring(code, env, {output}, stack + 3)
		end
	end

	local function parse(arg, cond, default)
		local ty = type(cond)
		if ty == 'function' then
			return parse(arg, cond(arg, env, output))

		elseif ty == 'string' then
			local split = basic.splitcode(cond, '|')
			local cond, default = split[1], split[2]

			local etypes = {}
			for etype in cond:gmatch('%S+') do
				if basic.isetypename(etype) then
					etypes[etype] = true
				else
					etypes = nil
					break
				end
			end

			if etypes then
				for etype in pairs(etypes) do
					if basic.isetype(arg, etype) then
						return true, run(default)
					end
				end
				if etypes['nil'] then
					return nil, run(default)
				end
				return false
			else
				if default == nil then
					return parse(arg, run(cond))
				else
					return parse(arg, run(cond)), run(default)
				end
			end

		else
			return cond, default
		end
	end

	for i, cond in ipairs(conds) do
		if basic.isstring(cond) then
			cond = basic.trim(cond)
		end
		local arg = args[argi]
		output[0] = arg
		local match, default = parse(arg, cond)
		output[0] = nil

		if match then
			if arg == nil then
				arg = default
			end
			output[i] = arg
			argi = argi + 1
		elseif match == nil then
			output[i] = default
		else
			basic.argerror(basic.stringify(arg) .. " does not fit the condition " .. basic.stringify(cond), tostring(argi), stack + 1)
		end
	end

	if argi <= (basic.max(basic.keys(args)) or 0) then
		basic.argerror('Passed extra argument ' .. basic.stringify(args[argi]), tostring(argi), stack + 1)
	end

	return basic.unpack(output)
end

--[[

# flags(take?, def, bool?): table

@ take: string | table
@ def: table
@ bool: boolean = false		-- convert flags to boolean?
]]

function basic.flags(take, def, bool)
	basic.validate(take, 'string table nil', 'take')
	basic.validate(def, 'table', 'def')
	basic.validate(bool, 'boolean nil', 'bool')
	local t = {}

	if basic.isstring(take) then
		for flag in take:gmatch('.') do
			local flagname = def[flag]
			if flagname then
				t[flagname] = true
			end
		end

	elseif take ~= nil then
		def = basic.inverse(def)
		for flagname, v in pairs(take) do
			if def[flagname] then
				t[flagname] = v
			end
		end
	end

	if bool then
		for _, flagname in pairs(def) do
			t[flagname] = t[flagname] and true or false
		end
	end

	return t
end

--[[

# wrap()

]]

function basic.wrap(func, inform, outform)
	basic.validate( func, 'function nil', '1')
	func = func or function(...)
		return ...
	end

	return function(...)
		local input
		if inform then

		else
			input = arg
		end

		local output = {func(basic.unpack(input))}
		local result
		if outform then

		else
			result = output
		end

		return basic.unpack(result)
	end
end


--[[

# trim(string): string

Remove spaces from the start/end of the input string

]]

function basic.trim(s)
	basic.validate(s, 'string', '1')
	s = s:gsub('^%s+',''):gsub('%s+$','')
	return s
end

--[[

lprint(string)

Print string by lines. Basicly fixes default print's clamp of long multiline strings.

]]

function basic.lprint(s)
	for line in s:gmatch('[^\n]*\n?') do
		line = line:gsub('\n', '')
		print(line)
	end
end

--[[

# dprint(object: any, options?: map): string?

Deep print the given object.
May print cyclic structures as well.

options: {
	print: f(string) | false = lprint			-- Function to display resulting string. Is set to false, resulting string will be returned.
	expand: f(object, key, options) = istable	-- Function to determine whether passed object should be deep printed.
	iterator: f(object): $forin in key, value	-- Iterator to define fields to print and their order.
	keys: boolean = true						-- Should keys be deep printed?
	meta: boolean = false						-- Should metatable's __index be printed?
	format: format | string = 'simple'			-- Map about object structure decoration. If is string, appropriate map from dprint.format will be used.
	tostring?: format.tostring					-- Override format.tostring function.
}

format: {
	tostring?: f(object, key, options): string	-- String-cast function for printing objects. By default uses stringify function to print basic objects, and doesn't print expanded ones.
	separator: string = ','			-- Separator between KV pairs.
	keyleft: string = '['			-- Prefix for keys.
	keyright: string = '] = '		-- Postfix for keys.
	mapleft = '{'					-- Prefix for expanded object's content.
	mapright = '}'					-- Postfix for expanded object's content.
	mapskip = '{ ... }'				-- Shortcut for repeated expanded object's content.
	space = '  '					-- Generic indent.
	child = space					-- Indent for the start of the child.
	lastspace = space				-- Generic indent for last child's lines.
	lastchild = child				-- Indent for the start of the last child.
}

Predefined dprint formats:
- dprint.format.simple
- dprint.format.tree

]]

basic.dprint = {
	format = {
		simple = {
			tostring = function(v, k, options)
				return options.expand(v, k, options) and '' or basic.stringify(v)
			end,
			separator = ',',
			keyleft = '[',
			keyright = '] = ',
			mapleft = '{',
			mapright = '}',
			mapskip = '{ ... }',
			space = '  ',
			child = '  ',
			lastchild = '  ',
			lastspace = '  ',
		},
		tree = {
			tostring = basic.stringify,
			separator = '',
			keyleft = '[',
			keyright = ']: ',
			mapleft = '',
			mapright = '',
			mapskip = ' ...',
			child = '|--',
			space = '|  ',
			lastchild = '*--',
			lastspace = '   ',
		},
	},
}

local function __dprint_parseformat(format)
	if type(format) == 'string' then
		format = basic.dprint.format[format]
	end
	format = basic.merge({}, format)
	format.lastspace = format.lastspace or format.space
	format.child = format.child or format.space
	format.lastchild = format.lastchild or format.child
	return basic.merge({}, basic.dprint.format.simple, format)
end

local function __dprint(object, options, meta)
	options = options or {}
	local hasmeta = meta and true or false
	local t = {}
	if hasmeta then
		t = options
	else
		t = {
			print = basic.first{options.print, basic.lprint},
			expand = options.expand or basic.istable,
			keys = basic.first{options.keys, true},
			meta = basic.first{options.meta, false},
			iterator = options.iterator or basic.iorder(nil, pairs),
			format = __dprint_parseformat(options.format),
		}
		t.tostring = options.tostring or t.format.tostring
	end

	meta = meta or {
		printed = {},
	}

	local output = ''
	local prefix = meta.prefix or ''
	local closestring = t.format.mapright:len() > 0

	output = output .. t.tostring(object, meta.key, t)

	if (t.keys or not meta.iskey) and t.expand(object, meta.key, t) then
		if meta.printed[object] then
			output = output .. t.format.mapskip
		else
			meta.printed[object] = true

			output = output .. t.format.mapleft

			local children = basic.entries(object, t.iterator)
			local indexkey = {}
			if t.meta then
				local __index = basic.get(getmetatable(object), {'__index'})
				if __index then
					table.insert(children, {indexkey, __index})
				end
			end
			
			local haschild = #children > 0

			local function printkv(k, v, last)
				local ownpostfix = last and t.format.lastchild or t.format.child		
				output = output .. '\n' .. prefix .. ownpostfix .. t.format.keyleft .. k .. t.format.keyright .. v
				if not last then
					output = output .. t.format.separator
				end
			end

			local options = hasmeta and t or basic.merge({}, t, {
				print = false,
			})
			
			if haschild then
				for i, _, e in basic.iindex()(children) do
					local childpostfix = i.last and t.format.lastspace or t.format.space
						
					local skey = e[1] == indexkey and '__index' or __dprint(e[1], options, {
						printed = meta.printed,
						prefix = prefix .. childpostfix,
						iskey = true,
					})
						
					printkv(
						skey,
						__dprint(e[2], options, {
							printed = meta.printed,
							prefix = prefix .. childpostfix,
							key = e[1],
						}),
						i.last
					)
				end
			end

			if (closestring and haschild) or (not closestring and meta.iskey) then
				output = output .. '\n' .. prefix
			end
			output = output .. t.format.mapright
		end
	end

	if t.print then
		t.print(output)
	else
		return output
	end
end

setmetatable(basic.dprint, {
	__call = function(_, object, options)
		__dprint(object, options)
	end,
})

--[[

# linkedlist(elements?): map

@ elements: array	-- array of initial elements

]]

function basic.linkedlist(elements)
	basic.validate( elements, 'array nil', '1')

	local nodes = {}
	local size = 0
	local first, last
	local list = {}

	function list:size()
		return size
	end

	function list:node(index)
		basic.validate( index, 'int nil', '1')
		index = index or size
		if index < 0 then
			index = index + size + 1
		end
		if index == 0 or index == size + 1 then
			return
		end
		if index < 1 or index > size then
			basic.argerror( 'index out of bounds (' .. index .. ')', '1')
		end

		local node = first
		local step = 'next'
		if index > size / 2 then
			node = last
			step = 'prev'
			index = size + 1 - index
		end

		for i = 2, index do
			node = node[step]
		end

		return node
	end

	function list:get(index)
		local node = self:node(index)
		return node and node.value
	end

	function list:valuenode(value)
		local node = first
		while node do
			if node.value == value then
				return node
			end
			node = node.next
		end
	end

	function list:index(value)
		local node = first
		local index = 1
		while node do
			if node.value == value then
				return index
			end
			node = node.next
			index = index + 1
		end
	end

	function list:nodeindex(node)
		local _node = first
		local index = 1
		while _node do
			if _node == node then
				return index
			end
			_node = _node.next
			index = index + 1
		end
	end

	function list:first(condition, start)
		local node = self:firstnode(condition, start)
		if node then
			return node.value
		end
	end

	function list:firstnode(condition, start)
		basic.validate(condition, 'function nil', '1 (condition)')
		basic.validate(start, 'map int nil', '2 (start)')
		condition = condition or function() return true end
		if basic.ismap(start) then
			if not nodes[start] then
				basic.argerror( "passed node isn't from the list", '2')
			end
		elseif start then
			start = self:node(start)
		else
			start = first
		end
		while start do
			if condition(start.value, start) then
				return start
			end
			start = start.next
		end
	end

	function list:put(value, next)
		basic.validate( next, 'map int nil', '2')

		if basic.ismap(next) then
			if not nodes[next] then
				basic.argerror( "passed node isn't from the list", '2')
			end
		elseif basic.isint(next) then
			next = self:node(next)
		end

		local prev
		local node = {
			value = value,
		}

		if next then
			prev = next.prev
			next.prev = node
			node.next = next
		else
			prev = last
			last = node
		end

		if prev then
			prev.next = node
			node.prev = prev
		else
			first = node
		end

		size = size + 1
		nodes[node] = true

		return node
	end

	function list:putafter(value, prev)
		basic.validate( prev, 'map int nil', '2')
		local next
		if basic.ismap(prev) then
			if not nodes[prev] then
				basic.argerror( "passed node isn't from the list", '2')
			end
			next = prev.next
		elseif basic.isint(prev) then
			next = prev + 1
		else
			next = first
		end
		return self:put(value, next)
	end

	function list:pop(node)
		basic.validate( node, 'map int nil', '1')

		if node == nil then
			node = last
		elseif basic.isint(node) then
			node = self:node(node)
		else
			if not nodes[node] then
				basic.argerror( "passed node isn't from the list", '1')
			end
		end

		if not node then
			return
		end

		if node.prev then
			node.prev.next = node.next
		else
			first = node.next
		end

		if node.next then
			node.next.prev = node.prev
		else
			last = node.prev
		end

		size = size - 1
		nodes[node] = nil
	end

	function list:remove(value)
		self:pop(self:valuenode(value))
	end

	function list:splice(start, delete, push)
		basic.validate( start, 'map int nil', 'start')
		basic.validate( delete, 'int', 'delete')
		basic.validate( push, 'array nil', 'push')
		local node
		if basic.ismap(start) then
			if not nodes[start] then
				basic.argerror( "passed node isn't from the list", 'start')
			end
			node = start
			start = list:nodeindex(node)
		elseif basic.isint(start) then
			node = self:node(start)
		else
			start = size + 1
		end
		if delete < 0 then
			delete = size + delete + 2 - start
		end
		local removed = {}

		for i = 1, delete do
			if not node then
				break
			end
			table.insert(removed, node.value)
			list:pop(node)
			node = node.next
		end

		if push then
			for _, value in ipairs(push) do
				node = list:put(value, node).next
			end
		end

		return removed
	end

	function list:nodes()
		local nodes = {}
		local node = first
		while node do
			table.insert(nodes, node)
			node = node.next
		end
		return nodes
	end

	function list:values()
		return basic.remap(
			self:nodes(),
			function(node)
				return node.value
			end
		)
	end

	if elements then
		list:splice(0, 0, elements)
	end

	return list
end

--[[

# regex(pattern, flags): regex

]]

local regex_ident = {}
local regex_flags = {
	i = 'ignorecase',
	m = 'multiline',
	s = 'dotall',
}
local regex_endline = {
	['\n'] = true,
	['\r'] = true,
}
local regex_escapes = {
	-- basic
	['.'] = '.',
	['?'] = '?',
	['*'] = '*',
	['+'] = '+',
	['-'] = '-',
	['('] = '(',
	[')'] = ')',
	['['] = '[',
	[']'] = ']',
	['{'] = '{',
	['}'] = '}',
	['^'] = '^',
	['$'] = '$',
	-- special
	['n'] = '\n',
	['r'] = '\r',
	['t'] = '\t',
	['v'] = '\v',
	['f'] = '\f',
	['b'] = '\b',
	-- complex
	['d'] = '[0-9]',
	['D'] = '[^0-9]',
	['w'] = '[A-Za-z0-9_]',
	['W'] = '[^A-Za-z0-9_]',
	['s'] = '[ \n\r\t\v\f]',
	['S'] = '[^ \n\r\t\v\f]',
}
local regex_escape
local regex_char
local regex_set
regex_escape = function(pattern, i)
	i = i or 1
	-- starts escapted
	if pattern:sub(i,i) == '\\' then
		i = i + 1
		local c = pattern:sub(i,i)
		-- number escape
		if c:match('%d') then
			local l, r = pattern:find('^%d+', i)
			local num = pattern:sub(l,r)
			return string.char(tonumber(num)), r

		-- other escape
		else
			local esc = regex_escapes[c]
			if esc then
				-- set reference
				if esc:sub(1,1) == '[' and esc:sub(-1,-1) == ']' then
					return regex_set(esc), i
				end

				-- basic char
				return esc, i
			end

			-- invalid escape
		end
	end
end
regex_char = function(pattern, i)
	i = i or 1
	local l, r = pattern:find('^\\?.', i)
	if l then
		local c = pattern:sub(l,r)
		-- raw char
		if l == r then
			return c, r, false
		end

		-- escaped char
		c, r = regex_escape(pattern, l)
		return c, r, true
	end

	-- not found
end
regex_set = function(pattern, i)
	i = i or 1
	-- not a set
	if pattern:sub(i,i) ~= '[' then
		return
	end
	
	local start = i + 1
	local next = start
	local set = {
		inverse = false,
	}

	while true do
		local c, r, esc = regex_char(pattern, next)
		local parsed = false
		-- no end bracket
		if not c then
			return next
		end

		if not esc then
			-- inverse flag
			if c == '^' and r == start then
				set.inverse = true
				parsed = true

			-- extra bracket
			elseif c == '[' then
				return r

			-- end bracket
			elseif c == ']' then
				return set, r
			end
		end

		if not parsed then
			-- interval
			if pattern:sub(r+1,r+1) == '-' then
				if basic.isstring(c) then
					local c2, r2 = regex_char(pattern, r+2)
					-- valid right edge for interval
					if basic.isstring(c2) then
						local min = c:byte()
						local max = c2:byte()
						-- right edge is lower than left
						if min > max then
							return r2

						-- valid interval
						else
							table.insert(set, {
								min = min,
								max = max,
							})
							r = r2
						end

					-- invalid right edge for interval
					else
						return r2 or (r+2)
					end

				-- invalid left edge for interval
				else
					return r+1
				end

			-- single char
			else
				table.insert(set, c)
			end

		end
		next = r + 1
	end
end

function basic.regex(pattern, flags)
	basic.validate( pattern, 'regex string nil', '1 (pattern)')
	basic.validate( flags, 'string table nil', '2 (flags)')
	
	local clone = false

	if pattern == nil then
		pattern = ''
	elseif basic.isregex(pattern) then
		clone = true
	end

	-- initial regex object & parse flags
	local re = basic.flags(flags, regex_flags, true)

	-- complie pattern
	if clone then
		re.chain = pattern.chain
	else
		local errindex
		local function buildchain(pattern, i, err)
			local chain = {}
			chain.start = {
				chain = chain,
			}
			chain.final = chain.start

			local s = pattern:sub(i,i)
			local r = i
			local char
			err = err or 0

			-- void string
			if s == '' then
				return chain

			else
				char, r = regex_set(pattern, i)
				-- set
				if char then
					if basic.isnumber(char) then
						errindex = char + err
						error()
					end

				else
					local esc
					char, r, esc = regex_char(pattern, i)
					-- escaped char
					if esc then
						-- word edge
						if char == '\b' then
							char = 'edge'
						end
					
					-- raw char
					else
						-- unbound quantifier
						if char:match('[%+%*%?{}]') then
							errindex = r + err
							error()

						-- dot
						elseif char == '.' then
							char = 'any'

						-- line start
						elseif char == '^' then
							char = 'start'

						-- line end
						elseif char == '$' then
							char = 'end'
						end
					end
				end
			end

			-- basic condition
			if char then
				chain.start.char = char
			end

			-- find quantifier
			i = r + 1
			local quant = pattern:match('^[+*]?%??', i)
			if not quant or quant == '' then
				quant = pattern:match('^{%d+,?%d*}', i)
			end

			-- parse quantifier
			if quant then
				local min, max
				local avoid = false

				if quant == '*' then
				elseif quant == '+' then
					min = 1
				elseif quant == '?' then
					max = 1
				elseif quant == '*?' then
					avoid = true
				elseif quant == '+?' then
					avoid = true
					min = 1
				else
					local com
					min, com, max = quant:match('{(%d+)(,?)(%d*)}')
					min = tonumber(min)
					if com == '' then
						max = min
					else
						max = tonumber(max)
					end
				end

				local node = {
					chain = chain,
					alter = chain.start,
					avoid = avoid,
					min = min,
					max = max,
				}
				chain.final.next = node
				chain.final = node
				chain.start = node

				i = i + quant:len()
			end

			local nextchain = buildchain(pattern, i)
			chain.final.next = nextchain.start
			chain.final = nextchain.final

			return chain
		end

		local status, result = pcall(buildchain, pattern, 1)
		if status then
			d.dp(result, {format='tree'})
			re.chain = result
		else
			if errindex then
				basic.argerror(
					'failed to parse pattern "' .. pattern ..
					'" on char ' .. errindex .. ' "' .. pattern:sub(errindex, errindex) .. '"',
					'1 (pattern)'
				)
			else
				error(result)
			end
		end
	end

	-- exec
	function re:exec(str, i)
		i = i or 1
		local states = basic.linkedlist()
		local chars = {}
		local wp = regex_escapes.w
		local prev
		local c
		if i > 1 then
			c = str:sub(i-1,i-1)
		end

		-- build char sequence
		for j = i, str:len() + 1 do
			prev = c
			c = str:sub(j,j)
			if c == '' then
				c = nil
			end
			if not prev or (self.multiline and prev == '\n') then
				table.insert(chars, 'start')
			end
			local function matchwp(x)
				if not x then
					return false
				end
				return x:match(wp) and true or false
			end
			if matchwp(prev) ~= matchwp(c) then
				table.insert(chars, 'edge')
			end
			if not c or (self.multiline and c == '\n') then
				table.insert(chars, 'end')
			end
			if c then
				table.insert(chars, c)
			end
		end

		local function matchc(c, cond)
			-- raw match
			if c == cond then
				return true
			end

			-- case match
			if self.ignorecase and basic.isstring(cond) and c:lower() == cond:lower() then
				return true
			end

			-- zero-length element
			if c:len() > 1 then
				return nil
			end

			-- dot match
			if cond == 'any' then
				return self.dotall or not regex_endline[c]
			end

			-- complex match
			if basic.istable(cond) then
				-- interval match
				if cond.min ~= nil then
					local n = c:byte()
					local ok = (n >= cond.min and n <= cond.max)
					if not ok and self.ignorecase then
						n = c:lower():byte()
						local min = string.char(cond.min):lower():byte()
						local max = string.char(cond.max):lower():byte()
						ok = (n >= min and n <= max)
					end
					return ok

				-- set match
				elseif cond.inverse ~= nil then
					return basic.some(
						cond,
						function(cond)
							return matchc(c, cond)
						end,
						ipairs
					) ~= cond.inverse
				end
			end

			-- unknown
			return false
		end

		local index = i
		for _, c in ipairs(chars) do
			local break2 = false
			local ischar = (c:len() == 1)
			dp('=== ' .. c .. ' =============')

			states:put({
				match = '',
				node = self.chain.start,
				left = index,
				count = {},
			})
			
			local statenode = states:node(1)
			while statenode do
				local state = statenode.value
				dp('-- ' .. state.match .. ' --')

				-- skip matched
				if state.right then
					dp('SKIP')
					statenode = statenode.next

				-- compare char
				elseif state.node.char then
					local ok = matchc(c, state.node.char)
					dp('COMP', state.node.char, ok)
					if ok == true then
						if ischar then
							state.match = state.match .. c
						end
						state.node = state.node.next
						if state.node == state.node.chain.final then
							if ischar then
								state.right = index
							else
								state.right = index - 1
							end
							dp('FINISH')
							if states:get(1) == state then
								dp('FOUND')
								break2 = true
							else
								states:splice(statenode.next, -1)
							end
							break
						end
					elseif ok == false then
						dp('REJECT')
						states:pop(statenode)
						local best = states:get(1)
						if best and best.right then
							dp('FOUND', best.match)
							break2 = true
							break
						end
					end
					statenode = statenode.next

				-- alternate
				else
					if state.node.alter then
						local allow = true
						local count = state.count[state.node.alter] or 0
						if state.node.max and count >= state.node.max then
							allow = false
						end

						if allow then
							local alter = {
								left = state.left,
								match = state.match,
								node = state.node.alter,
								count = basic.remap(state.count),
							}

							alter.count[state.node.alter] = (alter.count[state.node.alter] or 0) + 1
							
							local alternode
							if state.node.avoid then
								dp('SPLIT DOWN')
								alternode = states:putafter(alter, statenode)
							else
								dp('SPLIT UP')
								alternode = states:put(alter, statenode)
							end

							local must = false
							if state.node.min and state.node.min > count then
								must = true
							end

							if must then
								states:pop(statenode)
							else
								state.count[state.node.alter] = nil
							end

							if must or not state.node.avoid then
								statenode = alternode
							end
						end
					end

					state.node = state.node.next
				end
			end

			if break2 then
				break
			end

			if ischar then
				index = index + 1
			end
		end

		local state = states:first(function(state)
			return state.right
		end)

		if state then
			return {
				match = state.match,
				left = state.left,
				right = state.right,
			}
		end
	end

	-- refresh
	function re:refresh()
		lastindex = 0
	end

	-- regex etype identifier and self-call
	setmetatable(re, {
		regex = regex_ident,
		__call = re.exec,
	})

	return re
end

basic.defetype('regex', 'complex', function(v)
	return getmetatable(v).regex == regex_ident
end)

function basic.isregex(v)
	return basic.isetype('v', 'regex')
end

--[[

# match(* string, pattern, flags?, left?): match?, matchleft?, matchright?

@ string
@ pattern: regex | string
@ flags: table | string
@ left: int = 1
@ match: string
@ matchleft: int
@ matchright: int

]]

local match_flags
function basic.match(...)
	local str, pattern, flags, left = basic.args(
		{...},
		'string, regex string, table string nil, int nil'
	)

	if not match_flags then
		match_flags = basic.copy({
			g = 'global',
			y = 'sticky',
		}, regex_flags)
	end

	flags = basic.flags(flags, match_flags)

	-- compile regex
	if basic.isstring(pattern) then
		pattern = basic.regex(pattern, flags)
	end

	-- global match
	if flags.global then
		local list
		local next = left
		while true do
			local match, l, r = pattern:exec(str, next)
			if match then
				if not list then
					list = {}
				end
				table.insert(list, match.match)
				next = math.max(match.left, match.right) + 1
			else
				return list
			end
		end

	-- single match
	else
		local match = pattern:exec(str, left)
		if match then
			return match.match, match.left, match.right
		end
	end
end

--[[

# get(object, path?): any

]]

function basic.get(object, path)
	if not basic.istable(object) then
		return
	end
	local key = table.remove(path, 1)
	if key == nil then
		return object
	end
	return basic.get(object[key], path)
end

-- function basic.

--[[

# compare(left, right): boolean

@ left
@ right

]]

local compare_types

function basic.compare(left, right)
	if not compare_types then
		compare_types = basic.inverse{
			'nil',
			'boolean',
			'number',
			'string',
			'userdata',
			'table',
			'function',
			'thread',
		}
	end
	local t1 = compare_types[type(left)]
	local t2 = compare_types[type(right)]
	if t1 ~= t2 then
		return t1 < t2
	end
	if basic.isnumber(left) then
		return left < right
	end
	return tostring(left) < tostring(right)
end

--[[

# merge(target, sources...): table

Deeply merge all the given source tables in order to the target table.
Target table will be modified and returned (if it's a table).

NOTE:
Doesn't throw a error nor endless loops with cyclic structures. But resulted table's structure may be unpredictable, so try to avoid it.

WARNING:
If you need to generate a new table by merging other 2+, use first parameter as {}, then put tables to merge. Otherwise first table will be modified in place.

@ target: any
@ ... sources: any

]]

local __merge_ignore
function basic.merge(left, right, ...)
	local result
	local topcall = (__merge_ignore == nil)
	if topcall then
		__merge_ignore = {}
	end

	if right == nil then
		result = left
	elseif not basic.istable(right) then
		result = basic.merge(right, ...)
	elseif not basic.istable(left) then
		result = basic.merge({}, right, ...)
	else
		__merge_ignore[left] = left
		__merge_ignore[right] = left
		for k, v in pairs(right) do
			local leftv = left[k]
			left[k] = __merge_ignore[leftv] or __merge_ignore[v] or basic.merge(leftv, v)
		end
		__merge_ignore[left] = nil
		__merge_ignore[right] = nil
		result = basic.merge(left, ...)
	end

	if topcall then
		__merge_ignore = nil
	end

	return result
end

--[[

# copy(target, sources...): table

Shallow merge all the given source tables in order to the target table.
Target table will be modified and returned (if it's a table).

WARNING:
If you need to generate a new table by merging other 2+, use first parameter as {}, then put tables to merge. Otherwise first table will be modified in place.

@ target: any
@ ... sources: any

]]

function basic.copy(left, right, ...)
	if right == nil then
		return left
	elseif not basic.istable(right) then
		return basic.copy(right, ...)
	elseif not basic.istable(left) then
		return basic.copy({}, right, ...)
	else
		for k, v in pairs(right) do
			left[k] = v
		end
		return basic.copy(left, ...)
	end
end


--[[

# xpairs(table): iterator...

Execute appropriate iterator for table (pairs or ipairs)

]]

function basic.xpairs(object)
	basic.validate( object, 'table', '1')
	return (basic.isarray(object) and ipairs or pairs)(object)
end

--[[

# ipack(iterate?): iterator

Pack iterator, compressing it's variables into array on each iteration step.

@ iterate: f(object): $iterate for any... = xpairs
@ iterator: f(object): $forin for {any...}

]]

function basic.ipack(iterate)
	basic.validate( iterate, 'function nil', 'iterate')
	iterate = iterate or basic.xpairs

	return function(object)
		local iter, obj, args = (function(iter, obj, ...)
			return iter, obj, arg
		end)(iterate(object));

		return function(obj, packed)
			packed = {iter(obj, basic.unpack(packed))}
			if #packed > 0 then
				return packed
			end
		end, obj, args
	end
end

--[[

# iindex(iterate?): iterator

@ iterate: $iterate for any... = xpairs
@ iterator: $forin for int, any...

]]

function basic.iindex(iterate)
	basic.validate( iterate, 'function nil', 'iterate')
	return function(object)
		local entries = basic.entries(object, iterate)
		local i = 0
		local l = #entries
		return function()
			i = i + 1
			local entry = entries[i]
			if entry then
				return {
					index = i,
					first = (i == 1),
					last = (i == l),
				}, basic.unpack(entry)
			end
		end
	end
end

--[[

# ifilter(condition, iterate?): iterator

@ condition: f(args...): ~boolean			--
@ iterate: f(object): $iterate for args...	--
@ iterator: f(object): $forin for args...	-- Resulting iterator over filtered fields

]]

function basic.ifilter(condition, iterate)
	basic.validate( condition, 'function', 'condition')
	basic.validate( iterate, 'function nil', 'iterate')
	iterate = iterate or basic.xpairs

	return function(object)
		local entreis = {}
		for args in basic.ipack(iterate)(object) do
			if condition(basic.unpack(args)) then
				table.insert(entreis, args)
			end
		end
		
		local i = 1
		return function()
			local args = entreis[i]
			if args then
				i = i + 1
				return basic.unpack(args)
			end
		end
	end
end

--[[

# istep(* step?, left?, right?, iterate?): iterator

@ step: int
@ start: int
@ finish: int
@ iterate: f(object): $iterate for args... = xpairs
@ iterator: f(object): $forin for args...

]]

function basic.istep(...)
	local step, start, finish, iterate = basic.args(
		{...},
		'int nil | 1, int nil | 1, int nil, function nil | xpairs',
		basic
	)
	if step == 0 then
		basic.argerror( 'step size cannot be 0', 'step')
	end

	-- step = step or 1
	-- filter = filter or basic.isnumber
	-- iterator = iterator or basic.xpairs
	-- local rise = step > 0
	
	-- return function(object)
	-- 	local indexes = {}
	-- 	local values = {}
	-- 	for index, value in iterator(object) do
	-- 		if filter(index) then
	-- 			table.insert(indexes, index)
	-- 			values[index] = value
	-- 		end
	-- 	end
	-- 	table.sort(indexes)
	-- 	local len = #indexes
	-- 	local i = start or (rise and 1 or len)
	-- 	local l = finish or (rise and len or 1)
	-- 	if i < 1 then
	-- 		i = i + math.ceil((1 - i) / step) * step
	-- 	elseif i > l then
	-- 		i = i - math.ceil((i - l) / step) * step
	-- 	end

	-- 	return function()
	-- 		if (i > l) == rise then
	-- 			return
	-- 		end
	-- 		local index = indexes[i]
	-- 		if not index then
	-- 			return
	-- 		end
	-- 		return index, values[index], i
	-- 	end
	-- end
end

--[[

# iorder(* compare?, rise?, iterate?, index?): iterator

@ compare: f(key1, key2): boolean		-- Comparision function for custom iteration order 
	@ rise: boolean = true 				-- Iterate in ascending order
@ iterate: @iterate for ...args			
-- By default iterates all fields of the table with numberic keys
@ index: int | f(...args): some = 1
-- Determines index to sort over.
-- If int, index is iteration variable on the passed position
-- If function, accepts all variables, and should return index
@ iterator: @forin for ...args			-- Resulting ordered iterator

]]

function basic.iorder(...)
	local compare, rise, iterate, index = basic.args(
		{...},
		'function nil | compare, boolean nil | true, function nil | ifilter(isnumber), function int nil | 1',
		basic
	)
	if basic.isint(index) then
		local i = index
		index = function(...)
			return arg[i]
		end
	end
	local _compare = compare
	compare = function(a, b)
		return rise == _compare(a, b)
	end

	return function(object)
		local order = {}
		for args in basic.ipack(iterate)(object) do
			local index = index(basic.unpack(args))
			table.insert(order, {
				index = index,
				entries = args,
			})
		end
		table.sort(order, function(a, b)
			return compare(a.index, b.index)
		end)
		local i = 1

		return function()
			local data = order[i]
			if data then
				i = i + 1
				return basic.unpack(data.entries)
			end
		end
	end
end

--[[

# remap(object, convert, iterate?): map

Create new map from the object elements.

@ object: any
@ convert: f(value, key): newvalue, newkey?		
-- Function to generate appropriate field in the new map.
-- Accepts value and key from the iteration.
-- Should return new field value and key.
-- If new key is not return, key from the iteration is used instead.
@ iterate: f(object): $forin for key, value = xpairs	-- Key-value iterator for the passed object.

]]

function basic.remap(object, convert, iterate)
	basic.validate( convert, 'function nil', '2')
	basic.validate( iterate, 'function nil', '3')
	convert = convert or function(v)
		return v
	end
	iterate = iterate or basic.xpairs
	local new = {}
	for k, v in iterate(object) do
		local newv, newk = convert(v, k, object)
		if newk == nil then
			newk = k
		end
		new[newk] = newv
	end
	return new
end

--[[

# inverse(object, iterate?): map

Swap object's keys and values

@ object: any
@ iterate: $forin for key, value = xpairs

]]

function basic.inverse(object, iterate)
	basic.validate( iterate, 'function nil', '2')
	return basic.remap(object, function(k, v)
		return v, k
	end)
end

--[[

# reverse(list, iterate?)

]]

function basic.reverse(list, iterate)
	basic.validate(iterate, 'function nil', '2')
	iterate = iterate or basic.xpairs
	local values = basic.values(list, iterate)
	local len = #values
	local reversed = {}
	for i, v in ipairs(values) do
		reversed[len+1-i] = v
	end
	return reversed
end

--[[

# first(list, check?, iterate?): value, key

Find first element in array, which matches condition.
Returns nil, if match wasn't found.
If condition isn't passed, first element of array is returned.

@ list: any												--
@ check: f(value, key): ~boolean						--
@ iterate: f(list): @forin for key, value = iorder()	-- 
@ value: any						-- Found value
@ key: any							-- Found key (index)

]]

function basic.first(list, check, iterate)
	-- optimisation
	if check == nil and iterate == nil then
		local min
		for i, v in pairs(list) do
			if type(i) == 'number' then
				if not min or i < min then
					min = i
				end
			end
		end
		return list[min], min
	end

	check = check or function()
		return true
	end
	iterate = iterate or basic.iorder()
	for k, v in iterate(list) do
		if check(v, k) then
			return v, k
		end
	end
end

--[[

# reduce(list, reducer, value?, iterate?): any
# reduce(list, first, reducer, iterate?): any

]]

function basic.reduce(list, reducer, value, iterate)
	local first = false
	if basic.isboolean(reducer) then
		first = reducer
		reducer = value
		value = nil
	end

	basic.validate(reducer, 'function nil', 'reducer')
	basic.validate(iterate, 'function nil', 'iterate')
	iterate = iterate or basic.xpairs

	for k, v in iterate(list) do
		if first then
			value = v
			first = false
		else
			value = reducer(value, v, k, list)
		end
	end

	return value
end

--[[

# max(list, rise?, compare?, iterate?): boolean
# max(list, compare?, iterate?): boolean

@ list: any												-- Values container
@ rise: boolean = true									-- Should select maximal element, or minimal
@ compare: f(key1, key2): boolean						-- Comparision function. Return if key1 < key2
@ iterate: f(list): @iterate for key, value = iorder()	-- Key-value iterator over the container

]]


function basic.max(list, rise, compare, iterate)
	if basic.isfunction(rise) then
		iterate = compare
		compare = rise
		rise = nil
	end

	basic.validate(rise, 'boolean nil', 'rise')
	basic.validate(compare, 'function nil', 'rise')
	basic.validate(iterate, 'function nil', 'iterate')
	compare = compare or basic.compare

	if rise == nil then
		rise = true
	end
	
	local max = basic.reduce(list, function(max, value, key)
		if compare(max.value, value) == rise then
			return {
				value = value,
				key = key,
			}
		end
		return max
	end, {}, iterate)

	return max.value, max.key
end

--[[

# each(list, check?, iterator?): boolean

@ list: any
@ check: f(value, key): ~boolean

]]

function each()
end

--[[

# some(list, check?, iterate?): boolean

@ list: any
@ check: f(value, key): ~boolean
@ iterate: f(list): $forin for key, value = xpairs
]]

function basic.some(list, check, iterate)
	basic.validate(check, 'function', 'check')
	basic.validate(iterate, 'function nil', 'iterate')
	iterate = iterate or basic.xpairs
	return basic.first(list, check, iterate) ~= nil
end

--[[

# array(object, iterate, index?): array
# array(object, iterate, convert?): array

@ object: any								--
@ iterate: f(object): $iterate for args...	--
@ index: int = 1							--
@ convert: f(args...): some					--

]]

function basic.array(object, iterate, index)
	basic.validate( iterate, 'function', '2 (iterator)')
	basic.validate( index, 'function int nil', '3')
	index = index or 1
	if basic.isint(index) then
		local i = index
		index = function(...)
			return arg[i]
		end
	end
	local array = {}
	for args in basic.ipack(iterate)(object) do
		table.insert(array, index(basic.unpack(args)))
	end
	return array
end

--[[

# entries(object, iterate): {args...}

@ object: any
@ iterate: $iterate for args...

]]

function basic.entries(object, iterate)
	basic.validate( iterate, 'function nil', '2')
	return basic.array(object, basic.ipack(iterate or basic.xpairs))
end

--[[

# keys(table): array

Gernerate array of table keys

]]

function basic.keys(object, iterate)
	basic.validate( object, 'table', '1')
	basic.validate( iterate, 'function nil', '2')
	return basic.array(object, iterate or basic.xpairs)
end

--[[

# values(table): array

Generate array of table variables

]]

function basic.values(object, iterate)
	basic.validate( object, 'table', '1')
	basic.validate( iterate, 'function nil', '2')
	return basic.array(object, iterate or basic.xpairs, 2)
end

-----------------------------------------------------

return basic