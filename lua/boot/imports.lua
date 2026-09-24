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

    interface = {
        { "ansi"        , "interface.ansi" },
        { "confirm"     , "interface.confirm" },
        { "checkhealth" , "interface.checkhealth" },
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
    },

    commands = {
        { "check_dependencies"     , "commands.check-dependencies" },
        { "ec_id"                  , "commands.ec-id" },
        { "ec_insert"              , "commands.ec-insert" },
        { "indentation"            , "commands.indentation" },
        { "output"                 , "commands.output" },
        { "shell"                  , "commands.shell" },
        { "workspace_diagnostics"  , "commands.workspace-diagnostics" },
    },

    integrations = {
        { "colorscheme"       , "interface.colorscheme" },
        { "indent_blankline"  , "integrations.indent-blankline" },
        { "limelight"         , "integrations.limelight" },
        { "notify"            , "integrations.notify" },
        { "scrollbar"         , "integrations.scrollbar" },
        { "statusline"        , "interface.statusline" },
        { "zen_mode"          , "integrations.zen-mode" },
        { "gitsigns"          , "integrations.gitsigns" },
        { "harpoon"           , "integrations.harpoon" },
        { "neoscroll"         , "integrations.neoscroll" },
        { "telescope"         , "integrations.telescope" },
        { "vim_commentary"    , "integrations.vim-commentary" },
        { "visimatch"         , "integrations.visimatch" },
        { "yanky"             , "integrations.yanky" },
        { "d2"                , "integrations.d2" },
        { "lsp"               , "integrations.lsp" },
        { "mason_tools"       , "integrations.mason-tools" },
        { "neorg"             , "integrations.neorg" },
        { "luasnip"           , "integrations.luasnip" },
        { "treesitter"        , "integrations.treesitter" },
    },

    testing = {
        { "init" , "testing" },
    }
}

return SystemConfiguration
