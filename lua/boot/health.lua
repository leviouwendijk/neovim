local M = {}

local health = vim.health
local acc = require("accessor")

local function is_executable(cmd)
    return type(cmd) == "string" and cmd ~= "" and vim.fn.executable(cmd) == 1
end

local function first_executable(candidates)
    for _, cmd in ipairs(candidates) do
        if is_executable(cmd) then
            return cmd
        end
    end

    return nil
end

local function head(spec)
    if type(spec) == "string" then
        return spec
    end

    if type(spec) == "table" then
        if spec.bin then
            return head(spec.bin)
        end

        if spec.production then
            return head(spec.production)
        end

        return spec[1]
    end

    return nil
end

local function report(name, ok, severity, advice, found)
    local msg = name

    if found and found ~= "" then
        msg = string.format("%s: %s", name, found)
    end

    if ok then
        health.ok(msg)
        return
    end

    if severity == "error" then
        health.error(msg, advice)
    else
        health.warn(msg, advice)
    end
end

local function check_bin(name, cmd, severity, advice)
    local ok = is_executable(cmd)
    report(name, ok, severity, advice, ok and cmd or nil)
end

local function check_any(name, candidates, severity, advice)
    local found = first_executable(candidates)
    report(name, found ~= nil, severity, advice, found)
end

local function check_nvim_version()
    local ok = vim.fn.has("nvim-0.12") == 1
    report(
        "Neovim >= 0.12",
        ok,
        "error",
        {
            "Your config is built around newer APIs and vim.pack-era Neovim.",
            "Upgrade Neovim before trusting this health report.",
        },
        tostring(vim.version())
    )
end

local function check_gnu_tar()
    if is_executable("gtar") then
        health.ok("GNU tar preferred: gtar")
        return
    end

    if not is_executable("tar") then
        health.error("GNU tar preferred", {
            "GNU tar was not found.",
            "Install GNU tar if you need stricter compatibility for some install flows.",
            "On macOS with Homebrew: brew install gnu-tar",
        })
        return
    end

    local out = table.concat(vim.fn.systemlist({ "tar", "--version" }), "\n")
    if vim.v.shell_error == 0 and out:match("GNU tar") then
        health.ok("GNU tar preferred: tar")
        return
    end

    health.warn("GNU tar preferred", {
        "Found 'tar', but it does not look like GNU tar.",
        "This is usually fine on macOS, where /usr/bin/tar is typically bsdtar.",
        "Some install flows may behave better with GNU tar.",
        "Optional on macOS with Homebrew: brew install gnu-tar",
    })
end

function M.check()
    health.start("Core runtime")
    check_nvim_version()
    check_bin("git", "git", "error", "Required by plugin installs and Mason.")
    check_any("curl or wget", { "curl", "wget" }, "error", "Required for downloader/install flows.")
    check_bin("unzip", "unzip", "error", "Required by Mason/tool installers.")
    check_gnu_tar()
    check_bin("gzip", "gzip", "error", "Required by some installer flows.")
    check_any("C compiler", { "cc", "clang", "gcc" }, "error", "Tree-sitter parsers need a compiler.")
    check_bin("tree-sitter-cli", "tree-sitter", "error", {
        "Install the CLI, not just the library package.",
        "On macOS with Homebrew: brew install tree-sitter-cli",
    })
    check_bin("ripgrep", "rg", "error", "Used by Telescope grep workflows.")

    health.start("Configured binaries from this config")
    check_bin("trash", head(acc.bin.trash), "error", "Used by your netrw trash flow.")
    check_bin("open helper", head(acc.bin.open), "warn", "System open helper used by your config.")
    check_bin("clipboard copy helper", head(acc.bin.pbcopy), "warn", "Clipboard copy helper used by your config.")
    check_bin("clipboard paste helper", head(acc.bin.pbpaste), "warn", "Clipboard paste helper used by your config.")

    check_bin("python3", head(acc.bin.python), "warn", "Used by your output helpers and scripts.")
    check_bin("swift", head(acc.bin.swift), "warn", "Used by your output helpers and Swift workflows.")
    check_bin("ec", head(acc.bin.ec.bin), "warn", "Custom EC workflow binary.")
    check_bin("bedrocks", head(acc.bin.bedrocks), "warn", "Custom workflow binary.")
    check_bin("copier", head(acc.bin.copier), "warn", "Custom workflow binary.")

    health.start("Language servers and toolchains")
    check_bin("sourcekit-lsp", head(acc.bin.sourcekit), "error", "Required for your Swift LSP setup.")
    check_bin("eclsp", head(acc.bin.eclsp), "error", "Required for your EC LSP setup.")

    health.start("Likely plugin-related extras")
    check_bin("node", "node", "warn", "Useful for Node-based plugins; promote to required if markdown-preview is baseline.")
    check_bin("npm", "npm", "warn", "Used by plugins with npm install hooks.")
    check_bin("jq", "jq", "warn", "Needed if you use jq.nvim.")
    check_bin("d2", "d2", "warn", "Needed if you use your D2 workflow.")
    check_bin("java", "java", "warn", "Needed for PlantUML stack.")
    check_bin("graphviz (dot)", "dot", "warn", "Needed for PlantUML stack.")
    check_bin("plantuml", "plantuml", "warn", "Needed for PlantUML stack.")
    check_bin("uuidgen", "uuidgen", "warn", "Needed only if some helper uses it.")

    health.start("Suggested follow-up health checks")
    health.info("Run :checkhealth vim.lsp vim.treesitter")
    health.info("Also run plugin-specific checks such as :checkhealth mason when relevant")
end

return M
