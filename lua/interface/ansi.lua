local ANSI = {}

local ESC = "\27["

ANSI.enabled = vim.env.NO_COLOR == nil

ANSI.code = {
    reset = ESC .. "0m",

    bold = ESC .. "1m",
    dim = ESC .. "2m",
    italic = ESC .. "3m",
    underline = ESC .. "4m",
    blink = ESC .. "5m",
    inverse = ESC .. "7m",
    hidden = ESC .. "8m",
    strikethrough = ESC .. "9m",

    black = ESC .. "30m",
    red = ESC .. "31m",
    green = ESC .. "32m",
    yellow = ESC .. "33m",
    blue = ESC .. "34m",
    magenta = ESC .. "35m",
    cyan = ESC .. "36m",
    white = ESC .. "37m",
    default_text = ESC .. "39m",

    bright_black = ESC .. "90m",
    bright_red = ESC .. "91m",
    bright_green = ESC .. "92m",
    bright_yellow = ESC .. "93m",
    bright_blue = ESC .. "94m",
    bright_magenta = ESC .. "95m",
    bright_cyan = ESC .. "96m",
    bright_white = ESC .. "97m",

    black_background = ESC .. "40m",
    red_background = ESC .. "41m",
    green_background = ESC .. "42m",
    yellow_background = ESC .. "43m",
    blue_background = ESC .. "44m",
    magenta_background = ESC .. "45m",
    cyan_background = ESC .. "46m",
    white_background = ESC .. "47m",
    default_background = ESC .. "49m",

    bright_black_background = ESC .. "100m",
    bright_red_background = ESC .. "101m",
    bright_green_background = ESC .. "102m",
    bright_yellow_background = ESC .. "103m",
    bright_blue_background = ESC .. "104m",
    bright_magenta_background = ESC .. "105m",
    bright_cyan_background = ESC .. "106m",
    bright_white_background = ESC .. "107m",
}

function ANSI.rgb(r, g, b, background)
    local prefix = background and "48" or "38"
    return string.format("\27[%s;2;%d;%d;%dm", prefix, r, g, b)
end

function ANSI.format(text, ...)
    if not ANSI.enabled then
        return tostring(text)
    end

    local codes = { ... }
    return table.concat(codes) .. tostring(text) .. ANSI.code.reset
end

function ANSI.link(url, label, terminator)
    if not ANSI.enabled then
        return label or url
    end

    terminator = terminator or "\7"
    local start = "\27]8;;" .. url .. terminator
    local finish = "\27]8;;" .. terminator
    return start .. (label or url) .. finish
end

function ANSI.strip(text)
    return tostring(text):gsub("\27%[[0-9;]*[A-Za-z]", "")
end

return ANSI
