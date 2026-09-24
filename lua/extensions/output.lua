local M = {}

local nicetstamp = require("extensions.nicetstamp")  -- NEW

-- -- debugger
-- local function dbg(label, fn)
--   local ok, err = pcall(fn)
--   if not ok then
--     vim.notify(("[output][FAIL @ %s] %s"):format(label, tostring(err)), vim.log.levels.ERROR)
--     error(err)
--   else
--     vim.notify(("[output][OK   @ %s]"):format(label), vim.log.levels.DEBUG)
--   end
-- end

local defaults = {
    default_mode = "split", -- "split" | "float"
    name = "[output]",
    float = {
        width  = 0.8,          -- fraction (0..1) or absolute cols
        height = 0.6,          -- fraction (0..1) or absolute rows
        border = "rounded",    -- "single" | "double" | "rounded" | "solid" | "shadow" (plenary)
        title  = "Output",
        filetype = "runoutput",
        winblend = 0,          -- transparency
    },
}

local state = {
    config =
        vim.tbl_deep_extend(
            "force",
            {},
            defaults
        ),
}

local split =
    require("extensions.output.split")({
        nicetstamp = nicetstamp,
        state = state,
    })

local float =
    require("extensions.output.float")({
        nicetstamp = nicetstamp,
        state = state,
        write_split = split.write,
    })

local runner =
    require("extensions.output.runner")({
        state = state,
        split = split,
        float = float,
    })

function M.run(opts)
    return runner.run(opts)
end

-- convenience
function M.run_file_in_split(cmd, file, lines)
    M.run({ cmd = cmd, file = file, lines = lines or 0, mode = "split" })
end

function M.run_file_in_float(cmd, file, lines, float_opts)
    M.run({ cmd = cmd, file = file, lines = lines or 0, mode = "float", float = float_opts })
end

function M.setup(opts)
    state.config =
        vim.tbl_deep_extend(
            "force",
            state.config,
            opts or {}
        )
    local config = state.config
    config.name = tostring(config.name or "[output]") -- ensure string

    assert(type(config.name) == "string", "config.name type=" .. type(config.name))
    assert(type(config.float.border) == "string", "border type=" .. type(config.float.border))

    split.set_name(config.name)
end

function M.status()
    return {
        split = split.status(),
        float = float.status(),
        default_mode = state.config.default_mode,
    }
end

function M.toggle(mode)
    mode = mode or state.config.default_mode
    if mode == "float" then
        -- if open, close; else open (create or reuse)
        float.toggle()  -- centers + focuses
    else -- "split"
        split.toggle()
    end
end

return M
