local SystemConfiguration = {
    config = {
        { "funcs"    ,  "config.funcs" },
        { "set"      ,  "config.set" },
        { "remap"    ,  "config.remap" },
        { "defaults" ,  "config.defaults" },
        { "path"     ,  "config.path" },
    },

    packages = {
        -- { "packer" ,  "packages.packer" }
        { "packer" ,  "packages.pack" }
    },

    core = {
        { "trash"    ,  "core.trash" },
        { "log"      ,  "core.log" },
        { "confirm"  ,  "core.confirm" },
        { "filetype" ,  "core.filetype" },
        { "treesitter" ,  "core.treesitter" },
    },

    customizations = {
        { "writing"       ,  "customizations.writing" },
        { "statusline"    ,  "customizations.statusline" },
    },

    extensions = {
        { "highlight_yank"   ,  "extensions.highlight-yank" },
        { "uuid"             ,  "extensions.uuid" },
        { "ssh_clipboard"    ,  "extensions.ssh-clipboard" },
        { "stf"              ,  "extensions.stf" },
        { "file_rename"      ,  "extensions.file-rename" },
        { "filemover"        ,  "extensions.filemover" },
        { "copier_api"       ,  "extensions.copier-api" },
        { "mess"             ,  "extensions.mess" },
        { "ec_id"            ,  "extensions.ec-id" },
        { "ec_template"      ,  "extensions.ec-template" },
        { "reusable_library" ,  "extensions.reusable-library" },
        { "last_file"        ,  "extensions.last-file" },
        { "weasyprint"       ,  "extensions.weasyprint" },
        { "indentation"      ,  "extensions.indentation" },
        { "output"           ,  "extensions.output" },
        { "nicetstamp"       ,  "extensions.nicetstamp" },
        { "niceheader"       ,  "extensions.niceheader" },
        { "shell"            ,  "extensions.shell" },
        { "bedrocks"         ,  "extensions.bedrocks" },
        { "bedrocks_depth"   ,  "extensions.bedrocks-depth" },
    },

    utils = {
        { "notify"           ,  "utils.notify" },
        { "json"             ,  "utils.json" },
        { "branch"           ,  "utils.branch" },
        { "chmod"            ,  "utils.chmod" },
        { "format"           ,  "utils.format" },
        { "shebang"          ,  "utils.shebang" },
        { "vat"              ,  "utils.vat" },
        { "word_count"       ,  "utils.word-count" },
        { "copy_messages"    ,  "utils.copy-messages" },
        { "swift_init"       ,  "utils.swift-initializer" },
        { "appearance"       ,  "utils.appearance" },
        { "enter"            ,  "utils.enter" },
        { "align"            ,  "utils.align" },
        { "timestamp"        ,  "utils.timestamp" },
        { "project_progress" ,  "utils.project-progress" },
        { "casecon"          ,  "utils.casecon" },
        { "dependencies"     ,  "utils.dependencies" },
    }
}

return SystemConfiguration
