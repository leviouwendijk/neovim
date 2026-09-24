local uv = vim.uv or vim.loop

local Outcome = require("testing.outcome")
local Result = require("testing.result")
local Fixture = require("testing.fixture")

local Runner = {}

local function emit(sink, event)
    if sink and sink.receive then
        sink:receive(event)
    end
end

local function make_context()
    local fixtures = {}

    local context = {}

    function context:fixture(spec)
        local fixture = Fixture.new(spec)
        table.insert(fixtures, fixture)
        return fixture
    end

    function context:cleanup()
        local failures = {}

        for index = #fixtures, 1, -1 do
            local ok, err = pcall(function()
                fixtures[index]:cleanup()
            end)

            if not ok then
                table.insert(failures, tostring(err))
            end
        end

        return failures
    end

    return context
end

local function descriptor(test, path)
    return {
        id = test.id,
        path = table.concat(path, "/"),
        display_name = test.title or test.id,
        tags = test.tags or {},
    }
end

local function max_test_path_width(suite)
    local maximum = 0

    local function scan(node, parent_path)
        local suite_path = vim.list_extend(
            vim.deepcopy(parent_path),
            { node.id }
        )

        for _, child in ipairs(node.nodes) do
            if child.kind == "suite" then
                scan(child, suite_path)
            else
                local test_path = vim.list_extend(
                    vim.deepcopy(suite_path),
                    { child.id }
                )
                local path = table.concat(
                    test_path,
                    "/"
                )
                maximum = math.max(
                    maximum,
                    vim.fn.strdisplaywidth(path)
                )
            end
        end
    end

    scan(suite, {})
    return maximum
end

local function runtime_issue(captured)
    local value = captured.value

    if type(value) == "table" and value.__testing_failure then
        return value
    end

    return {
        label = "runtime",
        message = tostring(value),
        traceback = captured.traceback,
    }
end

local function run_test(test, path, sink)
    local test_descriptor = descriptor(test, path)

    emit(sink, {
        kind = "test_started",
        test = test_descriptor,
    })

    if test.skip then
        local skipped = Result.test(
            test_descriptor,
            Outcome.skipped,
            0,
            {
                {
                    label = "skip",
                    message = test.skip,
                },
            }
        )

        emit(sink, {
            kind = "test_finished",
            result = skipped,
        })
        return skipped
    end

    local context = make_context()
    local started = uv.hrtime()

    local ok, captured = xpcall(
        function()
            test.operation(context)
        end,
        function(err)
            return {
                value = err,
                traceback = debug.traceback("", 2),
            }
        end
    )

    local duration_ns = uv.hrtime() - started
    local cleanup_failures = context:cleanup()

    local outcome = ok and Outcome.passed or Outcome.failed
    local issues = {}

    if not ok then
        table.insert(issues, runtime_issue(captured))
    end

    for _, cleanup_error in ipairs(cleanup_failures) do
        outcome = Outcome.failed
        table.insert(issues, {
            label = "teardown",
            message = cleanup_error,
        })
    end

    if test.expected_failure then
        if outcome == Outcome.failed then
            outcome = Outcome.expected_failure
        elseif outcome == Outcome.passed then
            outcome = Outcome.unexpected_pass
            table.insert(issues, {
                label = "expected_failure",
                message = test.expected_failure,
            })
        end
    end

    local result = Result.test(
        test_descriptor,
        outcome,
        duration_ns,
        issues
    )

    emit(sink, {
        kind = "test_finished",
        result = result,
    })

    return result
end

local function walk(suite, parent_path, sink, results)
    local suite_path = vim.list_extend(vim.deepcopy(parent_path), { suite.id })

    emit(sink, {
        kind = "suite_started",
        suite = {
            id = suite.id,
            path = table.concat(suite_path, "/"),
            title = suite.title or suite.id,
        },
    })

    for _, node in ipairs(suite.nodes) do
        if node.kind == "suite" then
            walk(node, suite_path, sink, results)
        else
            local test_path = vim.list_extend(
                vim.deepcopy(suite_path),
                { node.id }
            )
            table.insert(
                results,
                run_test(node, test_path, sink)
            )
        end
    end

    emit(sink, {
        kind = "suite_finished",
        suite = {
            id = suite.id,
            path = table.concat(suite_path, "/"),
            title = suite.title or suite.id,
        },
    })
end

function Runner.run(suite, options)
    options = options or {}

    local sink = options.sink
    local title = suite.title or suite.id
    local started = uv.hrtime()
    local results = {}

    emit(sink, {
        kind = "run_started",
        title = title,
        name_width = max_test_path_width(suite),
    })

    walk(suite, {}, sink, results)

    local run_result = Result.run(
        title,
        uv.hrtime() - started,
        results
    )

    emit(sink, {
        kind = "run_finished",
        result = run_result,
    })

    return run_result
end

return Runner
