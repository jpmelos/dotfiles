return {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local gs = require("gitsigns")

        gs.setup()

        -- Navigation.
        K("n", "]h", gs.next_hunk, { desc = "Next hunk" })
        K("n", "[h", gs.prev_hunk, { desc = "Prev hunk" })

        -- Actions.
        K("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
        K("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
        K("v", "<leader>hs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Stage hunk" })
        K("v", "<leader>hr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Reset hunk" })

        K("n", "<leader>hS", gs.stage_buffer, { desc = "Stage buffer" })
        K("n", "<leader>hR", gs.reset_buffer, { desc = "Reset buffer" })

        K("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })

        K("n", "<leader>hp", gs.preview_hunk, { desc = "Preview hunk" })

        K("n", "<leader>hd", gs.diffthis, { desc = "Diff this hunk" })
        K("n", "<leader>hD", function()
            gs.diffthis("~")
        end, { desc = "Diff this buffer" })
    end,
}
