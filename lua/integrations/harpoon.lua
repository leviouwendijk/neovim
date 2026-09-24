local funcs = require("config.funcs")

-- local harpoon = require("harpoon")
local harpoon = funcs.require_or_nil("harpoon",
    {
        message = "harpoon missing; skipping setup",
    }
)

if not harpoon then
    return
end

harpoon:setup({
    settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
    },
})

local state = require("integrations.harpoon.state")(harpoon)

require("integrations.harpoon.bindings")(
    state.mark,
    state.ui
)

require("integrations.harpoon.statusline")(
    state.mark
)
