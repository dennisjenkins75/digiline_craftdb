# Digiline Craft Database

[![luacheck](https://github.com/dennisjenkins75/digiline_craftdb/workflows/luacheck/badge.svg)](https://github.com/dennisjenkins75/digiline_craftdb/actions)

# Overview

Adds a node that is a digiline queryable database of all crafting and technic
recipes known to the game engine.

This node can be used with a lua controller, lua sorting tubes and various
technic machines to create a fully automated 'Universal Autocrafting
Machine', which can recursively build anything (ex: technic:hv_battery_box0).

# Dependencies

Depends on:
* `technic`
* `digilines`

# APIs

1.  `get_recipes` - Given an exact item name, or table of exact item names,
    (ex: 'default:pick_stone', 'technic:hv_battery_box0', ...), return a list
    of all technic and regular recipes that can prodce those items.
1.  `search_items` - Given a partial (or full) item name, or full group name,
    return a table of all items with a matching name, and details about that
    item, such as its inventory image (for use in digistuff:touchscreen as
    'addimage').

## `get_recipes` API

`get_recipes` returns a list of all crafting, cooking and technic recipes that
can produce the item(s) specified.

Digiline request message format:
1.   `command` (string) - Literal string `get`.
1.   `item` (string) - Full (and exact) item string name in the form
     "mod_name:item_name". Ex: 'technic:hv_cable'.
1.    `items` (table of indexed strings) - Same format as `item`.

If both `item` and `items` are specified, then `items` is used and `item` is
ignored.

Example request:
```lua
  digiline_send ("craftdb", { command='get', item='default:pick_stone' })
  digiline_send ("craftdb", { command='get',
      items={ 'default:pick_stone', 'default:copper_ingot' }})
```

The 'repsonse' entry is a list (iterate via `ipairs()`) of recipe tables.

Each recipe table contains the following keys:

1. `inputs` (table) - keys are item names, values are quanties required.
    Note that this is NOT the crafting grid arrangement.  This is just a
    summary of the inputs for the LUAC's convienience.
1. `action` (string) - Which type of machine to use to create the item.  Values
    come directly from underlying technic and crafting tables:
    1.   `alloy`        (alloy furnace, has 2 inputs)
    1.   `compressing`  (compressor)
    1.   `extracting`   (extractor)
    1.   `freezing`     (freezer)
    1.   `grinding`     (grinder)
    1.   `separating`   (centrifuge)
    1.   `normal`       (autocrafter)
    1.   `cooking`      (furnace)
1.  `craft` (table of tables) - Actual crafting recipe, in the format that
    the autocrafter expects.  See below for example.
1.  `outputs` (table) - Maps item names to quantities of what is produced.
1.  `time` (number) - Count of seconds required to make the item.

Examples are at the bottom of this document.

## `search_items` API

`search_items`  returns a table of items matching the supplied item name or
group name.  The caller can request additional data for each matching item.

Digiline request message format:
1.   `command` (string) - Literal string `search_items`.
1.   `item` (string) - Search criteria; has one of three interpretations:
     1.   Exact match on item name (`substring_match` is non-truthy.
     1.   Substring match on item name (`substring_match` is truthy).
          Internally, uses 'string:find()'.  Use '' to match every
          registered item.
     1.   Exact match on group name if `item` begins with 'group:'.
          `substring_match` is ignored.
1.   `offset` (integer) - Defaults to 1.  Used to paginate the results
     if the count of items exceeds `max_count`.
1.   `max_count` (integer) - Defaults to 50.  Must be between 1 and 50.
     Maximum count of results to return.
1.   `substring_match` (boolean) - Defaults to false.  Use 'string:find()'
     to match item names instead of exact string equality test.
1.   `group_filter` (table) - Defaults to empty.  List of groups to
     filter results by.  See examples for details.
1.   `exclude_mods` (table) - Defaults to empty.  List of minetest mods
     to exclude items from.  Useful for finding items matching 
     `group:wood` that are not made by the tabelsaw (since you can't
      craft most things with them).  Ex: `technic_cnc`.
1.   `want_images` (boolean) - Defaults to false.  If true, then return
     the strings `inventory_image` and `wield_image` (filnames) for each
     item.  Useful if you want to use the images in a touchscreen UI.
1.   `want_groups` (boolean) - Defaults to false.  If true, then return
     the `groups` table for each matching item.
1.   `want_everything` (boolean) - Defaults to false.  if true, and the
     search result contains EXACTLY 1 item, then return the ENTIRE
     contents of `minetest.registered_items[item]` (this can be a lot of
     data).

Digiline response table format:
1.   key = full item string name.  Ex: `default:pick_stone`.
1.   value = table:
     1.   `inventory_image` - The inventory image filename copied from the
          item registration.  If this field is empty, then the first tile
          image filename.
     1.   `wield_image` - The value of `.wield_image`, if present.
     1.   `groups` - Table mapping group name to whatever (usually integers).
          Consult the minetest developer's guide for details.

If the `item` pattern results in fewer than `max_count`+1 matching items, then
the list is returned as-is.  If there are more initial results than
`max_count`, then the list is sorted by item string, then paginated by
`offset` and `max_count`.  In either case, the actual returned table is
indexed by item name, so it is not inherently sorted.

# Known Bugs

1.  Some crafting recipes genreate a 'returned item', these returned items
    are omitted from the return results.  This is due to
    `minetest.get_all_craft_recipes()` not returning information on the
    'returned item'. Ex: `default.dirt` takes a `bucket:bucket_water`
    and should return `bucket:bucket_empty`.  It is not safe for the
    craftdb to jam the returned item
    in, as some recipes also take buckets of liquid and do NOT return them 
    (ex: home decor's toilet).

1.  Lacks comprehensive unit testing for the `search_items` API.

# Examples

## `default:pick_stone` (crafting)

Send a (string) query for crafting recipe:

```lua
digiline_send("craftdb", {command='get_recipes', item='default:pick_stone'})
```

Response:
```lua
{
  {
    action = "normal",
    craft = {
      { "group:stone", "group:stone", "group:stone" },
      { "", "group:stick", "" },
      { "", "group:stick", "" }
    },
    inputs = {
      ["group:stone"] = 3
    },
    outputs = {
      ["default:pick_stone"] = 1
    },
    time = 1
  }
}
```

## `technic:hv_battery_box0` (crafting)

Request (sending table w/ 1 item):

```lua
digiline_send("craftdb", {command='get_recipes',
                          items={'technic:hv_battery_box0'}})
```

Response:
```lua
{
  {
    action = "normal",
    craft = {
      { "technic:mv_battery_box0", "technic:mv_battery_box0", "technic:mv_battery_box0" },
      { "technic:mv_battery_box0", "technic:hv_transformer", "technic:mv_battery_box0" },
      { "", "technic:hv_cable", "" }
    },
    inputs = {
      ["technic:hv_cable"] = 1,
      ["technic:mv_battery_box0"] = 5,
      ["technic:hv_transformer"] = 1
    },
    outputs = {
      ["technic:hv_battery_box0"] = 1
    },
    time = 1
  }
}
```

## `technic:copper_plate` (use compressor)

Request:

```lua
digiline_send("craftdb", {command='get_recipes', item='technic:copper_plate'})
```

Response:
```lua
{
  {
    action = "compressing",
    inputs = {
      ["default:copper_ingot"] = 5
    },
    outputs = {
      ["technic:copper_plate"] = 1
    },
    time = 4
  }
}
```

## `default:bronze_ingot` (Three of many responses)

Request:
```lua
digiline_send("craftdb", {command='get_recipes', item='default:bronze_ingot'})
```

Response:
```lua
{
  {
    action = "alloy",
    inputs = {
      ["default:tin_ingot"] = 1,
      ["default:copper_ingot"] = 7
    },
    outputs = {
      ["default:bronze_ingot"] = 8
    },
    time = 12
  },
  {
    action = "cooking",
    inputs = {
      ["technic:bronze_dust"] = 1
    },
    outputs = {
      ["default:bronze_ingot"] = 1
    },
    time = 1
  },
  {
    action = "normal",
    craft = {
      { "default:bronzeblock", "", "" },
      { "", "", "" },
      { "", "", "" }
    },
    inputs = {
      ["default:bronzeblock"] = 1
    },
    outputs = {
      ["default:bronze_ingot"] = 9
    },
    time = 1
  }
}
```

## `group:wood` (Search for valid wood plank items)

Request:
```lua:
digiline_send("craftdb", {
  command = 'search_items',
  name = 'group:wood',
  exclude_mods = { 'technic_cnc' },
  want_images = true,
  want_groups = true,
})
```

Response:
```lua
{
  ["default:junglewood"] = {
    inventory_image = "default_junglewood.png",
    groups = {
      wood = 1,
      choppy = 2,
      oddly_breakable_by_hand = 2,
      flammable = 2
    },
    wield_image = ""
  },
  ["default:aspen_wood"] = {
    inventory_image = "default_aspen_wood.png",
    groups = {
      wood = 1,
      choppy = 3,
      oddly_breakable_by_hand = 2,
      flammable = 3
    },
    wield_image = ""
  },
  ["default:wood"] = {
    inventory_image = "default_wood.png",
    groups = {
      wood = 1,
      choppy = 2,
      oddly_breakable_by_hand = 2,
      flammable = 2
    },
    wield_image = ""
  },
  ["default:pine_wood"] = {
    inventory_image = "default_pine_wood.png",
    groups = {
      wood = 1,
      choppy = 3,
      oddly_breakable_by_hand = 2,
      flammable = 3
    },
    wield_image = ""
  },
  ["default:acacia_wood"] = {
    inventory_image = "default_acacia_wood.png",
    groups = {
      wood = 1,
      choppy = 2,
      oddly_breakable_by_hand = 2,
      flammable = 2
    },
    wield_image = ""
  }
}

```

## `group:wood`, filter for 'choppy = 2'

Request:
```lua:
digiline_send("craftdb", {
  command = 'search_items',
  name = 'group:wood',
  exclude_mods = { 'technic_cnc' },
  group_filter = { choppy = 2 },
})
```

Response will contain ONLY members of group 'wood' that are also members
of 'choppy' with a value of '2'.  The same could also be accomplished with:

```lua:
digiline_send("craftdb", {
  command = 'search_items',
  name = '.',
  exclude_mods = { 'technic_cnc' },
  group_filter = { wood = true, choppy = 2, },
})
```
