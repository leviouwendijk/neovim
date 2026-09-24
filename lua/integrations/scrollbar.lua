local funcs = require("config.funcs")

local scrollbar = funcs.require_or_nil("scrollbar", {
    message = "scrollbar missing; skipping setup",
})

if not scrollbar then
    return
end

scrollbar.setup()
