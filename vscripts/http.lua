
--[[

• May be required directly with lua's 'require', but only once!

]]

--[[

parse_http(httpdata)

]]

function parse_http(http)
	local parsed

	if type(http) == 'string' then
		parsed = {url = http}
	else
		parsed = {url = http.url}
	end

	if not parsed.url:match('^http') then
		parsed.url = 'http://' .. parsed.url
	end

	parsed.met = http.met or 'GET'
	parsed.headers = http.headers or {}
	parsed.params = http.params or {}

	return parsed
end

--[[

create_request(httpdata)

]]

function create_request(http)
	http = parse_http(http)
	local req = CreateHTTPRequestScriptVM(http.met, http.url)

	for k, v in pairs(http.headers) do
		req:SetHTTPRequestHeaderValue(k, v)
	end

	for k, v in pairs(http.params) do
		req:SetHTTPRequestGetOrPostParameter(k, v)
	end

	return req, http
end

--[[

read_url(httpdata, callback: f(body: string, response: map, parsed: httpdata), fail: nil | f(body: string, response: map, parsed: httpdata), tries: int = 3)

]]

local setup_callbacks = {}

if IsServer() then
	ListenToGameEvent(
		'game_rules_state_change',
		function()
			if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
				for _, f in ipairs(setup_callbacks) do
					f()
				end
			end
		end,
		nil
	)	
end

function read_url(http, ok, fail, tries)
	tries = tries or 3

	local function run()
		local req, http = create_request(http)
		req:Send(function(t)
			if t.StatusCode == 200 then
				ok(t.Body, t, http)
			elseif fail then
				if tries > 1 then
					read_url(http, ok, fail, tries - 1)
				else
					fail(t.Body, t, http)
				end
			end
		end)
	end

	if IsServer() and (not GameRules or GameRules:State_Get() < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP) then
		table.insert(setup_callbacks, run)
	else
		run()
	end
end

--[[

require_url(httpdata, optional?: boolean = false, module?: string, callback?: f(module: f(), err: string))

]]

local required = {}
local required_modules = {}
local on_required_callbacks = {}

local function check_url_required()
	local ok = true
	for _, info in ipairs(required) do
		if info.state == 'loading' then
			return
		elseif info.state == 'error' then
			ok = false
		end
	end
	local callbacks = {unpack(on_required_callbacks)}
	on_required_callbacks = {}
	for _, f in ipairs(callbacks) do
		f(ok)
	end
end

function require_url(http, optional, module, callback)
	if type(optional) ~= 'boolean' then
		callback = module
		module = optional
		optional = false
	end
	if type(module) ~= 'string' then
		callback = module
		module = nil
	end

	local promise

	if module then
		if required_modules[module] then
			return required_modules[module]
		else
			promise = {}
			required_modules[module] = promise
		end
	end

	http = parse_http(http)
	local errstate = optional and 'fail' or 'error'
	local info = {
		state = 'loading',
		http = http,
	}
	table.insert(required, info)

	local function ferr(err)
		info.state = errstate
		if callback then
			check_url_required()
			callback(nil, err)
		else
			check_url_required();
			(optional and print or error)(err)
		end
	end
	
	read_url(
		http,
		function(code)
			local f, err = load(code)
			if err then
				print('Failed to require ' .. http.url)
				ferr(err)
			else
				if callback then
					callback(f, nil, promise)
				else
					local status, result = pcall(f)
					if status then
						if type(result) == 'table' then
							for k, v in pairs(result) do
								promise[k] = v
							end
						end
					else
						print('Failed to execute ' .. http.url)
						ferr(result)
						return
					end
				end
				info.state = 'done'
				check_url_required()
			end
		end,
		function()
			ferr('Cannot find ' .. http.url)
		end
	)

	return promise
end

--[[

on_all_url_required(callback: f(success: boolean))

]]

function on_all_url_required(f)
	table.insert(on_required_callbacks, f)
	check_url_required()
end

--[[

require_error_https()

]]

function require_error_https()
	local t = {}
	for _, info in ipairs(required) do
		if info.state == 'error' then
			table.insert(t, info.http)
		end
	end
	return t
end