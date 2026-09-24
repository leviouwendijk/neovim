local ok, luasnip = pcall(require, "luasnip")

if not ok then
    return
end

local snippet = luasnip.snippet
local text_node = luasnip.text_node
local insert_node = luasnip.insert_node

local function is_package_swift()
    return vim.fn.expand("%:t") == "Package.swift"
end

luasnip.add_snippets("swift", {
    snippet(
        {
            trig = "spmwarn",
            name = "Treat all SwiftPM warnings as errors",
            dscr = "Apply treatAllWarnings(as: .error) to applicable package targets",
        },
        {
            text_node(
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
            insert_node(0),
        },
        {
            condition = is_package_swift,
            show_condition = is_package_swift,
        }
    ),
    }, {
        key = "levi-swift-package-snippets",
    }
)
