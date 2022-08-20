
--[[

• Cannot be required directly with lua's 'require'

]]

local basis = __basis_loaded
local setup_callbacks = {}
local queues = {}
local required = {}
local required_modules = {}
local panorama_modules = {}

if IsServer() then
	ListenToGameEvent(
		'game_rules_state_change',
		function()
			if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
				CustomGameEventManager:RegisterListener('sv_basis_panorama_module', function(_, t)
					local mod = panorama_modules[t.module]
					if not mod then
						print('panorama trying to load unknown module: ' .. tostring(t.module))
						basis.panorama_event(t.PlayerID, 'cl_basis_panorama_module', {
							module = t.module,
						})
						return
					end

					local function send(pid)
						basis.panorama_event(pid, 'cl_basis_panorama_module', {
							module = t.module,
							code = mod.code,
						})
					end

					if mod.code then
						send(t.PlayerID)
					else
						table.insert(mod.clients, t.PlayerID)
						if not mod.loading then
							mod.loading = true
							read_url(http, 'async', function(code)
								local clients = mod.clients
								mod.code = code
								mod.clients = {}
								for _, pid in ipairs(clients) do
									send(pid)
								end
							end)
						end
					end
				end)

				for _, f in ipairs(setup_callbacks) do
					f()
				end
			end
		end,
		nil
	)	
end

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



]]

function http_queue(queue, callback)
	if type(queue) == 'function' then
		callback = queue
		queue = nil
	end

	queue = (queue or 'default'):lower()

	local q
	local this_step
	if queue ~= 'async' then
		q = queues[queue]
		if not q then
			q = {
				left = 1,
				right = 0,
				done = {},
			}
			queues[queue] = q
		end
		this_step = {
			callback = callback,
			ready = false,
		}
		q.right = q.right + 1
		q[q.right] = this_step
	end

	local invoke = function(t)
		if q then
			local err
			this_step.ready = true
			this_step.args = t
			while true do
				local step = q[q.left]
				if step then
					if step.ready then
						local status, steperr = pcall(step.callback, step.args)
						if not status then
							err = steperr
						end
						q[q.left] = nil
						q.left = q.left + 1
					else
						break
					end
				else
					local done = {unpack(q.done)}
					q.done = {}
					q.left = 1
					q.right = 0
					for _, callback in ipairs(done) do
						callback()
					end
					break
				end
			end
			if err then
				error(err)
			end
		else
			callback(t)
		end
	end

	return invoke
end

--[[



]]

function on_http_queue_done(queue, callback)
	if type(queue) == 'function' then
		callback = queue
		queue = nil
	end

	queue = (queue or 'default'):lower()

	local q = queues[queue]
	if not q or q.left > q.right then
		callback()
	else
		table.insert(q.done, callback)
	end
end

--[[

read_url(httpdata, callback: f(body: string, response: map, parsed: httpdata), fail: nil | f(body: string, response: map, parsed: httpdata), tries: int = 3)

]]

local __read_url__invoke
function read_url(http, queue, ok, fail, tries)
	if type(queue) == 'function' then
		tries = fail
		fail = ok
		ok = queue
		queue = nil
	end

	tries = tries or 3
	local req, invoke

	if __read_url__invoke then
		invoke = __read_url__invoke
		__read_url__invoke = nil
	else
		invoke = http_queue(
			queue,
			function(t)
				if t.StatusCode == 200 then
					ok(t.Body, t, http)
				else
					if fail then
						fail(t.Body, t, http)
					else
						error('Failed to read url ' .. http.url)
					end
				end
			end
		)
	end

	local function run()
		req, http = create_request(http)

		req:Send(function(t)
			if t.StatusCode ~= 200 and tries > 1 then
				__read_url__invoke = invoke
				read_url(http, queue, ok, fail, tries - 1)
			else
				invoke(t)
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

function require_url(http, optional, module, queue, callback)
	if optional ~= nil and type(optional) ~= 'boolean' then
		return require_url(http, nil, optional, module, queue)
	end
	if module ~= nil and type(module) ~= 'string' then
		return require_url(http, optional, nil, module, queue)
	end
	if queue ~= nil and type(queue) ~= 'string' then
		return require_url(http, optional, module, nil, queue)
	end

	queue = queue or 'require'
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
		queue = 'require',
		state = 'loading',
		http = http,
	}
	table.insert(required, info)

	local function ferr(err)
		info.state = errstate
		info.error = err
		if callback then
			callback(nil, err)
		else
			(optional and print or error)(err)
		end
	end
	
	read_url(
		http,
		queue,
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
			end
		end,
		function()
			ferr('Cannot find ' .. http.url)
		end
	)

	return promise
end

--[[

require_error_https()

]]

function http_require_errors(queue, delimiter, fails)
	if queue ~= nil and type(queue) ~= 'string' then
		return http_require_errors(nil, queue, delimiter)
	end
	if delimiter ~= nil and type(delimiter) ~= 'string' then
		return http_require_errors(queue, nil, delimiter)
	end

	queue = queue or 'require'

	local t = {}
	for _, info in ipairs(required) do
		if info.queue == queue and (info.state == 'error' or (fails and info.state == 'fail')) then
			table.insert(t, info)
		end
	end
	
	local len = #t
	if len > 0 then
		if delimiter then
			local s = t[1].http.url
			for i = 2, len do
				s = s .. delimiter .. t[i].http.url
			end
			return s
		else
			return t
		end
	end
end

--[[

panorama_module

]]

function panorama_module(module, http)
	panorama_modules[module] = {
		http = http,
		loading = false,
		clients = {},
		code = nil,
	}
end