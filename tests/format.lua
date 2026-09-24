local testing = require("testing")
local expect = testing.expect
local list = require("utils.format.list")
local comma_list =
    require("utils.format.comma-list")
local swift_function =
    require("utils.format.swift-function")

local function expect_lines(
    actual,
    expected,
    label
)
    expect.equal(
        table.concat(actual, "\n"),
        table.concat(expected, "\n"),
        label
    )
end

return testing.suite(
    "format",
    {
        testing.test(
            "list_expands_array_items",
            function()
                expect_lines(
                    list.format({
                        "let values = [1, 2, 3]",
                    }),
                    {
                        "let values = [",
                        "    1,",
                        "    2,",
                        "    3",
                        "]",
                    },
                    "array formatting"
                )
            end
        ),

        testing.test(
            "comma_list_preserves_nested_commas",
            function()
                expect_lines(
                    comma_list.format(
                        {
                            "let values = [one, call(a, b), three]",
                        },
                        ""
                    ),
                    {
                        "let values = [",
                        "    one,",
                        "    call(a, b),",
                        "    three",
                        "]",
                    },
                    "nested comma formatting"
                )
            end
        ),

        testing.test(
            "swift_function_merges_and_expands_arguments",
            function()
                expect_lines(
                    swift_function.format(
                        {
                            "func greet(",
                            "    name: String,",
                            "    count: Int",
                            ") -> String {",
                        },
                        ""
                    ),
                    {
                        "func greet(",
                        "    name: String,",
                        "    count: Int",
                        ") -> String {",
                    },
                    "Swift function formatting"
                )
            end
        ),
    },
    {
        title = "Format",
    }
)
