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


function CraftDB:get_all_recipes(item_list)
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


-- TODO: Add filtering so we can exclude nodes made via tablesaw.
function CraftDB:find_all_matching_items(name_pattern, offset, max_count)
  local matching_names = {}  -- list of names
  local image_names = {}  -- name -> image_filename

  if type(name_pattern) ~= 'string' then name_pattern = '.' end

  if type(offset) ~= 'number' then offset = 1 end
  offset = math.max(1, offset)

  if type(max_count) ~= 'number' then max_count = MAX_MATCHES end
  max_count = math.min(math.max(1, max_count), MAX_MATCHES)

  -- Step #1, find all matching items (includes nodes, craftitems and tools).
  for name, registration in pairs(minetest.registered_items) do
    if string.match(name, name_pattern) then
      table.insert(matching_names, name)
      image_names[name] = registration["inventory_image"]
    end
  end

  -- Step #2, stable pagination if results exceed our limit.
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

  -- Now, look up an image name for each item, so that user can supply
  -- image name to a digistuff:touchscreen for a nice craft-grid-like
  -- display (eg, via 'addimage').
  local result = {}
  for _, name in ipairs(matching_names) do
    result[name] = {
      inventory_image = image_names[name]
    }
  end

  return result
end
