local ok, luasnip = pcall(require, "luasnip")

if not ok then
    return
end

local function is_package_swift()
    return vim.fn.expand("%:t") == "Package.swift"
end

-- input args:
-- luasnip.add_snippets(filetype, snippets, options)

local filetype = "swift"

-- single snippet object:
local warning_as_errors_snippet = luasnip.snippet(
    {
        trig = "warnings_as_errors_package",
        name = "Treat all SwiftPM warnings as errors",
        dscr = "Apply treatAllWarnings(as: .error) to applicable package targets",
    },
    {
        luasnip.text_node(
            {
                "for target in package.targets {",
                "    switch target.type {",
                "    case .regular, .executable, .test, .macro:",
                "        var settings = target.swiftSettings ?? []",
                "",
                "        settings.append(",
                "            .treatAllWarnings(as: .error)",
                "        )",
                "",
                "        target.swiftSettings = settings",
                "",
                "    case .plugin, .system, .binary:",
                "        break",
                "",
                "    @unknown default:",
                "        break",
                "    }",
                "}",
                "",
            }
        ),
        luasnip.insert_node(0),
    },
    {
        condition = is_package_swift,
        show_condition = is_package_swift,
    }
)

-- snippets collected
local snippets = {
    warning_as_errors_snippet,
}

-- options
local options = {
    key = "levi-swift-package-snippets",
}

-- final call
luasnip.add_snippets(filetype, snippets, options)
