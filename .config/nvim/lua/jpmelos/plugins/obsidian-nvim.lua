return {
    "epwalsh/obsidian.nvim",
    -- Use latest release instead of latest commit.
    dependencies = {
        "nvim-lua/plenary.nvim",
        "hrsh7th/nvim-cmp",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    config = function()
        local K = vim.keymap.set

        require("obsidian").setup({
            workspaces = {
                {
                    name = "second-brain",
                    path = "~/second-brain",
                },
            },
            -- When using ':ObsidianOpen'.
            open_app_foreground = false,
            completion = {
                nvim_cmp = true,
                min_chars = 1,
            },
            mappings = {},
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
                    return title
                        :gsub(" ", "-")
                        :gsub("[^A-Za-z0-9-_]", "_")
                        :lower()
                end

                local note_id = ""
                for _ = 1, 16 do
                    note_id = note_id .. string.char(math.random(97, 122))
                end
                return note_id
            end,
            follow_url_func = function(url)
                if vim.loop.os_uname().sysname == "Darwin" then
                    -- MacOS
                    vim.fn.jobstart({ "open", url })
                else
                    -- Linux
                    vim.notify(
                        "Fix this, make it specific for Linux in"
                            .. "obsidian.nvim."
                    )
                    vim.fn.jobstart({ "xdg-open", url }) -- linux
                end
            end,
            picker = {
                name = "telescope.nvim",
                mappings = { insert_link = "<C-l>" },
            },
            ui = {
                enable = false,
                -- checkboxes = {
                --     [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
                --     ["x"] = { char = "", hl_group = "ObsidianDone" },
                -- },
                -- bullets = { char = "-", hl_group = "ObsidianBullet" },
                -- external_link_icon = {
                --     char = "",
                --     hl_group = "ObsidianExtLinkIcon",
                -- },
                -- reference_text = { hl_group = "ObsidianRefText" },
                -- highlight_text = { hl_group = "ObsidianHighlightText" },
                -- tags = { hl_group = "ObsidianTag" },
                -- block_ids = { hl_group = "ObsidianBlockID" },
                -- hl_groups = {
                --     ObsidianTodo = { bold = true, fg = "#f78c6c" },
                --     ObsidianDone = { bold = true, fg = "#89ddff" },
                --     ObsidianBullet = { bold = true },
                --     ObsidianExtLinkIcon = { fg = "#c792ea" },
                --     ObsidianRefText = { underline = true, fg = "#c792ea" },
                --     ObsidianHighlightText = { bg = "#75662e" },
                --     ObsidianTag = { italic = true, fg = "#89ddff" },
                --     ObsidianBlockID = { italic = true, fg = "#89ddff" },
                -- },
            },
        })

        K("n", "gf", function()
            return require("obsidian").util.gf_passthrough()
        end, {
            noremap = false,
            expr = true,
            desc = "Follow link",
        })
        K("n", "<leader>ox", function()
            return require("obsidian").util.toggle_checkbox()
        end, { desc = "Toggle checkbox" })
        K(
            { "n", "v" },
            "<leader>on",
            "<cmd>ObsidianLinkNew<cr>",
            { desc = "Link to new note" }
        )
        K(
            "n",
            "<leader>ot",
            "<cmd>ObsidianToday<cr>",
            { desc = "Open today's daily" }
        )
    end,
}
