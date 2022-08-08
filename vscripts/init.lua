if __basis_loaded then
	return __basis_loaded
end

local http
local settings = LoadKeyValues('basis.kv')

local basis = {
	loaded = {},
	setuping = false,
	setuped = false,
	vscripts_root = settings.vscripts_root or '',
	vscripts_url = 'https://raw.githubusercontent.com/SpectralMorphy/dota2_basis/main/vscripts/',
}

local require_queue = {}
local require_queue_i = 1
local require_queue_e = 1
local function queue_push()
	local data = {}
	local invoke = function(callback)
		data.callback = callback
		if require_queue[require_queue_i] == data then
			local idata = data
			while idata and idata.callback do
				idata.callback()
				require_queue[require_queue_i] = nil
				require_queue_i = require_queue_i + 1
				idata = require_queue[require_queue_i]
			end
		end
	end
	data.invoke = invoke
	require_queue[require_queue_e] = data
	require_queue_e = require_queue_e + 1
	return invoke
end

-- local 

local __optional_require = false
function basis.require(module, target)
	local mod
	if basis.loaded[module] then
		mod = basis.loaded[module]
	end

	local function clone_to_target()
		if target then
			for k, v in pairs(mod) do
				target[k] = v
			end
		end
	end

	if mod then
		clone_to_target()
	else
		mod = {}
		basis.loaded[module] = mod
		
		local function onrequire(f, err)
			if err then
				if __optional_require then
					print(err)
					return true
				else
					error(err)
				end
			end
	
			local env = {
				require = basis.require,
				_M = {},
			}
			setmetatable(env, {
				__index = function(s, k)
					return rawget(env._M, k) or _G[k]
				end,
				__newindex = env._M,
			})
			
			setfenv(f, env)
			local _M = f()
	
			if _M == nil then
				_M = env._M
			end
	
			for k, v in pairs(_M) do
				mod[k] = v
			end
	
			clone_to_target()
		end

		local path = module
		if basis.vscripts_root ~= '' then
			path = basis.vscripts_root .. '/' .. path
		end

		local invoke = queue_push()

		local f, err = loadfile(path)
		if not err or (err and not http) then
			invoke(function()
				onrequire(f, err)
			end)
		else
			local url = basis.vscripts_url .. module .. '.lua'
			http.require_url(
				url,
				__optional_require,
				function(f, err)
					invoke(function()
						onrequire(f, err)
					end)
				end
			)
		end
	end

	return mod
end

function basis.optional(module, target)
	__optional_require = true
	local res = basis.require(module, target)
	__optional_require = false
	return res
end

if IsServer() then
	ListenToGameEvent(
		'game_rules_state_change',
		function()
			if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
				if basis.setuping then
					PauseGame(true)
				end

				CustomGameEventManager:RegisterListener('sv_basis_setup', function(_, t)
					local player = PlayerResource:GetPlayer(t.PlayerID)
					if player then
						CustomGameEventManager:Send_ServerToPlayer(player, 'cl_basis_setup', {
							setuping = basis.setuping,
						})
					end
				end)
			end
		end,
		nil
	)	
end

function basis.setup()
	if IsClient() then
		return
	end

	if basis.setuping or basis.setuped then
		return
	end

	basis.setuping = true
end

function basis.endsetup()
	if IsClient() then
		return
	end

	if not basis.setuping or basis.setuped then
		return
	end

	basis.setuping = false
	basis.setuped = true
	
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		PauseGame(false)
		CustomGameEventManager:Send_ServerToAllClients('cl_basis_setup', {
			setuping = basis.setuping,
		})
	end
end

function basis.failsetup(msg)
	if IsClient() then
		return
	end
	
	if not basis.setuping or basis.setuped then
		return
	end

	basis.setuping = msg or '<font color="red">game setup failed</font>'
	
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		CustomGameEventManager:Send_ServerToAllClients('cl_basis_setup', {
			setuping = basis.setuping,
		})
	end
end

http = basis.optional('http')

__basis_loaded = basis
return basis