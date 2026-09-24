local Suite = require("testing.suite")

return {
    test = Suite.test,
    suite = Suite.suite,
    expect = require("testing.expect"),
    fixture = require("testing.fixture"),
    outcome = require("testing.outcome"),
    diagnostic = require("testing.diagnostic"),
    result = require("testing.result"),
    runner = require("testing.runner"),
    reporter = require("testing.reporter"),
}
