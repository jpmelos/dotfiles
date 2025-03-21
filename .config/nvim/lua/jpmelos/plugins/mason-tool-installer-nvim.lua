return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
        "williamboman/mason.nvim",
    },
    config = function()
        require("mason-tool-installer").setup({
            -- Install language servers with `mason-lspconfig.nvim` to
            -- ensure automatic configuration.
            ensure_installed = {
                -- bash
                -- shellcheck: Not explicitly referenced in these dotfiles, but
                -- it's used by `bashls` to provide some of its
                -- functionalities.
                "shellcheck",
                "shfmt",
                -- Python
                "ruff",
                -- Lua
                "stylua",
                -- Rust
                -- rustfmt: Deprecated to install via Mason. Use Rust default
                -- tools.
                -- SQL
                -- Still deciding what to use here.
                -- CSS, SCSS, JS, TS, YAML, GraphQL.
                "prettier",
                -- JSON.
                "jq",
                -- Markdown.
                -- Install mdformat manually like below:
                -- pipx install mdformat
                -- pipx inject mdformat \
                --     mdformat-config \
                --     mdformat-ruff \
                --     mdformat-rustfmt \
                --     mdformat-shfmt \
                --     mdformat-web \
                --     mdformat-frontmatter \
                --     mdformat-gfm \
                --     mdformat-gfm-alerts \
                --     mdformat-tables
            },
        })
    end,
}
