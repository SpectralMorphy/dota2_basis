local basis = require('basic')

local abi_src = LoadKeyValues('scripts/npc/npc_abilities.txt')
local abi_custom = LoadKeyValues('scripts/npc/npc_abilities_custom.txt')
local abi_over = LoadKeyValues('scripts/npc/npc_abilities_override.txt')
local it_src = LoadKeyValues('scripts/npc/items.txt')
local it_custom = LoadKeyValues('scripts/npc/npc_items_custom.txt')

print(abi_over, it_src)
-- ABILITIES = basis.merge(abi_src, abi_custom, abi_over)