# Digiline Craft Database

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

1.  `get` - Given an exact item name (ex: 'default:pick_stone', 
    'technic:hv_battery_box0', ...), return a list
    of all technic and regular recipes that can prodce that item.
1.  `find` - Given a partial (or full) item name, return a table of all
    items with a matching name, and details about that item, such as its
    inventory image (for use in digistuff:touchscreen as 'addimage').

All respones are tables with 2 keys: `request` and `response`, with `request`
being a verbatim copy of the original request (so that a LUAC can send multiple
requests and correlate the resposnes).  The sub `response` table depends on
the API invoked.

## `get` API

`get` returns a list of all crafting, cooking and technic recipes that can
produce the item specified.

Digiline request message format:
1.   `command` (string) - Literal string `get`.
1.   `item` (string) - Full itemstring name in the form "mod_name:item_name".
     Ex: 'technic:hv_cable'.

Example request:
```lua
  { command='get', item='default:pick_stone' }
```

The 'repsonse' entry is a list (iterate via 'ipairs()') of recipe tables.

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
1.  `craft` (table) - Exact shape of which item goes into each slot of the
    crafting grid.  Contains two elements:
    1.  `width` (number) - Integer width of the crafting grid.
    1.  `grid` (table) - Maps grid index (1 to width^2) to a string (item name).
1.  `outputs` (table) - Maps item names to quantities of what is produced.
1.  `time` (number) - Count of seconds required to make the item.

Examples are at the bottom of this document.

## `find` API

`find` returns a table of matching item strings and their inventory images.
Additional data might be added in future revisions of this mod.

Digiline request message format:
1.   `command` (string) - Literal string `find`.
1.   `item` (string) - Any valid matcher passable to 'string:match()'.
     Use '.' to match every registered item.
1.   `offset` (integer) - Defaults to 1.  Used to paginate the results
     if the count of items exceeds `max_count`.
1.   `max_count` (integer) - Defaults to 20.  Must be between 1 and 20.
     Maximum count of results to return.

Digiline response table format:
1.   key = full item string name.  Ex: 'default:pick_stone'.
1.   value = table:
     1.   `inventory_image` - The inventory image filename copied from the
          item registration.

If the `item` pattern results in fewer than `max_count`+1 matching items, then
the list is returned as-is.  If there are more initial results than
`max_count`, then the list is sorted by item string, then paginated by
`offset` and `max_count`.  In either case, the actual returned table is
indexed by item name, so it is not inherently sorted.

# Known Bugs

1.  Some crafting recipes genreate a 'returned item', these returned items
    are omiited from the return results.  This is due to
    `minetest.get_all_craft_recipes()` not returning information on the
    'returned item'. Ex: `default.dirt` takes a `bucket:bucket_water`
    and should return `bucket:bucket_empty`.  It is not safe for the
    craftdb to jam the returned item
    in, as some recipes also take buckets of liquid and do NOT return them 
    (ex: home decor's toilet).

# Examples

## `default:pick_stone` (crafting)

Send a query for crafting recipe:

```lua
digiline_send("craftdb", {command='get', item='default:pick_stone'})
```

Response:
```lua
{
  request = {
    item = "default:pick_stone",
    command = "get"
  },
  response = {
    {
      inputs = {
        ["group:stone"] = 3
      },
      action = "normal",
      craft = {
        width = 3,
        grid = {
          "group:stone",
          "group:stone",
          "group:stone",
          [5] = "group:stick",
          [8] = "group:stick"
        }
      },
      outputs = {
        ["default:pick_stone"] = 1
      },
      time = 1
    }
  }
}
```

## `technic:hv_battery_box0` (crafting)

Request:

```lua
digiline_send("craftdb", {command='get', item='technic:hv_battery_box0'})
```

Response:
```lua
{
  request = {
    item = "technic:hv_battery_box0",
    command = "get"
  },
  response = {
    {
      action = "normal",
      craft = {
        width = 3,
        grid = {
          "technic:mv_battery_box0",
          "technic:mv_battery_box0",
          "technic:mv_battery_box0",
          "technic:mv_battery_box0",
          "technic:hv_transformer",
          "technic:mv_battery_box0",
          [8] = "technic:hv_cable"
        }
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
}
```

## `technic:copper_plate` (use compressor)

Request:

```lua
digiline_send("craftdb", {command='get', item='technic:copper_plate'})
```

Response:
```lua
{
  request = {
    item = "technic:copper_plate",
    command = "get"
  },
  response = {
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
}
```

## `default:bronze_ingot` (Three responses)

Request:
```lua
digiline_send("craftdb", {command='get', item='default:bronze_ingot'})
```

Response:
```lua
{
  request = {
    item = "default:bronze_ingot",
    command = "get"
  },
  response = {
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
      craft = {
        width = 3,
        grid = {
          "technic:bronze_dust"
        }
      },
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
        width = 1,
        grid = {
          "default:bronzeblock"
        }
      },
      inputs = {
        ["default:bronzeblock"] = 1
      },
      outputs = {
        ["default:bronze_ingot"] = 9
      },
      time = 1,
    }
  }
}
```

