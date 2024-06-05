return {
    "rmagatti/goto-preview",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local goto_preview = require("goto-preview")

        goto_preview.setup()

        K(
            "n",
            "gpd",
            goto_preview.goto_preview_definition,
            { desc = "Preview LSP declaration" }
        )
        K(
            "n",
            "gpr",
            goto_preview.goto_preview_references,
            { desc = "Preview LSP references" }
        )
        K(
            "n",
            "gP",
            goto_preview.close_all_win,
            { desc = "Close all LSP previews" }
        )
    end,
}
