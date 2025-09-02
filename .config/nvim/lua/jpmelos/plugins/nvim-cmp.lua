return {
    "hrsh7th/nvim-cmp",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "kristijanhusak/vim-dadbod-completion",
        "folke/lazydev.nvim",
        "onsails/lspkind.nvim",
        "L3MON4D3/LuaSnip",
    },
    config = function()
        local cmp = require("cmp")

        cmp.setup({
            completion = { completeopt = "menu,menuone,preview,noselect" },
            -- Configure the snippet engine. This is required, otherwise
            -- `nvim-cmp` may show weird behavior.
            snippet = {
                expand = function(args)
                    require("luasnip").lsp_expand(args.body)
                end,
            },
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            },
            mapping = cmp.mapping.preset.insert({
                -- Trigger the suggestions modal.
                ["<C-Space>"] = cmp.mapping.complete(),
                -- Next suggestion.
                ["<Tab>"] = cmp.mapping.select_next_item(),
                -- Previous suggestion.
                ["<S-Tab>"] = cmp.mapping.select_prev_item(),
                -- Scroll documentation pane up.
                ["<C-f>"] = cmp.mapping.scroll_docs(-4),
                -- Scroll documentation pane down.
                ["<C-b>"] = cmp.mapping.scroll_docs(4),
                -- Close suggestions modal.
                ["<C-c>"] = cmp.mapping.abort(),
                -- Insert suggestion.
                ["<CR>"] = cmp.mapping.confirm(),
            }),
            -- Sources for autocompletion.
            sources = cmp.config.sources({
                { name = "nvim_lsp" },
                { name = "buffer" },
                { name = "path", option = { trailing_slash = true } },
                { name = "vim-dadbod-completion" },
                { name = "lazydev" },
            }),
            -- Configure pictograms from `onsails/lspkind.nvim`.
            formatting = {
                fields = { "abbr", "kind" },
                format = require("lspkind").cmp_format({
                    before = function(entry, vim_item)
                        local item = entry:get_completion_item()
                        if item.insertTextFormat == 2 then
                            item.insertTextFormat = 1
                            item.textEdit.newText =
                                entry:get_completion_item().filterText
                        end
                        return vim_item
                    end,
                }),
            },
        })

        -- SQL specific completion.
        cmp.setup.filetype({ "sql" }, {
            sources = {
                { name = "vim-dadbod-completion" },
                { name = "buffer" },
            },
        })
    end,
}
