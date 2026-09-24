local funcs = require("config.funcs")
local acc = require("accessor")
funcs.require_or_nil("utils.word-count", {
    message = "utils.word-count missing; continuing without eager preload",
    silent = true,
})
local bedrocks_depth = funcs.require_or_nil("extensions.bedrocks-depth", {
    message = "extensions.bedrocks-depth missing; skipping statusline setup",
})
local statusline = funcs.require_or_nil("customizations.statusline", {
    message = "customizations.statusline missing; skipping statusline setup",
})
if not bedrocks_depth or not statusline then
    return
end
local bedrocks_root = acc.paths.bedrocks.root


require("interface.statusline.variants")

require("interface.statusline.bedrocks")({
    root = bedrocks_root,
    depth = bedrocks_depth,
})

statusline.setup(
    {
        mode = "path_left",  -- "right" or "path_left"
        show_words = true,
        bedrocks_root = bedrocks_root,
    }
)

require("interface.statusline.netrw")
