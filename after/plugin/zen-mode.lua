local funcs = require("config.funcs")

local zen = funcs.require_or_nil("zen-mode", {
    message = "zen-mode missing; skipping setup",
})

if not zen then
    return
end

zen.setup({
    window = {
        width = 100,
        options = {}
    },
})
