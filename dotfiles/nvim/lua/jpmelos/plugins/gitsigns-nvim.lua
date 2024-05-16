return {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local gs = require("gitsigns")

        gs.setup()

        -- Navigation.
        K("n", "]g", gs.next_hunk, { desc = "Next hunk" })
        K("n", "[g", gs.prev_hunk, { desc = "Previous hunk" })

        -- Actions.
        K("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
        K("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
        K("v", "<leader>gs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Stage hunk" })
        K("v", "<leader>gr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Reset hunk" })

        K("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
        K("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })

        K("n", "<leader>gu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })

        K("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })

        K("n", "<leader>gd", gs.diffthis, { desc = "Diff this hunk" })
        K("n", "<leader>gD", function()
            gs.diffthis("~")
        end, { desc = "Diff this buffer" })
    end,
}
