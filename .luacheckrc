unused_args = false
allow_defined_top = true
unused = false
unused_globals = false

ignore = {
    "131",  -- Unused global variable
}

globals = {
    "minetest",
    "technic",
    "digilines",
}

read_globals = {
    string = {fields = {"split"}},
    table = {fields = {"copy", "getn"}},

    -- Used by 'busted' (unit testing framework).
    "assert", "describe", "it",

    -- Builtin
    "dump",
}
