local workspaces =
    { { name = "second-brain", path = "~/devel/second-brain" } }

return {
    "obsidian-nvim/obsidian.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "hrsh7th/nvim-cmp",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
        "iamcco/markdown-preview.nvim",
    },
    -- Only load when we are in one of the defined workspaces.
    cond = function()
        local cwd = vim.fn.getcwd()

        for _, workspace in ipairs(workspaces) do
            local expanded_path = vim.fn.expand(workspace.path)
            if cwd == expanded_path then
                return true
            end
        end

        return false
    end,
    config = function()
        local K = vim.keymap.set

        local obsidian = require("obsidian")

        local default_template_name = "default"

        -- Help the Markdown previewer find our images.
        local cwd = vim.fn.getcwd()
        vim.g.mkdp_images_path = cwd .. "/01-assets/imgs"

        obsidian.setup({
            legacy_commands = false,
            ui = { enable = false },
            statusline = { enabled = false },
            footer = { enabled = false },

            workspaces = workspaces,
            preferred_link_style = "markdown",

            templates = {
                folder = "00-templates",
                date_format = "%Y-%m-%d",
                time_format = "%H:%M",
                -- A map for custom variables, the key should be the
                -- variable and the value a function
                substitutions = {},
            },
            attachments = {
                img_folder = "01-assets/imgs",
                img_name_func = function()
                    return string.format(
                        "%s-%s",
                        os.date("%Y-%m-%d-%H-%M-%S"),
                        RandomAlphaNumericString(6)
                    )
                end,
                confirm_img_paste = false,
            },
            daily_notes = {
                folder = "02-dailies",
                date_format = "%Y-%m-%d",
                template = "daily-note.md",
                default_tags = { "daily-note" },
                workdays_only = false,
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

            picker = {
                name = "telescope.nvim",
                mappings = { insert_link = "<C-l>" },
            },

            checkbox = {
                enabled = true,
                create_new = true,
                order = { " ", "x" },
            },

            callbacks = {
                pre_write_note = function(note)
                    local templates_dir = obsidian.api.templates_dir()
                    if not templates_dir then
                        -- No templates defined, nothing to do here.
                        return
                    end

                    local ok = pcall(
                        obsidian.templates.resolve_template,
                        default_template_name,
                        templates_dir
                    )
                    if not ok then
                        -- The default template doesn't exist, nothing to do
                        -- here.
                        return
                    end

                    local buf = vim.api.nvim_get_current_buf()
                    local lines =
                        vim.api.nvim_buf_get_lines(buf, 0, -1, false)

                    -- Detect frontmatter boundaries.
                    local frontmatter_end = 0
                    if
                        #lines > 0
                        and (lines[1] == "---" or lines[1] == "+++")
                    then
                        local frontmatter_delimiter = lines[1]
                        for i = 2, #lines do
                            if lines[i] == frontmatter_delimiter then
                                frontmatter_end = i
                                break
                            end
                        end
                    end

                    -- Check if content after frontmatter is empty.
                    local is_empty = true
                    for i = frontmatter_end + 1, #lines do
                        if lines[i] ~= "" then
                            is_empty = false
                            break
                        end
                    end

                    if is_empty then
                        -- Determine insertion line (after frontmatter).
                        local insert_line = frontmatter_end + 1

                        -- If there's frontmatter, delete everything after
                        -- it (including any empty lines), add exactly one
                        -- empty line, and insert template after that.
                        if frontmatter_end > 0 then
                            vim.api.nvim_buf_set_lines(
                                buf,
                                frontmatter_end,
                                -1,
                                false,
                                { "" }
                            )
                            -- Insert after the empty line we just added.
                            insert_line = frontmatter_end + 2
                        end

                        obsidian.templates.insert_template({
                            template_name = default_template_name,
                            templates_dir = templates_dir,
                            template_opts = Obsidian.opts.templates,
                            location = {
                                buf,
                                vim.api.nvim_get_current_win(),
                                insert_line,
                                0,
                            },
                            partial_note = note,
                        })
                    end
                end,
            },
        })

        vim.api.nvim_create_autocmd("User", {
            pattern = "ObsidianNoteEnter",
            command = "MarkdownPreview",
        })

        K(
            "n",
            "<leader>on",
            "<cmd>Obsidian new<cr>",
            { desc = "Open new note" }
        )
        K(
            "n",
            "<leader>ot",
            "<cmd>Obsidian new_from_template<cr>",
            { desc = "Open new note from template" }
        )
        K(
            "n",
            "<leader>od",
            "<cmd>Obsidian today<cr>",
            { desc = "Open today's daily note" }
        )
        K(
            "n",
            "<leader>oi",
            "<cmd>Obsidian paste_img<cr>",
            { desc = "Paste image from clipboard" }
        )
    end,
}
