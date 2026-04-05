local funcs = require("config.funcs")

local ec = funcs.require_or_nil("extensions.ec-id", {
    message = "ec-id: extensions.ec-id module not found",
})

if not ec then
    return
end

ec.setup(
    {
        insert_target = "buffer",  -- buffer | register | clipboard | echo
        hops = 4,                  -- walk up to this many parents to find entries/
        use_stdout_flag = true,
        notify_collisions = true,
    }
)
