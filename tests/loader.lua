local testing = require("testing")
local expect = testing.expect
local Loader = require("boot.loader")

return testing.suite("loader", {
    testing.test(
        "constructor_requires_imports_and_order",
        function()
            local imports_ok, imports_error = pcall(function()
                Loader.new({
                    order = {},
                })
            end)

            expect.falsy(imports_ok)
            expect.truthy(
                tostring(imports_error):find(
                    "Loader.new requires imports",
                    1,
                    true
                ) ~= nil,
                "missing imports fail at construction"
            )

            local order_ok, order_error = pcall(function()
                Loader.new({
                    imports = {},
                })
            end)

            expect.falsy(order_ok)
            expect.truthy(
                tostring(order_error):find(
                    "Loader.new requires order",
                    1,
                    true
                ) ~= nil,
                "missing order fails at construction"
            )
        end
    ),

    testing.test(
        "process_rejects_dot_call_without_receiver",
        function()
            local loader = Loader.new({
                imports = {},
                order = {},
                strict = true,
                notify = function() end,
            })

            local ok, err = pcall(function()
                loader.process({})
            end)

            expect.falsy(ok)
            expect.truthy(
                tostring(err):find(
                    "Loader:process must be called on a Loader instance",
                    1,
                    true
                ) ~= nil,
                "wrong call convention fails at the boundary"
            )
        end
    ),

    testing.test(
        "loads_selected_modules_in_declared_order",
        function()
            local calls = {}

            local loader = Loader.new({
                imports = {
                    first = {
                        { "one", "one" },
                        { "two", "two" },
                    },
                    second = {
                        { "three", "three" },
                    },
                },
                order = {
                    "second",
                    "first",
                },
                strict = true,
                notify = function() end,
                load = function(path)
                    table.insert(calls, path)
                    return {
                        path = path,
                    }
                end,
            })

            local state = loader:process({
                first = {
                    one = true,
                    two = false,
                },
                second = {
                    three = true,
                },
            })

            expect.equal(#calls, 2)
            expect.equal(calls[1], "three")
            expect.equal(calls[2], "one")
            expect.equal(state.second.three.path, "three")
            expect.equal(state.first.one.path, "one")
            expect.nil_value(state.first.two)

            local first_values = loader:values("first")
            local second_values = loader:values("second")

            expect.equal(#first_values, 1)
            expect.equal(first_values[1].path, "one")
            expect.equal(#second_values, 1)
            expect.equal(second_values[1].path, "three")
        end
    ),

    testing.test(
        "loader_instances_keep_independent_state",
        function()
            local first = Loader.new({
                imports = {
                    suites = {
                        { "one", "one" },
                    },
                },
                order = {
                    "suites",
                },
                strict = true,
                notify = function() end,
                load = function(path)
                    return "first:" .. path
                end,
            })

            local second = Loader.new({
                imports = {
                    suites = {
                        { "two", "two" },
                    },
                },
                order = {
                    "suites",
                },
                strict = true,
                notify = function() end,
                load = function(path)
                    return "second:" .. path
                end,
            })

            first:process({
                suites = {
                    one = true,
                },
            })

            second:process({
                suites = {
                    two = true,
                },
            })

            expect.equal(first:get("suites", "one"), "first:one")
            expect.nil_value(first:get("suites", "two"))
            expect.equal(second:get("suites", "two"), "second:two")
            expect.nil_value(second:get("suites", "one"))
        end
    ),

    testing.test(
        "strict_loader_surfaces_load_failure",
        function()
            local loader = Loader.new({
                imports = {
                    suites = {
                        { "broken", "broken" },
                    },
                },
                order = {
                    "suites",
                },
                strict = true,
                notify = function() end,
                load = function()
                    error("fixture failure")
                end,
            })

            local ok, err = pcall(function()
                loader:process({
                    suites = {
                        broken = true,
                    },
                })
            end)

            expect.falsy(ok)
            expect.truthy(
                tostring(err):find(
                    "Failed loading broken",
                    1,
                    true
                ) ~= nil,
                "strict loader identifies failed module"
            )
            expect.truthy(
                tostring(err):find(
                    "fixture failure",
                    1,
                    true
                ) ~= nil,
                "strict loader preserves load error"
            )
        end
    ),
}, {
    title = "Loader",
})
