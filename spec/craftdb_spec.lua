package.path = "../?.lua;" .. package.path

-- Minetest provides several helper functions (like 'string.split').  These
-- do NOT exist in 'busted', the Lua testing framework.  Our mod code uses
-- some of these minetest helpers though.  To get the busted unit tests to
-- work, we need to import the helper functions here, but only if running the
-- unit tests.  See 'tests/api_spec.lua'.
_G.core = {}
dofile("/usr/share/minetest/builtin/common/misc_helpers.lua")

require("craftdb")

_G.minetest = {}

function minetest.get_all_craft_recipes(item_name)
  return {}
end

minetest.registered_items = {
  ['farming:wheat'] = { inventory_image = 'foo.png' },
  ['dye:blue'] = { inventory_image = 'bar.png' },
  ['technic:gold_dust'] = { inventory_image = 'baz.png' },
}

-- Selection of "technic.recipes" used in some unit tests below.
-- First recipe from each typename, plus a few additional recipes.
local technic_recipes = {
  separating = {
    recipes = {
      ["farming:wheat"] = {
        input = {["farming:wheat"] = 4},
        time = 10,
        output = {
          "farming:seed_wheat 3",
          "default:dry_shrub"
        }
      },
    },
    output_size = 2,
    input_size = 1,
    description = "Separating"
  },
  cooking = {
    input_size = 1,
    output_size = 1
  },
  extracting = {
    recipes = {
      ["flowers:geranium"] = {
        input = {["flowers:geranium"] = 1},
        time = 4,
        output = "dye:blue 4"
      },
    },
    output_size = 1,
    input_size = 1,
    description = "Extracting"
  },
  grinding = {
    recipes = {
      ["default:gold_ingot"] = {
        input = {["default:gold_ingot"] = 1},
        time = 3,
        output = "technic:gold_dust"
      },
      -- Additional path to "technic:gold_dust", so that we have two total.
      ["default:gold_lump"] = {
        input = {["default:gold_lump"] = 1},
        time = 3,
        output = "technic:gold_dust 2"
     },
    },
    output_size = 1,
    input_size = 1,
    description = "Grinding"
  },
  alloy = {
    recipes = {
      ["technic:carbon_steel_dust/technic:coal_dust"] = {
        input = {
          ["technic:carbon_steel_dust"] = 1,
          ["technic:coal_dust"] = 1
        },
        time = 3,
        output = "technic:cast_iron_dust"
      },
    },
    output_size = 1,
    input_size = 2,
    description = "Alloying"
  },
  compressing = {
    recipes = {
      ["technic:carbon_cloth"] = {
        input = {["technic:carbon_cloth"] = 1},
        time = 4,
        output = "technic:carbon_plate"
      },
    },
    output_size = 1,
    input_size = 1,
    description = "Compressing"
  },
}





-- Tests
describe("CraftDB:_merge_craft_recipe_items", function()
  it("nil", function()
    local foo = CraftDB.new()
    assert.same({}, foo:_merge_craft_recipe_items(nil))
  end)

  it("empty", function()
    local foo = CraftDB.new()
    assert.same({}, foo:_merge_craft_recipe_items(""))
  end)

  it("string", function()
    local foo = CraftDB.new()
    assert.same({["foo:bar"] = 4},
                foo:_merge_craft_recipe_items("foo:bar 4"))
  end)

  it("table", function()
    local _in = { "technic:copper_dust 3", "technic:tin_dust", }
    local _expected = {
      ["technic:copper_dust"] = 3,
      ["technic:tin_dust"] = 1,
    }
    local foo = CraftDB.new()
    assert.same(_expected, foo:_merge_craft_recipe_items(_in))
  end)
end)

describe("CraftDB:_import_technic_recipe", function()
  it("nil", function()
    local foo = CraftDB.new()
    foo:_import_technic_recipe("grinding", nil)
    assert.same({}, foo:_get_technic_recipe_cache())
  end)

  it("empty", function()
    local foo = CraftDB.new()
    foo:_import_technic_recipe("grinding", {})
    assert.same({}, foo:_get_technic_recipe_cache())
  end)

  it("works", function()
    -- 'recipe' is a raw technic recipe.
    -- Copied directly from dump of 'technic.recipes'.
    local recipe = {
      input = {
        ["technic:bronze_dust"] = 4,
      },
      time = 10,
      output = {
        "technic:copper_dust 3",
        "technic:tin_dust",
      },
    }

    -- 'expected' is in our canonical format.
    -- Note that the input recipe produces two outputs.
    local expected = {
      ["technic:copper_dust"] = {
        [1] = {
          action = "separating",
          inputs = {
            ["technic:bronze_dust"] = 4
          },
          outputs = {
            ["technic:copper_dust"] = 3,
            ["technic:tin_dust"] = 1,
          },
          time = 10,
        },
      },
      ["technic:tin_dust"] = {
        [1] = {
          action = "separating",
          inputs = {
            ["technic:bronze_dust"] = 4
          },
          outputs = {
            ["technic:copper_dust"] = 3,
            ["technic:tin_dust"] = 1,
          },
          time = 10,
        },
      },
    }

    local foo = CraftDB.new()
    foo:_import_technic_recipe("separating", recipe)
    assert.same(expected, foo:_get_technic_recipe_cache())
  end)
end)

describe("CraftDB:import_technic_recipes", function()
  it("empty", function()
    local foo = CraftDB.new()
    foo:import_technic_recipes({})
    assert.same({}, foo:_get_technic_recipe_cache())
  end)

  it("works", function()
    local expected = {
      ["default:dry_shrub"] = {
        [1] = {
          action = "separating",
          inputs = {["farming:wheat"] = 4},
          outputs = {["farming:seed_wheat"] = 3, ["default:dry_shrub"] = 1},
          time = 10,
        },
      },
      ["dye:blue"] = {
        [1] = {
          action = 'extracting',
          inputs = {["flowers:geranium"] = 1},
          outputs = {["dye:blue"] = 4},
          time = 4,
        },
      },
      ["farming:seed_wheat"] = {
        [1] = {
          action = "separating",
          inputs = {["farming:wheat"] = 4},
          outputs = {["farming:seed_wheat"] = 3, ["default:dry_shrub"] = 1},
          time = 10,
        },
      },
      ["technic:carbon_plate"] = {
        [1] = {
          action = "compressing",
          inputs = {["technic:carbon_cloth"] = 1},
          outputs = {["technic:carbon_plate"] = 1},
          time = 4,
        },
      },
      ["technic:cast_iron_dust"] = {
        [1] = {
          action = "alloy",
          inputs = {["technic:carbon_steel_dust"] = 1,
                    ["technic:coal_dust"] = 1},
          outputs = {["technic:cast_iron_dust"] = 1},
          time = 3,
        },
      },
      ["technic:gold_dust"] = {
        [1] = {
          action = "grinding",
          inputs = {["default:gold_ingot"] = 1},
          outputs = {["technic:gold_dust"] = 1},
          time = 3,
        },
        [2] = {
          action = "grinding",
          inputs = {["default:gold_lump"] = 1},
          outputs = {["technic:gold_dust"] = 2},
          time = 3,
        }
      },
    }

    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    assert.same(expected, foo:_get_technic_recipe_cache())
  end)
end)

describe("CraftDB:canonicalize_regular_recipe", function()
  it("works", function()
    local input = {
      type = "normal",
      output = "default:pick_steel",
      items = {
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        [5] = "group:stick",
        [8] = "group:stick"
      },
      width = 3,
    }

    local expected = {
      action = "normal",
      craft = {
        { "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
        { "", "group:stick", "" },
        { "", "group:stick", "" },
      },
      inputs = {["default:steel_ingot"] = 3, ["group:stick"] = 2},
      outputs = {["default:pick_steel"] = 1},
      time = 1,
    }

    local foo = CraftDB.new()
    assert.same(expected, foo:canonicalize_regular_recipe(input))
  end)
end)

describe("CraftDB:get_all_recipes", function()
  it("nil", function()
    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    local output = foo:get_all_recipes(nil)
    assert.same({}, output)
  end)

  it("invalid_type", function()
    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    local output = foo:get_all_recipes("this.should.be.a.table")
    assert.same({}, output)
  end)

  it("invalid_item", function()
    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    local output = foo:get_all_recipes({"no_such_mod:no_such_item"})
    assert.same({}, output)
  end)

  it("technic_item", function()
    local expected = {
      {
        action = 'grinding',
        inputs = { ['default:gold_ingot'] = 1 },
        outputs = { ['technic:gold_dust'] = 1 },
        time = 3,
      }, {
        action = 'grinding',
        inputs = { ['default:gold_lump'] = 1 },
        outputs = { ['technic:gold_dust'] = 2 },
        time = 3,
      }
    }

    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    local output = foo:get_all_recipes({"technic:gold_dust"})
    assert.same(expected, output)
  end)

  it("multiple_items", function()
    local expected = {
      {
        action = 'grinding',
        inputs = { ['default:gold_ingot'] = 1 },
        outputs = { ['technic:gold_dust'] = 1 },
        time = 3,
      }, {
        action = 'grinding',
        inputs = { ['default:gold_lump'] = 1 },
        outputs = { ['technic:gold_dust'] = 2 },
        time = 3,
      }, {
        action = 'extracting',
        inputs = {["flowers:geranium"] = 1},
        outputs = {["dye:blue"] = 4},
        time = 4,
      }
    }

    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    local output = foo:get_all_recipes({"technic:gold_dust", "dye:blue"})
    assert.same(expected, output)
  end)
end)

describe("CraftDB:find_all_matching_items", function()
  it("works", function()
    local expected = {
      ['dye:blue'] = { inventory_image = 'bar.png'},
    }

    local foo = CraftDB.new()
    foo:import_technic_recipes(technic_recipes)
    local output = foo:find_all_matching_items('dye:', 1, 99)
    assert.same(expected, output)
  end)
end)
