-- We cache every recipe (default and technic) in a unified table, indexed
-- by output item.  For recipes with multiple outputs, the recipe is listed
-- twice.
--
-- NOTE: Technic recipes are loaded into 'technic.recipes' on a delay at game
-- init time (to support other mods' aliases from mods that load after we do).
-- See technic/machines/register/recipes.lua:65
--
-- Some recipes have multiple inputs, some multiple outputs, some a crafting
-- grid.  We'll just overload all of that into a single table definition.

-- Count of seconds to wait after this mod loads before attempting to index
-- all technic recipes.
local initialization_delay = 1.0

dofile(minetest.get_modpath(minetest.get_current_modname()).."/craftdb.lua")

digiline_craftdb = {}
digiline_craftdb.craftdb = CraftDB.new()


local _on_construct = function(pos)
  local formspec = "field[channel;Channel;${channel}]"
  minetest.get_meta(pos):set_string("formspec", formspec)
end


local _on_digiline_receive = function(pos, _, channel, msg)
  -- msg should be a table, with a key called 'command'.  Some commands
  -- take additional arguments.
  if type(msg) ~= "table" then return end

  local meta = minetest.get_meta(pos)
  if channel ~= meta:get_string("channel") then return end

  if msg.command == "get" then
    local items = {}
    if msg.items and type(msg.items) == 'table' then
      items = msg.items
    elseif msg.item and type(msg.item) == 'string' then
      items = {msg.item}
    else
      return
    end

    local result = digiline_craftdb.craftdb:get_all_recipes(items)
    digilines.receptor_send(pos, digilines.rules.default, channel, result)
  end

  if msg.command == "find" and msg.item and type(msg.item) == 'string' then
    local result = digiline_craftdb.craftdb:find_all_matching_items(
        msg.item, msg.offset, msg.max_count)
    digilines.receptor_send(pos, digilines.rules.default, channel, result)
  end
end


local _on_receive_fields = function(pos, _, fields, sender)
  local name = sender:get_player_name()
  if minetest.is_protected(pos, name) and
      not minetest.check_player_privs(name, {protection_bypass=true}) then
    minetest.record_protection_violation(pos, name)
    return
  end

  if (fields.channel) then
    minetest.get_meta(pos):set_string("channel", fields.channel)
  end
end


local function _delayed_init()
  digiline_craftdb.craftdb:import_technic_recipes(technic.recipes)
end


minetest.after(initialization_delay, _delayed_init)

minetest.register_node(minetest.get_current_modname()..":craftdb", {
  description = "Digiline Minetest Recipe Database",
  groups = {cracky = 3, oddly_breakable_by_hand = 2},
  tiles = {
    "digiline_craftdb_top.png",
    "jeija_microcontroller_bottom.png",
    "jeija_microcontroller_sides.png",
    "jeija_microcontroller_sides.png",
    "jeija_microcontroller_sides.png",
    "jeija_microcontroller_sides.png"
  },
  inventory_image = "digiline_craftdb_top.png",
  selection_box = {  -- From Luacontroller
    type = "fixed",
    fixed = { -8/16, -8/16, -8/16, 8/16, -5/16, 8/16 },
  },
  node_box = {  -- From Luacontroller
    type = "fixed",
    fixed = {
      {-8/16, -8/16, -8/16, 8/16, -7/16, 8/16},  -- Bottom slab
      {-5/16, -7/16, -5/16, 5/16, -6/16, 5/16},  -- Circuit board
      {-3/16, -6/16, -3/16, 3/16, -5/16, 3/16},  -- IC
    }
  },
  drawtype = "nodebox",
  paramtype = "light",
  sunlight_propagates = true,

  on_construct = _on_construct,
  on_receive_fields = _on_receive_fields,

  digiline = {
    receptor = {},
    effector = {
      action = _on_digiline_receive,
    },
  },
})

minetest.register_craft({
  output = minetest.get_current_modname()..":craftdb",
  recipe = {
    {"default:book", "default:book", "default:book" },
    {"", "mesecons_luacontroller:luacontroller0000", ""},
    {"", "digilines:wire_std_00000000", ""},
  },
})
