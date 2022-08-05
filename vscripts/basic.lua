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
			• map -- raw tables without any metadata
				• array -- table with ordered numeric keys, starting from 1. (table, which can be iterated through 'ipairs')
		• userdata
		• thread

NOTE: Empty table will be considered as array.

Here are some functions to establish relastions between objects and etypes:

-----------------------------------------------------

isetype(object: any, etype: string): boolean

Check if the given object belongs to the specified etype.

-----------------------------------------------------

etype(any): etypename

Get the last descendant etype, which the given object belongs to.

-----------------------------------------------------

# USER DEFINED ETYPES

It's possible to define new etypes, using 'defetype' function.
Each etype must be based on any other etype.
etype is determined by its function, which checks if the given object belongs to this etype.
Here is no need in this function to include checking for object to belong to parenting etypes. It will be done automatically.
When defining multiple etypes based on the same one, make sure their check functions does not intersect (cannot both return true for the same object), otherwise it will contradict to etype concept and will not work correctly.

NOTE: Due to the last term, 'table' etype cannot be used as base, because any of its instance will belong to either 'map' or 'complex'.
Also cannot be extended etypes 'any' and 'some'.

-----------------------------------------------------

defetype(etype: string, basetype: etype, check: f(any): boolean)

Define new etype, based on the 'basetype'.
The check function must return whether the passed object belongs to this etype.

-----------------------------------------------------

# ISETYPE SHORTCUTS

An is-like function is assigned to each built-in etype.
This function checks if the object belongs to the appropriate etype, and is just a shortcut for 'isetype' with specific etype parameter.

List of the defined is-like functions goes bellow:

-----------------------------------------------------

isnil(any): boolean

Check if the given object is nil.

-----------------------------------------------------

issome(any): boolean

Check if the given object is not nil.

-----------------------------------------------------

isboolean(any): boolean

Check if the given object is boolean.

-----------------------------------------------------

isnumber(any): boolean

Check if the given object is a number.

-----------------------------------------------------

isint(any): boolean

Check if the given object is an integer.

-----------------------------------------------------

isstring(any): boolean

Check if the given object is a string.

-----------------------------------------------------

isetypename(any): boolean

Check if the given object is one of the defined etype names.

-----------------------------------------------------

istypename(any): boolean

Check if the given object is one of the 8 basic lua type names.

-----------------------------------------------------

isfunction(any): boolean

Check if the given object is a function.

-----------------------------------------------------

istable(any): boolean

Check if the given object is a table.

-----------------------------------------------------

iscomplex(any): boolean

Check if the given object is a complex table.

-----------------------------------------------------

ismap(any): boolean

Check if the given object is a raw table.

-----------------------------------------------------

isarray(any): boolean

Check if the given object is pure array.

-----------------------------------------------------

isuserdata(any): boolean

Check if the given object is a userdata.

-----------------------------------------------------

isthread(any): boolean

Check if the given object is a coroutine.

]]

local etypes = {any = {children = {}}}
local genetypechecker = true

local function getetypedata(typename, s)
	local t = etypes[typename]
	if t then
		return t
	end
	error((s or '') .. 'type ' .. stringify(typename) .. ' is not defined!', 3)
end

function defetype(typename, basetype, check)
	if type(typename) ~= 'string' then
		error('type name ' .. stringify(typename) .. ' must be a string!', 2)
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
	return #v == length(v)
end)

genetypechecker = false

--[[

getlocal(name: string, level: int = 1): any

Find local variable by the name in the given stack level.

- free order

]]

function getlocal(...)
	local name, level = args('string, number = 1', ...)
	level = level + 1
	local i = 1
	while true do
		local iname, value = debug.getlocal(level, i)
		if iname == name or iname == nil then
			return value
		end
		i = i + 1
	end
end

--[[

args(format: string, input: ...any): ...any

]]

function args(format, ...)
	local input = {...}
	local output = {}
	local templates = split(format, ',')

	local function matches_condition(v, condition)
		condition = trim(condition)

	end

	local function parse_default(default)

	end

	for i, template in ipairs(templates) do
		local condition, default = unpack(split(template, '='))
		local result
		for j, value in iorder(input) do
			if matches_condition(value, condition) then
				result = value
				input[j] = nil
				break
			end
		end
		if result == nil and default then
			result = parse_default(default)
		end
		output[i] = result
	end

	return unpack(output)
end

--[[

stringify(any): string

Convert object to a string, keeping information about its type.

]]

function stringify(v)
	if isstring(v) then
		return '"' .. v .. '"'
	end
	return tostring(v)
end

--[[

match(source: string, pattern: string): {...string}

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

split(source: string, delimiters: string): {...string}

Split the source string by delimiters into array of substrings. Each delimiter is a single char of the 'delimiters' string.

]]

function split(source, delimiters)
	local matches = match(source, '([^' .. delimiters .. ']*)[' .. delimiters .. ']?')
	table.remove(matches, #matches)
	return matches
end

--[[

trim(string): string

Returns the given string with removed space characters from the both left and right.

]]

function trim(s)
	return s:match('^%s*(.-)%s*$')
end

--[[

key(table, value: any, iterator = pairs): any

Find key of the given value in the table.
Returns nil, if value is missing in the table.

]]

function key(t, v)
	for k, iv in pairs(t) do
		if iv == v then
			return k
		end
	end
end

--[[

isempty(table, iterator = pairs): boolean

Determine if the given table is empty.
Iterator may be provided to determine fields for counting.

]]

function isempty(t, iterator)
	iterator = iterator or pairs
	local f, r, i = iterator(t)
	return (f(r, i) == nil)
end

--[[

length(table, iterator = pairs): int

Get number of fields in the table.
Iterator may be provided to determine fields for counting.

]]

function length(t, iterator)
	iterator = iterator or pairs
	local n = 0
	for _ in iterator(t) do
		n = n + 1
	end
	return n
end

--[[

foreach(table, callback: f(value: any, key: any, source: table, order: int), iterator = pairs)

Perform the callback for each field of the given table.
Iterator may be provided (for iteration, lol).

]]

function foreach(t, callback, iterator)
	iterator = iterator or pairs
	local i = 1
	for k in iterator(t) do
		callback(t[k], k, t, i)
		i = i + 1
	end
end

--[[

map(source: table, modify: f(value: any, key: any, source: table, order: int): any, iterator = pairs, others: boolean = false): table

Form new table by mapping values of the source table with the 'modify' function.
Iterator may be provided to limit fields and determine order for the mapping.
The 'others' param determines if fields outside the iterator should be included.

]]

function map(source, modify, iterator, others)
	local newer = {}
	local iterated = {}
	foreach(
		source,
		function(v, k, ...)
			newer[k] = modify(v, k, ...)
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

filter(source: table, condition: f(value: any, key: any, source: table, order: int): boolean, iterator = pairs, others: boolean = false): table

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

inverse(source: table, iterator): table

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

keys(table, iterator = pairs): {...any}

Returns array of keys of the given table.
Iterator may be provided to limit fields and determine order of the output array.

]]

function keys(t, iterator)
	local keys = {}
	foreach(
		t,
		function(_, k)
			table.insert(keys, k)
		end,
		iterator
	)
	return keys
end

--[[

iorder(source: table, is_ordered: boolean | f(x1: any, x2: any): boolean = true, is_valid: f(key: any, value: any, keys: array, order: int): boolean = isnumber): iterator()

Iterator over the source table, which iterates specified keys in specified order. Also provides values inside the iteration (as second parameter).
By default, when only first parameter is given, iterates all numeric keys in ascending order.
If second parameter is boolean, keys will be limited to numeric, while the parameter value will define if the order should be ascending.
If second parameter is function, it behaves as the comparator for the sorting (should return whether two passed keys are in the valid order).
Third parameter may be a filter-function, which selects keys for iteration.

]]

function iorder(t, is_ordered, is_valid)
	if type(is_ordered) == 'boolean' or is_ordered == nil then
		if is_valid then
			local extra_is_valid = is_valid
			is_valid = function(k, ...)
				return isnumber(k) and extra_is_valid(k, ...)
			end
		else
			is_valid = isnumber
		end
	end

	if is_ordered == false then
		is_ordered = function(a, b)
			return a > b
		end
	end

	local indexes = keys(t)
	if is_valid then
		indexes = filter(indexes, is_valid)
	end

	table.sort(indexes, is_ordered)
	local index_orders = inverse(indexes)

	return function(index)
		if index == nil then
			index = indexes[1]
		else
			local i = index_orders[index]
			index = indexes[i+1]
		end
		return index, t[index]
	end, t, nil
end