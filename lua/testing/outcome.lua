local Outcome = {
    passed = "passed",
    failed = "failed",
    skipped = "skipped",
    expected_failure = "expected_failure",
    unexpected_pass = "unexpected_pass",
    interrupted = "interrupted",
}

function Outcome.is_failure(outcome)
    return outcome == Outcome.failed
        or outcome == Outcome.unexpected_pass
        or outcome == Outcome.interrupted
end

return Outcome
