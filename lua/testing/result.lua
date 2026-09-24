local Outcome = require("testing.outcome")

local Result = {}

local function count(results, predicate)
    local total = 0
    for _, item in ipairs(results) do
        if predicate(item) then
            total = total + 1
        end
    end
    return total
end

function Result.test(test, outcome, duration_ns, issues, diagnostics)
    return {
        test = test,
        outcome = outcome,
        duration_ns = duration_ns or 0,
        issues = issues or {},
        diagnostics = diagnostics or {},
        is_failure = Outcome.is_failure(outcome),
    }
end

function Result.run(title, duration_ns, results)
    local run = {
        title = title,
        duration_ns = duration_ns or 0,
        results = results or {},
    }

    run.failure_count = count(run.results, function(item)
        return item.is_failure
    end)

    run.passed_count = count(run.results, function(item)
        return item.outcome == Outcome.passed
            or item.outcome == Outcome.expected_failure
    end)

    run.skipped_count = count(run.results, function(item)
        return item.outcome == Outcome.skipped
    end)

    run.total_count = #run.results
    run.is_failure = run.failure_count > 0

    return run
end

return Result
