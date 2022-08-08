local basic = require('basic')

function getplayers(t)
	t = basic.merge({
		spectators = false,
	}, t)

	local players = {}
	for pid = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayer(pid) then
			if t.spectators or not PlayerResource:IsBroadcaster(i) then
				table.insert(players, pid)
			end
		end
	end
	
	return players
end

-- function iplayers(t)
	

-- 	local players = {}
-- 	for pid = 0, DOTA_MAX_PLAYERS - 1 do
-- 		if PlayerResource:IsValidPlayer(pid) then
-- 			if t.spectators or not PlayerResource:IsBroadcaster(i) then
-- 				table.insert(players, pid)
-- 			end
-- 		end
-- 	end

-- 	local i = 1

-- 	return function()
-- 		local player = players[i]
-- 		i = i + 1
-- 		return player
-- 	end
-- end