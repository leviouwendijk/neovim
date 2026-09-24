local ANSI = require("interface.ansi")
local Outcome = require("testing.outcome")

local Reporter = {}
Reporter.__index = Reporter

local function format_duration(duration_ns)
    local milliseconds = duration_ns / 1000000
    if milliseconds < 1 then
        return string.format("%.3fms", milliseconds)
    end
    if milliseconds < 1000 then
        return string.format("%.1fms", milliseconds)
    end
    return string.format("%.2fs", milliseconds / 1000)
end

local function status_label(outcome, use_ansi)
    local label
    local codes

    if outcome == Outcome.passed then
        label = "PASS"
        codes = { ANSI.code.green, ANSI.code.bold }
    elseif outcome == Outcome.failed then
        label = "FAIL"
        codes = { ANSI.code.red, ANSI.code.bold }
    elseif outcome == Outcome.skipped then
        label = "SKIP"
        codes = { ANSI.code.yellow, ANSI.code.dim }
    elseif outcome == Outcome.expected_failure then
        label = "XFAIL"
        codes = { ANSI.code.yellow }
    elseif outcome == Outcome.unexpected_pass then
        label = "XPASS"
        codes = { ANSI.code.red, ANSI.code.bold }
    else
        label = "INT"
        codes = { ANSI.code.red, ANSI.code.bold }
    end

    local padded = string.format("%-5s", label)

    if not use_ansi then
        return padded
    end

    return ANSI.format(padded, unpack(codes))
end

local function write_line(text)
    io.stdout:write(text .. "\n")
    io.stdout:flush()
end

local function pad_right_display(text, width)
    text = tostring(text)
    local display_width = vim.fn.strdisplaywidth(text)

    if display_width >= width then
        return text
    end

    return text
        .. string.rep(" ", width - display_width)
end

local function render_issue(issue, use_ansi)
    local prefix = use_ansi
        and ANSI.format("      ", ANSI.code.dim)
        or "      "

    write_line(prefix .. (issue.message or tostring(issue)))

    if issue.label then
        write_line("        label:    " .. tostring(issue.label))
    end
    if issue.expected ~= nil then
        write_line("        expected: " .. tostring(issue.expected))
    end
    if issue.actual ~= nil then
        write_line("        actual:   " .. tostring(issue.actual))
    end
    if issue.location then
        write_line(string.format(
            "        at:       %s:%s",
            tostring(issue.location.source),
            tostring(issue.location.line)
        ))
    end
    if issue.traceback then
        write_line("        traceback:")
        for line in tostring(issue.traceback):gmatch("[^\n]+") do
            write_line("          " .. line)
        end
    end
end

function Reporter.new(options)
    options = options or {}

    return setmetatable({
        ansi = options.ansi ~= false,
        name_width = options.name_width,
        duration_width = options.duration_width or 8,
    }, Reporter)
end

function Reporter:receive(event)
    if event.kind == "run_started" then
        self.name_width =
            self.name_width
            or event.name_width
            or 0

        write_line(event.title)
        write_line("")
        return
    end

    if event.kind == "test_finished" then
        local result = event.result
        local name = result.test.path or result.test.id
        local status = status_label(result.outcome, self.ansi)
        local duration = format_duration(result.duration_ns)

        local padded_name = pad_right_display(
            name,
            self.name_width or 0
        )
        local padded_duration = string.format(
            "%" .. self.duration_width .. "s",
            duration
        )

        write_line(
            status
                .. " "
                .. padded_name
                .. " "
                .. padded_duration
        )

        if result.is_failure or result.outcome == Outcome.skipped then
            for _, issue in ipairs(result.issues) do
                render_issue(issue, self.ansi)
            end
        end
        return
    end

    if event.kind == "run_finished" then
        local result = event.result
        write_line("")
        write_line(string.format(
            "%d passed · %d failed · %d skipped · %d total · %s",
            result.passed_count,
            result.failure_count,
            result.skipped_count,
            result.total_count,
            format_duration(result.duration_ns)
        ))
    end
end

return Reporter
