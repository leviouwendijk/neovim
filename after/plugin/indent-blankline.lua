local funcs = require("config.funcs")

local ibl = funcs.require_or_nil("ibl", {
    message = "ibl missing; skipping setup",
})

if not ibl then
    return
end

ibl.setup()
