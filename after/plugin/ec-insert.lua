local funcs = require("config.funcs")

local tpl = funcs.require_or_nil("extensions.ec-template", {
    message = "ec-insert: extensions.ec-template not found",
})

if not tpl then
    return
end

tpl.setup(
    {
        kind = "entry",
        hops = 4,
        use_stdout_flag = true,
        notify_collisions = true,
    }
)
