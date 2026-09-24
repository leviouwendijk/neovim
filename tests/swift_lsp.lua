local testing = require("testing")
local expect = testing.expect

local package_swift = [[
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftLSPFixture",
    targets: [
        .target(
            name: "SwiftLSPFixture"
        ),
    ]
)
]]

local swift_source = [[
struct Greeting {
    let value: String
}

func makeGreeting() -> Greeting {
    Greeting(value: "hello")
}
]]

local function write_probe(path, source)
    local probe = string.format([=[
local source = %q

local function fail(message)
    io.stderr:write(
        "swift-lsp probe: "
            .. tostring(message)
            .. "\n"
    )
    vim.cmd("cquit 1")
end

vim.cmd(
    "edit "
        .. vim.fn.fnameescape(source)
)

local buffer =
    vim.api.nvim_get_current_buf()

local attached = vim.wait(
    15000,
    function()
        local clients = vim.lsp.get_clients({
            bufnr = buffer,
            name = "sourcekit",
        })

        return #clients > 0
            and clients[1].initialized
    end,
    50
)

if not attached then
    fail("sourcekit did not attach within 15s")
end

local clients = vim.lsp.get_clients({
    bufnr = buffer,
    name = "sourcekit",
})

if #clients ~= 1 then
    fail(
        "expected exactly one sourcekit client, got "
            .. tostring(#clients)
    )
end

local client = clients[1]

if client.offset_encoding ~= "utf-16" then
    fail(
        "unexpected offset encoding: "
            .. tostring(client.offset_encoding)
    )
end

if vim.bo[buffer].formatexpr
    ~= "v:lua.vim.lsp.formatexpr()"
then
    fail(
        "Swift LSP attach did not install formatexpr"
    )
end

local function has_mapping(mode, lhs)
    local mappings =
        vim.api.nvim_buf_get_keymap(
            buffer,
            mode
        )

    for _, mapping in ipairs(mappings) do
        if mapping.lhs == lhs then
            return true
        end
    end

    return false
end

if not has_mapping("n", "==") then
    fail(
        "Swift LSP attach did not install normal == mapping"
    )
end

if not has_mapping("x", "=") then
    fail(
        "Swift LSP attach did not install visual = mapping"
    )
end

local function has_buffer_mapping(mode, lhs)
    local mapping =
        vim.fn.maparg(
            lhs,
            mode,
            false,
            true
        )

    return type(mapping) == "table"
        and next(mapping) ~= nil
        and mapping.buffer == 1
end

local interaction_mappings = {
    { "n", "gd" },
    { "n", "[d" },
    { "n", "<leader>vy" },
    { "n", "<leader>vL" },
}

for _, mapping in ipairs(interaction_mappings) do
    if not has_buffer_mapping(
        mapping[1],
        mapping[2]
    ) then
        fail(
            "LSP interaction attach did not install "
                .. mapping[2]
                .. " mapping"
        )
    end
end

local function contains_symbol(items, target)
    for _, item in ipairs(items or {}) do
        if item.name == target then
            return true
        end

        if contains_symbol(
            item.children,
            target
        ) then
            return true
        end
    end

    return false
end

local params = {
    textDocument =
        vim.lsp.util.make_text_document_params(
            buffer
        ),
}

local symbol_ok = vim.wait(
    10000,
    function()
        local responses =
            vim.lsp.buf_request_sync(
                buffer,
                "textDocument/documentSymbol",
                params,
                2500
            )

        local response =
            responses
            and responses[client.id]

        if not response
            or response.err
            or not response.result
        then
            return false
        end

        return contains_symbol(
            response.result,
            "Greeting"
        )
    end,
    100
)

if not symbol_ok then
    fail(
        "sourcekit attached but did not return the Greeting document symbol"
    )
end

client:stop(true)

vim.cmd("qa!")
]=], source)

    local file, err = io.open(path, "wb")

    if not file then
        error(
            "failed to create Swift LSP probe: "
                .. tostring(err)
        )
    end

    file:write(probe)
    file:close()
end

return testing.suite("swift_lsp", {
    testing.test(
        "sourcekit_attaches_and_answers_document_symbols",
        function(context)
            local root =
                vim.g.nvim_config_test_root
            local init =
                vim.fs.joinpath(
                    root,
                    "init.lua"
                )

            local fixture = context:fixture({
                files = {
                    ["Package.swift"] =
                        package_swift,
                    ["Sources/SwiftLSPFixture/Greeting.swift"] =
                        swift_source,
                },
            })

            local source = fixture:path(
                "Sources/SwiftLSPFixture/Greeting.swift"
            )
            local probe =
                fixture:path("probe.lua")

            write_probe(
                probe,
                source
            )

            local result = vim.system({
                vim.v.progpath,
                "--headless",
                "-u",
                init,
                "-l",
                probe,
            }, {
                cwd = fixture.root,
                text = true,
            }):wait(30000)

            expect.equal(
                result.code,
                0,
                "live SourceKit LSP regression failed"
                    .. "\nstdout:\n"
                    .. tostring(result.stdout or "")
                    .. "\nstderr:\n"
                    .. tostring(result.stderr or "")
            )
        end
    ),
}, {
    title = "Swift LSP",
})
