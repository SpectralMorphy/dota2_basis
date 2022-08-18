if __basis_loaded then
	__basis_loaded.reload = true
	return __basis_loaded
end

local http
local settings = LoadKeyValues('basis.kv')

local basis = {
	loaded = {},
	reload = false,
	setuping = false,
	setuped = false,
	vscripts_root = settings.vscripts_root or '',
	vscripts_url = 'https://raw.githubusercontent.com/SpectralMorphy/dota2_basis/main/vscripts/',
}

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

		local f, err = loadfile(path)
		if http then
			if not err then
				http.http_queue('require', function()
					onrequire(f, err)
				end)()
			else
				local url = basis.vscripts_url .. module .. '.lua'
				http.require_url(
					url,
					__optional_require,
					function(f, err)
						onrequire(f, err)
					end
				)
			end
		else
			onrequire(f, err)
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