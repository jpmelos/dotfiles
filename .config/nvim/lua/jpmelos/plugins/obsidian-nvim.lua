return {
    "epwalsh/obsidian.nvim",
    -- Use latest release instead of latest commit.
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "hrsh7th/nvim-cmp",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    opts = {
        workspaces = {
            {
                name = "second-brain",
                path = "~/second-brain",
            },
            {
                name = "second-brain-close",
                path = "~/second-brain-close",
            },
        },
        -- When using ':ObsidianOpen'.
        open_app_foreground = false,
        completion = {
            nvim_cmp = true,
            min_chars = 1,
        },
        mappings = {
            ["gf"] = {
                action = function()
                    return require("obsidian").util.gf_passthrough()
                end,
                opts = { noremap = false, expr = true, buffer = true },
            },
            ["<leader>ox"] = {
                action = function()
                    return require("obsidian").util.toggle_checkbox()
                end,
                opts = { buffer = true, desc = "Toggle checkbox" },
            },
            ["<leader>ot"] = {
                action = "<cmd>ObsidianToday<cr>",
                opts = { buffer = true, desc = "Open today's daily" },
            },
        },
        daily_notes = {
            folder = "00-dailies",
            date_format = "%Y-%m-%d",
            alias_format = "%Y-%m-%d",
            template = nil,
        },
        templates = {
            folder = "templates",
            date_format = "%Y-%m-%d",
            time_format = "%H:%M",
            -- A map for custom variables, the key should be the
            -- variable and the value a function
            substitutions = {},
        },
        note_id_func = function(title)
            if title ~= nil then
                return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-_]", "_"):lower()
            end

            local note_id = ""
            for _ = 1, 16 do
                note_id = note_id .. string.char(math.random(97, 122))
            end
            return note_id
        end,
        follow_url_func = function(url)
            if vim.loop.os_uname().sysname == "Darwin" then
                vim.fn.jobstart({ "open", url }) -- Mac OS
            else
                vim.notify(
                    "Fix this, make it specific for Linux in obsidian.nvim."
                )
                vim.fn.jobstart({ "xdg-open", url }) -- linux
            end
        end,
        picker = {
            name = "telescope.nvim",
            mappings = { insert_link = "<C-l>" },
        },
        ui = {
            enable = true,
            checkboxes = {
                [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
                ["x"] = { char = "", hl_group = "ObsidianDone" },
            },
            bullets = { char = "-", hl_group = "ObsidianBullet" },
            external_link_icon = {
                char = "",
                hl_group = "ObsidianExtLinkIcon",
            },
            reference_text = { hl_group = "ObsidianRefText" },
            highlight_text = { hl_group = "ObsidianHighlightText" },
            tags = { hl_group = "ObsidianTag" },
            block_ids = { hl_group = "ObsidianBlockID" },
            hl_groups = {
                ObsidianTodo = { bold = true, fg = "#f78c6c" },
                ObsidianDone = { bold = true, fg = "#89ddff" },
                ObsidianBullet = { bold = true },
                ObsidianExtLinkIcon = { fg = "#c792ea" },
                ObsidianRefText = { underline = true, fg = "#c792ea" },
                ObsidianHighlightText = { bg = "#75662e" },
                ObsidianTag = { italic = true, fg = "#89ddff" },
                ObsidianBlockID = { italic = true, fg = "#89ddff" },
            },
        },
    },
}
