local M = {}

local acc = require("accessor")

local function cmd_target(spec)
    if type(spec) == "string" then
        return spec
    end

    if type(spec) == "table" then
        if spec.production then
            return cmd_target(spec.production)
        end

        return spec[1]
    end

    return nil
end

local function is_exec(cmd)
    if not cmd or cmd == "" then
        return false
    end

    return vim.fn.executable(cmd) == 1
end

local function first_exec(candidates)
    for _, cmd in ipairs(candidates) do
        if is_exec(cmd) then
            return cmd
        end
    end

    return nil
end

local function version_string()
    local v = vim.version()
    return string.format("%d.%d.%d", v.major, v.minor, v.patch)
end

local function nvim_at_least(major, minor)
    local v = vim.version()

    if v.major ~= major then
        return v.major > major
    end

    return v.minor >= minor
end

local function gnu_tar_status()
    if is_exec("gtar") then
        return "ok", "gtar"
    end

    if not is_exec("tar") then
        return "missing", "tar missing"
    end

    local out = table.concat(vim.fn.systemlist({ "tar", "--version" }), "\n")

    if out:match("GNU tar") then
        return "ok", "tar (GNU)"
    end

    return "warn", "tar found, but it is not GNU tar"
end

local function push_status(lines, status, label, detail)
    local prefix = ({
        ok = "[OK]",
        warn = "[WARN]",
        missing = "[MISSING]",
        optional = "[OPTIONAL]",
    })[status] or "[INFO]"

    if detail and detail ~= "" then
        table.insert(lines, string.format("%-10s %s — %s", prefix, label, detail))
    else
        table.insert(lines, string.format("%-10s %s", prefix, label))
    end
end

local function push_line(lines, ok, label, detail)
    push_status(lines, ok and "ok" or "missing", label, detail)
end

local function push_optional(lines, ok, label, detail)
    local prefix = ok and "[OK]" or "[OPTIONAL]"

    if detail and detail ~= "" then
        table.insert(lines, string.format("%-10s %s — %s", prefix, label, detail))
    else
        table.insert(lines, string.format("%-10s %s", prefix, label))
    end
end

local function section(lines, title)
    table.insert(lines, "")
    table.insert(lines, title)
    table.insert(lines, string.rep("-", #title))
end

local function open_report(lines)
    vim.cmd("botright new")

    local buf = vim.api.nvim_get_current_buf()

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = "markdown"

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    vim.keymap.set("n", "q", "<cmd>bd!<CR>", {
        buffer = buf,
        silent = true,
        desc = "Close dependency report",
    })

    vim.cmd("normal! gg")
end

function M.run()
    local lines = {}

    local compiler = first_exec({ "cc", "clang", "gcc" })
    local downloader = first_exec({ "curl", "wget" })

    local tar_status, tar_detail = gnu_tar_status()

    local sourcekit = cmd_target(acc.bin.sourcekit)
    local eclsp = cmd_target(acc.bin.eclsp)

    local opener = cmd_target(acc.bin.open)
    local clipboard_copy = cmd_target(acc.bin.pbcopy)
    local clipboard_paste = cmd_target(acc.bin.pbpaste)

    table.insert(lines, "# Config dependency report")
    table.insert(lines, "")
    table.insert(lines, "Current Neovim: " .. version_string())

    section(lines, "Core required")
    push_line(lines, nvim_at_least(0, 12), "Neovim >= 0.12", "needed for vim.pack-based setup")
    push_line(lines, is_exec("git"), "git")
    push_line(lines, downloader ~= nil, "curl or wget", downloader or "neither found")
    push_line(lines, is_exec("unzip"), "unzip")
    push_status(lines, tar_status, "GNU tar preferred", tar_detail)
    push_line(lines, is_exec("gzip"), "gzip")
    push_line(lines, is_exec("tree-sitter"), "tree-sitter-cli", "binary name is tree-sitter")
    push_line(lines, compiler ~= nil, "C compiler", compiler or "no cc / clang / gcc found")
    push_line(lines, is_exec("rg"), "ripgrep", "binary name is rg")
    push_line(lines, is_exec("trash"), "trash")
    push_line(lines, is_exec("node"), "node")
    push_line(lines, is_exec("npm"), "npm")

    section(lines, "Configured language tooling")
    push_line(lines, is_exec(sourcekit), "sourcekit-lsp", sourcekit or "not configured")
    push_line(lines, is_exec(eclsp), "eclsp", eclsp or "not configured")

    section(lines, "Configured system helpers")
    push_line(lines, is_exec(opener), "open helper", opener or "not configured")
    push_line(lines, is_exec(clipboard_copy), "clipboard copy helper", clipboard_copy or "not configured")
    push_line(lines, is_exec(clipboard_paste), "clipboard paste helper", clipboard_paste or "not configured")
    push_optional(lines, is_exec("defaults"), "defaults", "macOS appearance helper")

    section(lines, "Optional / workflow-specific")
    push_optional(lines, is_exec("jq"), "jq", "jq.nvim")
    push_optional(lines, is_exec("d2"), "d2", "D2 preview / fmt / validate")
    push_optional(lines, is_exec("java"), "java", "PlantUML preview stack")
    push_optional(lines, is_exec("dot"), "graphviz", "dot binary")
    push_optional(lines, is_exec("plantuml"), "plantuml")
    push_optional(lines, is_exec("python3"), "python3", "output helpers / scripts")
    push_optional(lines, is_exec("python3.11"), "python3.11", "HtmlPdfLandscape helper")
    push_optional(lines, is_exec("swift"), "swift", "output helpers")
    push_optional(lines, is_exec("bedrocks"), "bedrocks", "custom workflow binary")
    push_optional(lines, is_exec("copier"), "copier", "custom workflow binary")
    push_optional(lines, is_exec("ec"), "ec", "custom workflow binary")
    push_optional(lines, is_exec("stf"), "stf", "custom workflow binary")
    push_optional(lines, is_exec("casecon"), "casecon", "custom workflow binary")
    push_optional(lines, is_exec("uuidgen"), "uuidgen")

    section(lines, "Not currently on the required list")
    table.insert(lines, "- luarocks")
    table.insert(lines, "- a separate external LuaJIT install")
    table.insert(lines, "- Homebrew `tree-sitter` library formula (unless you explicitly want the library too)")

    open_report(lines)
end

return M
