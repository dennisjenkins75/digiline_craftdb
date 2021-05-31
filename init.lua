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


local function _on_construct(pos)
  local formspec = "field[channel;Channel;${channel}]"
  minetest.get_meta(pos):set_string("formspec", formspec)
end

-- 'get_recipes' command
-- msg.command == 'get_recipes'
-- msg.item (string, optional):
--    Full item name of get recipes for (ex: 'default:pick_steel').
-- msg.items (table, optional):
--    List of full item names to get recipes for.
--    Ex: {'default:pick_steel', 'default:wood'}

local function _on_digiline_get_recipes(pos, channel, msg)
    local items
    if msg.items and type(msg.items) == 'table' then
      items = msg.items
    elseif msg.item and type(msg.item) == 'string' then
      items = {msg.item}
    else
      return
    end

    local result = digiline_craftdb.craftdb:get_recipes(items)
    digilines.receptor_send(pos, digilines.rules.default, channel, result)
end


-- 'search_items' command
-- msg.command == 'search_items'.
-- msg.name (string, required):
--     Partial (or full) item name.  If in the format 'group:STRING', then
--     lookup will return all items having that group.  An empty string will
--     match all item names if `substring_match` = true.
-- msg.offset (integer, optional, default 1):
--     Offset for paging through large results.
-- msg.max_count (integer, optional, default MAX_MATCHES):
--     Max count of items to return at once.  Capped internally (see
--     Craftdb:MAX_MATCHES) also, but user can request lower maximum.
-- msg.substring_match (bool, optional, default false)
--     Perform string.find() on the item.  If false, then used a direct
--     string equality test.
-- msg.group_filter (table, optional):
--     If present, only return items that exactly* match all of the specified
--     groups and group values.  Table has same format as the item's registered
--     groups table.  *Note: See examples for special matching rules.
-- msg.exclude_mods (table, optional);
--     List of module names to filter out.  If the item's registration
--     includes ".mod_origin" and its value is in ex_mods, then omit this
--     item from the search results.  Common value to use here would be
--     'technic_cnc' to filter out all items made on a tablesaw.
-- msg.want_images (bool, optional, defaults false):
--     If true, then return the inventory_image value (or a suitable
--     replacement) and a wield_image value (if present) for each matching item.
-- msg.want_groups (bool, optional, defaults false):
--     If true, thren return the groups table for each matching item.
-- msg.want_everything (bool, optional, defaults false):
--     If true, and there is only ONE resulting item, then return the entire
--     item registration (this can be fairly large).

local function _on_digiline_search_items(pos, channel, msg)
  -- To reduce arg clutter, and make it easier for other mods to call our
  -- internal API, we pack all of our "options" into a table.
  local options = {
    -- TODO: Sanitize/deep-copy these values?  Is that needed?
    offset = msg['offset]'],
    max_count = msg['max_count'],
    substring_match = msg['substring_match'],
    group_filter = msg['group_filter'],
    exclude_mods = msg['exclude_mods'],
    want_images = msg['want_images'],
    want_groups = msg['want_groups'],
    want_everything = msg['want_everything'],
  }

  local result = digiline_craftdb.craftdb:search_items(
      msg.name, options)
  digilines.receptor_send(pos, digilines.rules.default, channel, result)
end


local _on_digiline_receive = function(pos, _, channel, msg)
  -- msg should be a table, with a key called 'command'.  Some commands
  -- take additional arguments.
  if type(msg) ~= "table" then return end

  local meta = minetest.get_meta(pos)
  if channel ~= meta:get_string("channel") then return end

  -- Find recipes that match 'msg.item' (string) or 'msg.items' (table)
  if msg.command == "get_recipes" then
    _on_digiline_get_recipes(pos, channel, msg)
  end

  -- Search for all registered items that match the supplied
  -- item name or group, and optionally exclude items from specific
  -- groups or mod_origin.
  if msg.command == "search_items" then
    _on_digiline_search_items(pos, channel, msg)
  end
end


local function _on_receive_fields(pos, _, fields, sender)
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
