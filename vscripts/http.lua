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

function read_url(http, ok, fail)
	local req, http = create_request(http)
	req:Send(function(t)
		if t.StatusCode == 200 then
			ok(t.Body, t, http)
		else
			fail(t.Body, t, http)
		end
	end)
end

function require_url(http, optional, callback)
	local function ferr(err)
		if callback then
			callback(nil, err)
		else
			(optional and print or error)(err)
		end
	end
	
	read_url(
		http,
		function(code, _, http)
			local f, err = load(code)
			if err then
				print('Failed to require ' .. http.url)
				ferr(err)
			else
				if callback then
					callback(f, nil)
				else
					f()
				end
			end
		end,
		function(_, _, http)
			ferr('Cannot find ' .. http.url)
		end
	)
end