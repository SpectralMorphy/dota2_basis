--[[

• May be required directly with lua's 'require', but only once!

]]

function create_request(http)
	if type(http) == 'string' then
		http = {url = http}
	else
		http = {url = http.url}
	end

	http.met = http.met or 'GET'
	http.headers = http.headers or {}
	http.params = http.params or {}

	local req = CreateHTTPRequestScriptVM(http.met, http.url)

	for k, v in pairs(http.headers) do
		req:SetHTTPRequestHeaderValue(k, v)
	end

	for k, v in pairs(http.headers) do
		req:SetHTTPRequestGetOrPostParameter(k, v)
	end

	return req, http
end

--[[

read_url(httpdata, callback: f(body: string, response: map, parsed: httpdata), fail?: f(body: string, response: map, parsed: httpdata))

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

function read_url(http, ok, fail)
	local function run()
		local req, http = create_request(http)
		req:Send(function(t)
			if t.StatusCode == 200 then
				ok(t.Body, t, http)
			elseif fail then
				fail(t.Body, t, http)
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

require_url(httpdata, optional: boolean = false, callback?: f(module: f(), err: string))

]]

local required = {}
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
	for _, f in ipairs(on_required_callbacks) do
		f(ok)
	end
end

function require_url(http, optional, callback)
	local function ferr(err)
		if callback then
			callback(nil, err)
		else
			(optional and print or error)(err)
		end
	end

	local errstate = optional and 'fail' or 'error'
	local info = {
		state = 'loading',
	}
	
	read_url(
		http,
		function(code, _, http)
			info.http = http
			local f, err = load(code)
			if err then
				info.state = errstate
				print('Failed to require ' .. http.url)
				ferr(err)
			else
				info.state = 'done'
				if callback then
					callback(f, nil)
				else
					f()
				end
			end
		end,
		function(_, _, http)
			info.http = http
			info.state = errstate
			ferr('Cannot find ' .. http.url)
		end
	)
end

--[[

on_all_url_required(callback: f(errors: boolean))

]]

function on_all_url_required(f)
	table.insert(on_required_callbacks, f)
	check_url_required()
end