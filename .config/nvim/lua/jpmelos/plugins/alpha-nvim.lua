return {
    "goolord/alpha-nvim",
    lazy = false,
    config = function()
        local dashboard = require("alpha.themes.dashboard")

        dashboard.section.header.val = {
            "                                                     ",
            "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
            "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
            "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
            "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
            "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
            "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
            "                                                     ",
        }

        dashboard.section.buttons.val = {
            dashboard.button(
                "<Space>ee",
                "  > Toggle file explorer",
                "<cmd>NvimTreeToggle<CR>"
            ),
            dashboard.button(
                "<Space>ff",
                "󰱼  > Find file",
                "<cmd>Telescope find_files<CR>"
            ),
            dashboard.button(
                "<Space>fs",
                "  > Find word",
                "<cmd>Telescope live_grep<CR>"
            ),
            dashboard.button(
                "<Space>wr",
                "󰁯  > Restore session for directory",
                "<cmd>SessionRestore<CR>"
            ),
            dashboard.button(":q", "  > Quit", "<cmd>qa<CR>"),
        }

        require("alpha").setup(dashboard.opts)

        -- Disable folding in the Alpha buffer.
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "alpha",
            callback = function()
                vim.opt_local.foldenable = false
            end,
        })
    end,
}
