--[[

• Both client and server

• May be required directly with lua's 'require'

]]

local _M = _M or _G

--[[

# ETYPE SECTION

Etypes are extension for the basic lua types. They define some extra properties or generalisations.
Etypes have a tree-like structure. Each etype, except of 'any', is based on another etype.
Besides the 8 basic lua types, here are also 8 predefined additional etypes: 2 generalizing, and 6 extending.

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
			• map -- raw tables (without any metadata)
				• array -- table with ordered numeric keys, starting from 1. (table, which can be iterated through 'ipairs')
		• userdata
		• thread

NOTE:
Empty map will be considered as array. Array with nils in the middle will be considered as map.

Here are some functions to establish relastions between objects and etypes:

-----------------------------------------------------

# isetype(object: any, etype: string): boolean

Check if the given object belongs to the specified etype.

-----------------------------------------------------

# etype(any): etypename

Get the last descendant etype, which the given object belongs to.

-----------------------------------------------------

# USER DEFINED ETYPES

It's possible to define new etypes, using 'defetype' function.
Each etype must be based on any other etype.
etype is determined by its function, which checks if the given object belongs to this etype.
Here is no need in this function to include checking for object to belong to parenting etypes. It will be done automatically. (When checking, ascendants conditions will be called before, in descending order)
When defining multiple etypes based on the same one, make sure their check functions does not intersect (cannot both return true for the same object), otherwise it will contradict to etype concept and will not work correctly.

NOTE:
Due to the last term, 'table' etype cannot be used as base, because any of its instance will belong to either 'map' or 'complex'.
By the similar logic, etypes 'any' and 'some' also cannot be extended.

NOTE:
Be attentive with 'etype' function usage. Its behavior is affected every time a new etype is created.

-----------------------------------------------------

# defetype(etype: string, basetype: etype, check: f(any): boolean)

Define new etype, based on the 'basetype'.
The check function must return whether the passed object belongs to this etype.

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
local genetypechecker = true

local function getetypedata(typename, s)
	local t = etypes[typename]
	if t then
		return t
	end
	error((s or '') .. 'etype ' .. stringify(typename) .. ' is not defined!', 3)
end

function defetype(typename, basetype, check)
	if type(typename) ~= 'string' then
		error('etype name ' .. stringify(typename) .. ' must be a string!', 2)
	end

	local basedata = getetypedata(basetype, 'base ')
	table.insert(basedata.children, typename)
	
	etypes[typename] = {
		check = check,
		base = basetype,
		children = {},
	}

	if genetypechecker then
		_M['is' .. typename] = function(v)
			return isetype(v, typename)
		end
	end
end

function isetype(v, typename)
	local data = getetypedata(typename)
	if data.base and not isetype(v, data.base) then
		return false
	end
	if data.check then
		return data.check(v)
	end
	return true
end

function etype(v, _etypelist)
	if not _etypelist then
		_etypelist = etypes.any.children
	end
	for _, typename in ipairs(_etypelist) do
		local data = getetypedata(typename)
		if data.check(v) then
			return etype(v, data.children) or typename
		end
	end
end

local function typetoetype(typename, base)
	defetype(typename, base, function(v)
		return type(v) == typename
	end)
end

defetype('some', 'any', function(v)
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

defetype('int', 'number', function(v)
	return math.floor(v) == v
end)

defetype('etypename', 'string', function(v)
	return etypes[v] and true or false
end)

defetype('typename', 'etypename', function(v)
	return etypes[v].base == 'any'
end)

defetype('complex', 'table', function(v)
	return getmetatable(v) ~= nil
end)

defetype('map', 'table', function(v)
	return getmetatable(v) == nil
end)

defetype('array', 'map', function(v)
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

# fd(...any): any

Returns first of the passed objects, which is not nil.

]]

function fd(...)
	local v = find(
		{...},
		function(v)
			return v ~= nil
		end,
		iorder
	)
	return v
end

--[[

# dget(source: any, keys: ...any): any

Deep get a field of the given table, using consequenceive keys.

]]

function dget(source, key, ...)
	if key == nil then
		return source
	elseif type(source) ~= 'table' then
		return nil
	else
		return dget(source[key], ...)
	end
end

--[[

# dset(target: any, keys: ...any, value: any): any

Deep set a field of the given table, using consequenceive keys.
Will override non-table filds on the path.

]]

function dset(target, key, val, ...)
	local last = (#({...}) == 0)
	if last then
		target[key] = val
	else
		local new = target[key]
		if type(new) ~= 'table' then
			new = {}
			target[key] = new
		end
		dset(new, val, ...)
	end
end

--[[

# dgos(target: any, keys: ...any, default: any): any

Deep get a field of the given table, using consequenceive keys. Set it, if doesn't exist.
Will override non-table filds on the path.

]]

function dgos(target, key, def, ...)
	local val = target[key]
	local last = (#({...}) == 0)
	if last then
		if val == nil then
			val = def
			target[key] = val
		end
		return val
	else
		if type(val) ~= 'table' then
			val = {}
			target[key] = val
		end
		return dgos(val, def, ...)
	end
end

--[[

# ocall(function: f() | nil, params: ...any): result: any

Calls the given function if it's not nil with the given params.

]]

function ocall(f, ...)
	if f then
		return f(...)
	end
end

--[[

# oscall(object: table | nil, function: string, params: ...any)

Optionally calls function of the given object by name, using object itself as first parameter.
Calls only if both object and function are not nils.

]]

function oscall(obj, fname, ...)
	if obj then
		local f = obj[fname]
		if f then
			return f(obj, ...)
		end
	end
end

--[[

# use(...any)

Define upvalues for usage. Affects some context dependent functions.
Function does nothing by itself. But listed upvalues becomes registered by the engine, since they are used.

]]

function use()
end

--[[

# getlocal(name: string, level: int = 1): any
• free order
• context dependent

Find local variable by the name at the given stack level. (including used upvalues)

]]

function getlocal(...)
	local name, level = args('string; number = 1', ...)
	level = level + 1
	return locals(level)[name]
end

--[[

# locals(level: int = 1): map
• context dependent

Get map of all local variables at the given stack level. (including used upvalues)

]]

function locals(level)
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

# envcopy(level: int = 1): complex
• context dependent

Generate environment simulation of the given stack level, including local variables and used upvalues.

]]

function envcopy(level)
	level = (level or 1) + 1
	local env = locals(level)
	local genv = getfenv(level)
	setmetatable(env, {
		__index = genv,
		__newindex = genv,
	})
	return env
end

--[[

# runstring(code: string, env?: table, level: int = 1): any

Execute the given string of code.
Environment may be provided.
Stack level for potential error may be provided.
If code is a right-side expression, its result will be returned.

]]

function runstring(code, env, stack)
	if isnumber(env) then
		stack = env
		env = nil
	end

	stack = (stack or 1) + 1

	local retcode = 'return ' .. code
	local f, err = load(retcode)
	if err then
		f, err = load(code)
		if err then
			error(err, stack)
		end
	end

	if env then
		setfenv(f, env)
	end

	local result = {pcall(f)}

	if result[1] then
		return unpackfull(result, 2)
	else
		error(result[2], stack)
	end
end

--[[

# args(format: string, input: ...any): ...any
• context dependent

Maps the input args to output due to the specified format.
Allows flexible params order. Each template matches first unused input value or uses default or matches nil.

Format is a string of semicolon-separated templates:
[tempate1; tempalte2; ...]

Each template must contain the condition and may define the default value:
condition [= default]

Condition may be a etype name.
Otherwise condition will be parsed as a function in the current context with the given name. (function should return whether the passed object matches condition)
There may be multiple conditions separated by vertical line "|". They will be true if any of them will be true.

Default may be any expression, which must be valid in the current context.
Expression may refer previous output parameters, using the form: #param_number. (First param number is 1)
To prevent '#' replacement inside the inner strings, use '%#' instead.

Last template may be a "..."
In this case all remaining unused params will be returned in their order after the parsed params.

NOTE:
Only used upvalues are included in the context.

EXAMPLE:
```
function newarray(...)
	return {...}
end

local function issix(v)
	return v == 6
end

function f(...)
	use(issix)
	local n6, i, s, n1, n2, n3, t, b = args('issix; int; string; string | number; number = #4; number = #4 + #5; map = newarray(1, 2); ...', ...)
	print(n6, i, s, n1, n2, n3, t, b)
end

f(true, 3.14, 4, 5, 6)	--> 6    4    nil    3.14    5    8.14    table: A9DFB0    true
```

]]

function args(format, ...)
	local input = {...}
	local output = {}
	local templates = split(format, ';')
	local env = envcopy(2)

	local function matches_condition(v, condition)
		condition = trim(condition)
		if isetypename(condition) then
			return isetype(v, condition)
		else
			local check = env[condition]
			if type(check) == 'function' then
				return check(v)
			else
				error('Invalid condtion with name ' .. stringify(condition) .. ': ' .. stringify(check), 3)
			end
		end
	end

	local function parse_default(default)
		default = (' ' .. default):gsub('([^%%])(#%d+)', '%1getfenv(1)["%2"]'):gsub('%%#', '#')
		return runstring(default, env, 2)
	end

	for i, template in ipairs(templates) do
		if trim(template) == '...' then
			for j, value in iorder(input) do
				output[i] = value
				i = i + 1
			end
			break
		else
			local conditions, default = unpack(split(template, '='))
			local result
			for j, value in iorder(input) do
				if find(
					split(conditions, '|'),
					function(condition)
						if matches_condition(value, condition) then
							result = value
							input[j] = nil
							return true
						end
					end
				) then
					break
				end
			end
			if result == nil and default then
				result = parse_default(default)
			end
			output[i] = result
			env['#' .. i] = result
		end
	end

	return unpackfull(output)
end

--[[

# reargs(env?: int | table = 1, format: string, ...any): ...any
• context dependent

Generates new parameter list using the given parameter list, according to the given format.
Format is a string of comma-separated expressions, which will be executed in the current context, and result will be returned. (Only used upvalues are visible)
Expression may refer any passed parameter using the format: #param_number. (First param number is 1)
To prevent '#' replacement inside the inner strings, use '%#' instead.
Expression also may be a '...', which will put all the passed parameters in appropriate position between returned values.
Optional first parameter may be a number, which represents a stack level of the execution contex.
First parameter also may be a table, then it will be used as context itself.

#NOTE
Actually, function just runs a 'format' string as code.
But also allows to use '...' in the middle of the param list, and refer params with '#n'.
Even return statement may be passed in this string.

EXAMPLE
```
local x = 1
function createvalue()
	return 'value'
end

print(reargs('createvalue(), ..., #2 + x', 3, 10))	--> value    3    10    11
```

]]

function reargs(env, format, ...)
	local input = {...}

	if isnumber(env) then
		env = envcopy(env + 1)
	elseif not istable(env) then
		table.insert(input, 1, format)
		format = env
		env = envcopy(2)
	end

	if not isstring(format) then
		error('Invalid format: ' .. stringify(format), 2)
	end

	local varargs = join(map(
		input,
		function(v, i)
			local key = '#' .. i
			env[key] = v
			return key
		end,
		istep
	))

	format = (' ' .. format):gsub('%.%.%.', varargs):gsub('([^%%])(#%d+)', '%1getfenv(1)["%2"]'):gsub('%%#', '#')

	return runstring(format, env)
end

--[[

# lt(a: any, b: any): boolean

Returns whether a is less than b.
First tries to compare objects as numbers.
If only one of the objects may be cast to number, it's less.
Otherwise compares objects as strings.

]]

function lt(a, b)
	local na = tonumber(a)
	local nb = tonumber(b)

	if na or nb then
		if na and nb then
			return na < nb
		else
			return na and true or false
		end
	end

	return tostring(a) < tostring(b)
end

--[[

# gt(a: any, b: any): boolean

Returns whether a is greater than b.
First tries to compare objects as numbers.
If only one of the objects may be cast to number, it's less.
Otherwise compares objects as strings.

]]

function gt(a, b)
	return lt(b, a)
end

--[[

# stringify(any): string

Convert object to a string, keeping information about its type.

]]

function stringify(v)
	if isstring(v) then
		return '"' .. v:gsub('"', '\\"') .. '"'
	end
	return tostring(v)
end

--[[

# match(source: string, pattern: string): {...string}

Returns array of all matches by the pattern in the source string.

]]

function match(source, pattern)
	local matches = {}
	for s in source:gmatch(pattern) do
		table.insert(matches, s)
	end
	return matches
end

--[[

# split(source: string, delimiters: string = ','): {...string}

Split the source string by delimiters into array of substrings. Each delimiter is a single char of the 'delimiters' string.

]]

function split(source, delimiters)
	delimiters = delimiters or ','
	local matches = match(source, '([^' .. delimiters .. ']*)[' .. delimiters .. ']?')
	table.remove(matches, #matches)
	return matches
end

--[[

# trim(string): string

Returns the given string with removed space characters from the both left and right.

]]

function trim(s)
	return s:match('^%s*(.-)%s*$')
end

--[[

# wrap(f(...any): ...any = nil, inform: string = '...', outform: string = '...'): f(...any): ...any
• context dependent

Returns wrapper for the given function.
When calling a wrapper, puts parameters into the source function according to the inform.
Returns results of the source function according to the 'outform'.
'inform' and 'outform' work same as 'format' for the 'reargs' function.
'outform' also may refer input wrapper's params with form: ##param_number
If function is not specified, wrapper will just return parsed parameters.

EXAMPLE
```
function summ(a, b)
  return a + b
end
local x = 10

add_x_then_double_then_addsrc = wrap(summ, '#1, x', '#1 * 2 + ##1, ...')

print(add_x_then_double_then_addsrc(7))		--> 41    17
-- 41 = (7 + x) * 2 + 7
```

]]

function wrap(f, inform, outform)
	if inform or outform then
		local env = envcopy(2)
		inform = inform or '...'
		outform = outform or '...'
		outform = (' ' .. outform):gsub('##(%d+)', 'getfenv(1)["%%#%%#%1"]')
		f = f or wrap()

		return function(...)
			for i, v in pairs({...}) do
				env['##'..i] = v
			end
			return reargs(env, outform, f(reargs(env, inform, ...)))
		end
	else
		if f then
			return function(...)
				return f(...)
			end
		else
			return function(...)
				return ...
			end
		end
	end
end

--[[

# find(object, condition: f(value: any, key: any, source: object, order: int): boolean, iterator = pairs): any, any

Finds first vaule in the given table which matches the condition.
Returns value and its key.
Returns nil, if nothing matches the condition.
Iterator may be provided to determine values and which of them is first.

]]

function find(source, condition, iterator)
	iterator = iterator or pairs
	local i = 1
	for k, v in iterator(source) do
		if condition(v, k, source, i) then
			return v, k
		end
		i = i + 1
	end
end

--[[

# findkey(object, condition: f(value: any, key: any, source: object, order: int): boolean, iterator = pairs): any

Same as find, but returns only the key.

]]

function findkey(source, condition, iterator)
	local v, k = find(source, condition, iterator)
	return k
end

--[[

# getkey(object, value: any, iterator = pairs): any

Find first getkey of the given value in the table.
Returns nil, if value is missing in the table.
Iterator may be provided to determine values and which of them is first.

]]

function getkey(source, value, iterator)
	return findkey(source, function(v)
		return v == value
	end, iterator)
end

--[[

# isempty(object, iterator = pairs): boolean

Determine if the given table is empty.
Iterator may be provided to determine fields for counting.

]]

function isempty(t, iterator)
	iterator = iterator or pairs
	local f, r, i = iterator(t)
	return (f(r, i) == nil)
end

--[[

# fcount(source: object, condition: f(value: any, key: any, source: object, order: int) = f(): true , iterator = epairs): int

Get number of fields in the table, which match the condition.
Iterator may be provided to determine fields for counting.

]]

function fcount(t, condition, iterator)
	local n = 0
	foreach(
		t,
		function(...)
			if not condition or condition(...) then
				n = n + 1
			end
		end,
		iterator
	)
	return n
end

--[[

# getlast(object, iterator = ipairs): any, any

Get last value and key in the given object.
Iterator may be provided to determine fields for iteration and which of them is last.

]]

function getlast(t, iterator)
	iterator = iterator or ipairs
	local last, lastkey
	for k, v in iterator(t) do
		last, lastkey = v, k
	end
	return last, lastkey
end

--[[

# unpackfull(values: {...any} | object, from: iterator | number = 1): ...any

Fully unpacks array-like table, regardless of nils in the middle.
Max numeric index is considered as the last element.
If second parameter is number, iteration will start from this index.
May use second parameter as iterator to determine values for unpacking and their order.

]]

local __unpackfull_max
local __unpackfull_i
function unpackfull(values, iterator)
	if iterator then
		if type(iterator) == 'number' then
			iterator = istep(true, iterator)
		end
		return unpackfull(vals(values, iterator))
	end

	local max = __unpackfull_max or extr(keys(values)) or 0
	local i = __unpackfull_i or 1
	if max < i then
		__unpackfull_max = nil
		__unpackfull_i = nil
		return
	else
		__unpackfull_max = max
		__unpackfull_i = i + 1
		return values[i], unpackfull(values)
	end
end

--[[

# foreach(object, callback: f(value: any, key: any, source: object, order: int), iterator = epairs)

Perform the callback for each field of the given table.
Iterator may be provided (for iteration, lol).

]]

function foreach(t, callback, iterator)
	iterator = iterator or epairs
	local i = 1
	for k, v in iterator(t) do
		callback(v, k, t, i)
		i = i + 1
	end
end

--[[

# map(source: object, modify: f(value: any, key: any, source: object, order: int, new: object): any, any = wrap(), iterator = epairs, others: boolean = false): map

Form new table by mapping values of the source table with the 'modify' function.
'modify' may return a second result, then the key will be mapped to this value.
If 'modify' function is not specified, shallow copy of the table will be returned.
Iterator may be provided to limit fields and determine order for the mapping.
The 'others' param determines if fields outside the iterator should be included.

]]

function map(source, modify, iterator, others)
	modify = modify or wrap()
	local newer = {}
	local iterated = {}
	foreach(
		source,
		function(v, k, t, i)
			local newv, newk = modify(v, k, t, i, newer)
			if newk == nil then
				newk = k
			end
			newer[newk] = newv
			iterated[k] = true
		end,
		iterator
	)
	if others then
		foreach(source, function(v, k)
			if not iterated[k] then
				newer[k] = v
			end
		end)
	end
	return newer
end

--[[

# filter(source: object, condition: f(value: any, key: any, source: object, order: int): boolean, iterator = pairs, others: boolean = false): map

Form new table by including only values wich matches the condition.
Iterator may be provided to limit fields and determine order for the filtering.
The 'others' param determines if fields outside the iterator should be included.

]]

function filter(source, condition, iterator, others)
	return map(
		source,
		function(v, ...)
			if condition(v, ...) then
				return v
			end
		end,
		iterator,
		others
	)
end

--[[

# 

]]

function reduce()
	
end

--[[

# inverse(source: object, iterator = epairs): map

Generate new table, using values of the source table as keys and keys as values.
Iterator may be provided to limit fields and determine order for inversion.
If table has multiple similar values, only first one is used.

]]

function inverse(t, iterator)
	local newer = {}
	foreach(
		t,
		function(v, k)
			if newer[v] == nil then
				newer[v] = k
			end
		end,
		iterator
	)
	return newer
end

--[[

# join(values: {...any} | object, delimiter?: string = ',', iterator = ipairs): string

Join the given array of objects, using the delimiter.
Iterator may be provided, to determine the order and the values to iterate.

NOTE:
Default table.concat doesn't cast types, and may throw a error.

]]

function join(values, delimiter, iterator)
	if type(delimiter) ~= 'string' then
		iterator = delimiter
		delimiter = ','
	end
	iterator = iterator or ipairs
	local s = ''
	local first = true
	foreach(
		values,
		function(v)
			if first then
				first = false
			else
				s = s .. delimiter
			end
			s = s .. tostring(v)
		end,
		iterator
	)
	return s
end

--[[

# extr(source: object, compare: boolean | f(a: any, b: any): boolean = true, condition: f(value: any, key: any, source: object, order: int): boolean = f(): true, iterator = epairs): any

Find first extremum value in the given table.
By default returns maximal numberic value.
If second parameter is boolean, it will define if maximum value is queried (otherwise - minimum), while values will be limited to numberic.
If second parameter is a function, it must return whether 2 passed parameters are in ascending order. Due to this order, the maximum will be returned.
Third parameter is a filter-function, which limits allowed values.
Iterator may be provided to determine which extremum value is first.

]]

function extr(t, compare, condition, iterator)
	if type(compare) ~= 'function' then
		if condition then
			local extra_condition = condition
			condition = function(v)
				return isnumber(v) and extra_condition(v)
			end
		else
			condition = isnumber
		end

		if compare == false then
			compare = gt
		elseif compare == true or compare == nil then
			compare = lt
		else
			error('invalid compare parameter: ' .. stringify(compare), 2)
		end
	end

	local ex
	foreach(t, function(v, k)
		if not condition or condition(v) then
			if not ex or compare(ex, v) then
				ex = v
			end
		end
	end, iterator)
	return ex
end

--[[

# keys(object, iterator = epairs): {...some}

Returns array of keys of the given table.
Iterator may be provided to limit fields and determine order of the output array.

]]

function keys(t, iterator)
	local a = {}
	foreach(
		t,
		function(_, k, _, i)
			a[i] = k
		end,
		iterator
	)
	return a
end

--[[

# vals(object, iterator = epairs): {...some}

Returns array of values of the given table.
Iterator may be provided to limit fields and determine order of the output array.

]]

function vals(t, iterator)
	local a = {}
	foreach(
		t,
		function(v, _, _, i)
			a[i] = v
		end,
		iterator
	)
	return a
end

--[[

# entries(object, iterator = epairs): {...{key: some, value: any}}

Returns array of key-value pairs of the given table.
Iterator may be provided to limit fields and determine order of the output array.

]]

function entries(t, iterator)
	local a = {}
	foreach(
		t,
		function(v, k, _, i)
			a[i] = {k, v}
		end,
		iterator
	)
	return a
end

--[[

# random(source: table, weighted?: boolean = false, iterator = epairs): any, any

Get random element from the given table. Returns value and key.
If 'weighted' is true, values will be considered as weights, and only key will be returned. Ignores not-numeric values.
Iterator may be provided to limit fields.
]]

function random(t, weighted, iterator)
	if type(weighted) ~= 'boolean' then
		iterator = weighted
		weighted = false
	end

	local arr = entries(t, iterator)
	if weighted then
		local max = 0
		local weights = {}
		for i, e in ipairs(arr) do
			weights[i] = max
			max = max + tonumber(e[2])
		end
		local weight = RandomFloat(0, max)
		for i, w in ipairs(weights) do
			if weight >= w then
				return arr[i][1]
			end
		end
	else
		local e = arr[RandomInt(1, #arr)]
		return e[2], e[1]
	end
end

--[[

# merge(target: table, sources: ...table): table

Merges all the given source tables in order to the target table.
Target table will be modified and returned.

NOTE:
Doesn't throw a error nor endless loops with cyclic structures. But resulted table's structure may be complex to predict, so try to avoid it.

WARNING:
If you need to generate a new table by merging other 2+, use first parameter as {}, then put tables to merge. Otherwise first table will be modified in place.

]]

local __merge_ignore
function merge(left, right, ...)
	local result
	local topcall = (__merge_ignore == nil)
	if topcall then
		__merge_ignore = {}
	end

	if right == nil then
		result = left
	elseif not istable(right) then
		result = merge(right, ...)
	elseif not istable(left) then
		result = merge({}, right, ...)
	else
		__merge_ignore[left] = left
		__merge_ignore[right] = left
		for k, v in pairs(right) do
			local leftv = left[k]
			left[k] = __merge_ignore[leftv] or __merge_ignore[v] or merge(leftv, v)
		end
		__merge_ignore[left] = nil
		__merge_ignore[right] = nil
		result = merge(left, ...)
	end

	if topcall then
		__merge_ignore = nil
	end

	return result
end

--[[

# epairs(table): iterator()

Appropriate pairs or ipairs iterator for the passed table.

]]

function epairs(t)
	if isarray(t) then
		return ipairs(t)
	else
		return pairs(t)
	end
end

--[[

# iorder(source: table | true, compare: boolean | f(a: any, b: any): boolean = true, condition: f(value: any, key: any, source: table, order: int): boolean = f(): true): iterator | iterator()

Iterator over the source table, which iterates specified keys in specified order.
Provides values inside the iteration (as second parameter).
By default, when only first parameter is given, iterates all numeric keys in ascending order.
If first parameter is true, iterator with specified parameters will be returned, not performed.
If second parameter is boolean, keys will be limited to numeric, while the parameter value will define if the order should be ascending.
If second parameter is function, it behaves as the comparator for the sorting (should return whether two passed keys are in the valid order).
Third parameter may be a filter-function, which selects keys for iteration.

]]

function iorder(v, compare, condition)
	local iterator = function(t)
		if type(compare) == 'boolean' or compare == nil then
			if condition then
				local extra_condition = condition
				condition = function(v, k, t, i)
					return isnumber(k) and extra_condition(v, k, t, i)
				end
			else
				condition = function(v, k)
					return isnumber(k)
				end
			end
		end

		if compare == false then
			compare = gt
		end

		if condition then
			t = filter(t, condition)
		end

		local indexes = keys(t)
		table.sort(indexes, compare)
		local i = 1

		return function()
			local index = indexes[i]
			if index then
				i = i + 1
				return index, t[index]
			end
		end
	end

	if v == true then
		return iterator
	end

	return iterator(v)
end

--[[

# istep(source: table | true, first: number = 1, last: number = extr(keys(source)), step: number = 1): iterator | iterator()

Iterator over the source table, which iterates numeric keys from the first number to the last number, with the passed step interval. (Works same af 'for i = first, last, step do' statement)
Provides values inside the iteration (as second parameter).
If first parameter is true, iterator with specified parameters will be returned, not performed.
Default 'last' key is the maximum numeric key in the source table.

]]

function istep(v, first, last, step)
	local iterator = function(t)
		local index = first or 1
		local last = last or extr(keys(t)) or 0
		local step = step or 1
		
		return function()
			if index <= last then
				local k, v = index, t[index]
				index = index + step
				return k, v
			end
		end
	end

	if v == true then
		return iterator
	end

	return iterator(v)
end

--[[

lprint(string)

Print string by lines. Basicly fixes default print's clamp of long multiline strings.

]]

function lprint(s)
	foreach(
		split(s, '\n'),
		wrap(print, '#1')
	)
end

--[[

# dprint(object: any, options?: map): string?

Deep print the given object.
May print cyclic structures as well.

options: {
	print: f(string) | false = lprint,			-- function to display resulting string. Is set to false, resulting string will be returned.
	expand: f(object: any, key: any, options) = istable,	-- function to determine whether passed object should be deep printed.
	iterator: iterator = iorder(true, lt),		-- Iterator to define fields to print and their order.
	keys: boolean = true,						-- Should keys be deep printed?
	meta: boolean = false,						-- Should metatable's __index be printed?
	format: format | string = 'simple',			-- Map about object structure decoration. If is string, appropriate map from dprint.format will be used.
	tostring?: f(object: any, options): string,	-- Override format.tostring function.
}

format: {
	tostring?: f(object: any, key: any, options): string,	-- String-cast function for printing objects. By default uses stringify function to print basic objects, and doesn't print expanded ones.
	separator: string = ','			-- Separator between KV pairs.
	keyleft: string = '['			-- Prefix for keys.
	keyright: string = '] = '		-- Postfix for keys.
	mapleft = '{',					-- Prefix for expanded object's content.
	mapright = '}',					-- Postfix for expanded object's content.
	mapskip = '{ ... }',			-- Shortcut for repeated expanded object's content.
	space = '  ',					-- Generic indent.
	child = space,					-- Indent for the start of the child.
	lastspace = space,				-- Generic indent for last child's lines.
	lastchild = child,				-- Indent for the start of the last child.
}

Predefined dprint formats:
- dprint.format.simple
- dprint.format.tree

]]

dprint = {
	format = {
		simple = {
			tostring = function(v, k, options)
				return options.expand(v, k, options) and '' or stringify(v)
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
			tostring = stringify,
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
		format = dprint.format[format]
	end
	format = merge({}, format)
	format.lastspace = format.lastspace or format.space
	format.child = format.child or format.space
	format.lastchild = format.lastchild or format.child
	return merge({}, dprint.format.simple, format)
end

local function __dprint(object, options, meta)
	options = options or {}
	local t = {
		print = fd(options.print, lprint),
		expand = options.expand or istable,
		keys = fd(options.keys, true),
		meta = fd(options.meta, false),
		iterator = options.iterator or iorder(true, lt),
		format = __dprint_parseformat(options.format),
	}
	t.tostring = options.tostring or t.format.tostring

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

			local children = entries(object, t.iterator)
			local indexkey = {}
			if t.meta then
				local __index = dget(getmetatable(object), '__index')
				if __index then
					table.insert(children, {indexkey, __index})
				end
			end
			
			local len = #children
			local haschild = len > 0

			local function printkv(k, v, last)
				local ownpostfix = last and t.format.lastchild or t.format.child		
				output = output .. '\n' .. prefix .. ownpostfix .. t.format.keyleft .. k .. t.format.keyright .. v
				if not last then
					output = output .. t.format.separator
				end
			end

			local options = merge({}, options, {
				print = false,
			})			
			
			if haschild then
				foreach(
					children,
					function(e, _, _, i)
						local last = (len == i)
						local childpostfix = last and t.format.lastspace or t.format.space
						
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
							last
						)
					end
				)
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

setmetatable(dprint, {
	__call = function(_, object, options)
		__dprint(object, options)
	end,
})

-----------------------------------------------------

return _M