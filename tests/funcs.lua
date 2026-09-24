local testing = require("testing")
local expect = testing.expect
local funcs = require("config.funcs")

local function with_preload(name, preload, body)
    local previous_preload = package.preload[name]
    local previous_loaded = package.loaded[name]

    package.preload[name] = preload
    package.loaded[name] = nil

    local ok, err = pcall(body)

    package.preload[name] = previous_preload
    package.loaded[name] = previous_loaded

    if not ok then
        error(err, 0)
    end
end

return testing.suite("funcs", {
    testing.test(
        "head_resolves_supported_command_shapes",
        function()
            local executable = vim.v.progpath

            expect.equal(
                funcs.head(executable),
                executable
            )
            expect.equal(
                funcs.head({
                    executable,
                    "--version",
                }),
                executable
            )
            expect.equal(
                funcs.head({
                    bin = {
                        executable,
                        "--version",
                    },
                }),
                executable
            )
            expect.equal(
                funcs.head({
                    production = executable,
                }),
                executable
            )
            expect.equal(
                funcs.head(function()
                    return {
                        bin = executable,
                    }
                end),
                executable
            )
            expect.nil_value(
                funcs.head(function()
                    error("fixture failure")
                end)
            )
        end
    ),

    testing.test(
        "has_executable_reports_resolved_head",
        function()
            local available, resolved =
                funcs.has_executable({
                    bin = {
                        vim.v.progpath,
                        "--version",
                    },
                })

            expect.truthy(available)
            expect.equal(resolved, vim.v.progpath)

            local missing = "__nvim_test_missing_executable__"
            local unavailable, missing_resolved =
                funcs.has_executable(missing)

            expect.falsy(unavailable)
            expect.equal(missing_resolved, missing)
        end
    ),

    testing.test(
        "warn_once_emits_only_once_per_key",
        function()
            local previous_notify = vim.notify
            local messages = {}

            local ok, err = pcall(function()
                rawset(vim, "notify", function(message)
                    table.insert(messages, message)
                end)

                local key =
                    "tests:funcs:warn_once:"
                    .. tostring(vim.loop.hrtime())

                funcs.warn_once(key, "first")
                funcs.warn_once(key, "second")

                expect.equal(#messages, 1)
                expect.equal(messages[1], "first")
            end)

            rawset(vim, "notify", previous_notify)

            if not ok then
                error(err, 0)
            end
        end
    ),

    testing.test(
        "once_require_caches_success",
        function()
            local name = "tests.__once_require_success"
            local calls = 0

            with_preload(name, function()
                calls = calls + 1
                return {
                    value = calls,
                }
            end, function()
                local load = funcs.once_require(name)
                local first = load()
                local second = load()

                expect.equal(calls, 1)
                expect.equal(first, second)
                expect.equal(first.value, 1)
            end)
        end
    ),

    testing.test(
        "once_require_or_nil_caches_failure",
        function()
            local name = "tests.__once_require_failure"
            local calls = 0

            with_preload(name, function()
                calls = calls + 1
                error("fixture failure")
            end, function()
                local load = funcs.once_require_or_nil(
                    name,
                    {
                        silent = true,
                    }
                )

                expect.nil_value(load())
                expect.nil_value(load())
                expect.equal(calls, 1)
            end)
        end
    ),
}, {
    title = "Config funcs",
})
