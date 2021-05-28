local DEBUG_MODE = false
local MAX_MATCHES = 50

CraftDB = {}
CraftDB.__index = CraftDB

setmetatable(CraftDB, {
  __call = function(cls, ...) return cls.new(...) end,
})

function CraftDB.new()
  local self = setmetatable({}, CraftDB)
  self.technic_recipe_cache = {}
  return self
end

-- Only used for unit testing.
function CraftDB:_get_technic_recipe_cache()
  return self.technic_recipe_cache
end


-- Debugging aid.
local function _dump_table_to_file(table, filename)
  if DEBUG_MODE then
    local fname = minetest.get_worldpath() .. "/" .. filename
    local file = io.open(fname, "w")
    if file then
      file:write(dump(table))
      io.close(file)
      print("digiline_craftdb: Created file: " .. fname)
    end
  end
end


local function _make_table_from_strings(string_or_table)
  if type(string_or_table) == "string" then
    return {string_or_table}
  elseif type(string_or_table) == "table" then
    return string_or_table
  else
    return {}
  end
end


-- Creates a lookup table (key -> 1) from a list (int -> key).
local function _make_lut_from_list(list)
  local result = {}
  if type(list) == 'table' then
    for _, key in ipairs(list) do
      result[key] = 1
    end
  end
  return result
end


-- Input: "recipe.output" from a regular or technic recipe.
--    Input can be a single string or a table (indexed) list of strings.
-- Returns: Table in our canonical format.
-- Ex:
--  Input: {[1] = ["technic:copper_dust 3"], [2] = ["technic:tin_dust"]}
--  Returns: {["technic:copper_dust"] = 3, ["technic:tin_dust"] = 1}
function CraftDB:_merge_craft_recipe_items(input_list)
  local result = {}
  local input_ = input_list

  if (not input_list) or (input_list == "") then return {} end

  if type(input_list) == "string" then
    input_ = {[1] = input_list}
  end

  -- Input table is indexed by integers, but might have gaps, so must iterate
  -- using 'pairs()', not 'ipairs()'.
  if input_ then
    for _, item in pairs(input_) do
      local t = string.split(item, " ")
      if #t == 1 then
        t[2] = 1
      else
        t[2] = tonumber(t[2])
      end

      if result[t[1]] then
        result[t[1]] = result[t[1]] + t[2]
      else
        result[t[1]] = t[2]
      end
    end
  end

  return result
end


function CraftDB:_import_technic_recipe(typename, recipe)
  -- Handle nil input.
  if not recipe then return end

  -- recipe.output can be either a single string, or a table of strings.
  local outputs_ = self:_merge_craft_recipe_items(recipe.output)

  for item, count in pairs(outputs_) do
    -- The recipe is recorded for each output, because later we will want to
    -- search for all recipies that can give us a specific output.
    local new_recipe = {
      action = typename,
      inputs = _make_table_from_strings(recipe.input),
      outputs = outputs_,
      time = recipe.time,
    }

    local cache = self.technic_recipe_cache
    if not cache[item] then
      cache[item] = {}
    end

    table.insert(cache[item], new_recipe)
  end
end


-- Useful for debugging / testing, and for excluding some recipes.
-- Return 'true' to allow the recipe, 'false' to reject it.
function CraftDB:_filter_recipe(typename, recipe_name, recipe)
  return true
end


-- Imports filtered recipes from 'technic_recipes' into internal cache.
-- In production, this comes from the technic mod as 'technic.recipes'.
-- In test, this comes from the unit test itself (which is a copied subset of
-- what I found in production on one random day).
function CraftDB:import_technic_recipes(technic_recipes)
  -- Save for debugging, not required for operation.
  _dump_table_to_file(technic_recipes,
                      "digiline-craftdb-technic-raw.txt")

  for typename, data in pairs(technic_recipes) do
    -- typename is 'separating', 'cooking', 'extracting', etc...

    -- Skip 'cooking' items, they are duplicates from default using a furnace.
    if typename ~= "cooking" then
      for recipe_name, recipe in pairs(data.recipes) do
        if self:_filter_recipe(typename, recipe_name, recipe) then
          self:_import_technic_recipe(typename, recipe)
        end
      end
    end
  end

  -- Save for debugging, not required for operation.
  _dump_table_to_file(self.technic_recipe_cache,
                      "digiline-craftdb-technic-imported.txt")
end


-- Converts regular recipe into our internal format.
function CraftDB:canonicalize_regular_recipe(regular_recipe)
  local items = regular_recipe.items

  return {
    action = regular_recipe.type,
    outputs = self:_merge_craft_recipe_items({regular_recipe.output}),
    inputs = self:_merge_craft_recipe_items(items),

    -- 'craft' should be in the same format as one would send to the
    -- autocrafter (eg, a 3x3 grid instead of a 9-element table).
    craft = {
      { items[1] or "", items[2] or "", items[3] or "" },
      { items[4] or "", items[5] or "", items[6] or "" },
      { items[7] or "", items[8] or "", items[9] or "" }
    },

    -- NOTE: Regular recipes don't have a 'time', and the autocrafter produces
    -- 1 item/s.  So that our API is consistent between 'regular' and 'technic'
    -- production methods, we'll put in a fake time here.
    time = 1,
  }
end


function CraftDB:get_recipes(item_list)
  if type(item_list) ~= 'table' then return {} end

  local result = {}

  for _, item_name in ipairs(item_list) do
    -- Start with our technic recipes.
    local t = self.technic_recipe_cache[item_name]
    if t then
      for _, technic_recipe in ipairs(t) do
        table.insert(result, technic_recipe)
      end
    end

    -- Add in regular crafting and cooking recipes.
    local orig = minetest.get_all_craft_recipes(item_name)
    if orig then
      for _, regular_recipe in ipairs(orig) do
        table.insert(result, self:canonicalize_regular_recipe(regular_recipe))
      end
    end
  end

  -- Sort the recipes lexicographically by name of their outputs.
  -- Most receipes will have only one output, but for those that have >one,
  -- just.. meh, whatever.

  -- Actual sort order should not matter, but we'll sort anyway, so that the
  -- results are always consistently sorted.  This will save a 'table.sort()'
  -- step in most LUACs that use the list in a textarea in a touchscreen
  -- (digistuff:touchscreen).
  local sort_func = function(a, b)
    local _, out_a = next(a.outputs, nil)
    local _, out_b = next(b.outputs, nil)
    return out_a < out_b
  end

  table.sort(result, sort_func)

  return result
end


function CraftDB:search_items(name_pattern, options)
  local matching_names = {}  -- list of names

  if type(name_pattern) ~= 'string' then return {} end

  if type(options) ~= 'table' then options = {} end

  -- 'offset' must be an integer and >= 1.
  -- If not, set `offset` = 1.
  local offset = (type(options['offset']) == 'number') and
                 math.max(1, math.floor(options['offset'])) or 1

  -- 'max_count' must be an integer, and 1 <= max_count <= MAX_MATCHES.
  -- If not, set `max_count` = MAX_MATCHES.
  local max_count = (type(options['max_count']) == 'number') and
              math.min(math.max(1, math.floor(options['max_count'])),
                       MAX_MATCHES) or
              MAX_MATCHES

  -- 'group_filter' might be nil, but if present, should always be a table.
  local group_filter = options['group_filter']
  if (type(group_filter) ~= 'table') and (type(group_filter) ~= nil) then
    group_filter = {}
  end

  -- Generate exclusion lookup tables from the input lists.
  local exclude_mods = _make_lut_from_list(options['exclude_mods'])

  -- Are we looking up a group or item?  Groups start with 'group:'
  local group = nil
  if name_pattern:sub(1, 6) == 'group:' then
    group = name_pattern:sub(7)
    name_pattern = nil
  end

  -- Internal helper method, uses lambda capture of 'name_pattern'.
  -- NOTE: `string.find()` treats '.' as a meta-character that will match
  -- anything.
  -- Should return a bool.
  local function is_name_match(name)
    if options['substring_match'] then
      return nil ~= string.find(name, name_pattern)
    else
      return name == name_pattern
    end
  end

  -- Internal helper method, uses lambda capture of 'group'.
  local function is_group_match(groups)
    return group and (groups[group] ~= nil)
  end

  -- Internal helper method, no lambda capture.
  local function is_non_empty_string(s)
    return type(s) == 'string' and string.len(s) > 0
  end

  -- Internal helper method, filter items base on the item's group and
  -- user-supplied 'options.group_filter'.  Returning 'true' keeps the item.
  local function is_group_filter(groups)
    -- NOTE: Currently only handles 'group attributes' that are integers.
    -- Cannot handle tables.
    if group_filter then
      for g, filter_group_value in pairs(group_filter) do
        local item_group_value = groups[g]

        -- If filter for this group is a boolean, then ignore the item's
        -- group value and accept/reject the item based solely on group
        -- membership.
        if type(filter_group_value) == 'boolean' then
          if (filter_group_value and not item_group_value) or
             (not filter_group_value and item_group_value) then
            return false
          end
        elseif type(filter_group_value) == 'number' then
          if filter_group_value ~= item_group_value then
            return false
          end
        else  -- group metatype is unhandled; reject all items.
          return false
        end
      end
    end
    return true
  end

  -- Filter implementation, lots of captures.
  local function keep_item(name, registration)
    local groups = registration['groups'] or {}

    -- Primary item/group matching.
    if not (is_name_match(name) or is_group_match(groups)) then
      return false
    end

    -- Filter out items w/ membership in any excluded groups.
    if not is_group_filter(groups) then
      return false
    end

    -- Filter out items from any excluded mods.
    local mod_origin = registration['mod_origin'] or nil
    if mod_origin and exclude_mods[mod_origin] then
      return false
    end

    return true
  end

  -- Step #1.
  -- Find all matching items (includes nodes, craftitems and tools).
  for name, registration in pairs(minetest.registered_items) do
    if keep_item(name, registration) then
      table.insert(matching_names, name)
    end
  end

  -- Step #2
  -- Stable pagination if results exceed our limit.
  if (#matching_names > max_count) or (offset > 1) then
    -- Need to extract a slice of the output and return just that.
    -- Allows caller to 'page' between output results.
    table.sort(matching_names)
    local temp = {}
    for i = offset, offset + max_count - 1 do
      if matching_names[i] then
        table.insert(temp, matching_names[i])
      end
    end

    matching_names = temp
  end

  -- Step #3.
  -- Look up any additional registration data for each item.  Ex: user
  -- might want the 'inventory_image', so that they can display it in a
  --  digistuff:touchscreen for a nice craft-grid-like display (eg, via
  -- 'addimage').
  local result = {}
  for _, name in ipairs(matching_names) do
    result[name] = {}
    local registration = minetest.registered_items[name]
    -- print(dump(registration))

    if options.want_images then
      if is_non_empty_string(registration['inventory_image']) then
        result[name]['inventory_image'] = registration['inventory_image']
      elseif type(registration['tiles']) == 'table' then
        result[name]['inventory_image'] = registration['tiles'][1]
      end

      result[name]['wield_image'] = registration['wield_image']
    end

    if options.want_groups then
      result[name]['groups'] = registration['groups']
    end

    if options.want_everything and (#matching_names == 1) then
      result[name] = registration
    end
  end

  return result
end
