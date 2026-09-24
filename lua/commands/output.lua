local funcs = require("config.funcs")
local acc = require("accessor")

local output = funcs.require_or_nil("extensions.output", {
    message = "extensions.output missing; skipping output commands",
})

if not output then
    return
end

output.setup(
    {
        default_mode = "float",
        name = "[output]",
        float = {
            width = 0.9,
            height = 0.6,
            title = "Output",
            border = "rounded"
        },
    }
)

require("commands.output.commands")({
    output = output,
    acc = acc,
})
