unused_args = false
allow_defined_top = true

globals = {
    "minetest",
    "technic",
    "digilines",
}

read_globals = {
    string = {fields = {"split"}},

    -- Used by 'busted' (unit testing framework).
    "assert", "describe", "it",

    -- Builtin
    "dump",
}
