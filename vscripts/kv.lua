local basic = require('basic')

local abi_src = LoadKeyValues('scripts/npc/npc_abilities.txt') or {}
local abi_cust = LoadKeyValues('scripts/npc/npc_abilities_custom.txt') or {}
local abi_over = LoadKeyValues('scripts/npc/npc_abilities_override.txt') or {}
local it_src = LoadKeyValues('scripts/npc/items.txt') or {}
local it_cust = LoadKeyValues('scripts/npc/npc_items_custom.txt') or {}
local her_src = LoadKeyValues('scripts/npc/npc_heroes.txt') or {}
local her_cust = LoadKeyValues('scripts/npc/npc_heroes_custom.txt') or {}
local uni_src = LoadKeyValues('scripts/npc/npc_units.txt') or {}
local uni_cust = LoadKeyValues('scripts/npc/npc_units_custom.txt') or {}

ABILITIES = basic.merge(abi_src, abi_cust, abi_over)
ITEMS = basic.merge(it_src, it_cust, abi_over)
HEROES = basic.merge(her_src, her_cust)
UNITS = basic.merge(uni_src, uni_cust)

for _, t in ipairs{ABILITIES, ITEMS, HEROES, UNITS} do
	setmetatable(t, {
		__call = function(self)
			return basic.merge({}, self)
		end
	})
end

function GetKV(name)
	local spell = ABILITIES[name] or ITEMS[name]
	if spell then
		return basic.merge({}, ABILITIES.ability_base, spell)
	end

	local unit = UNITS[name]
	if unit then
		return basic.merge({}, UNITS.npc_dota_units_base, unit)
	end

	local hero = HEROES[name]
	if hero then
		return basic.merge({}, UNITS.npc_dota_units_base, HEROES.npc_dota_hero_base, hero)
	end
end