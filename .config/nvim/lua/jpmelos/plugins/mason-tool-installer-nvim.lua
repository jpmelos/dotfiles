return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
        "williamboman/mason.nvim",
    },
    config = function()
        require("mason-tool-installer").setup({
            -- Install language servers with `mason-lspconfig.nvim` in
            -- `nvim-lspconfig` to ensure automatic configuration.
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
                -- tooling.
                -- clippy: Deprecated to install via Mason. Use Rust default
                -- tooling.
                -- CSS, SCSS, JS, TS, YAML, GraphQL.
                "prettier",
                -- JSON.
                "jq",
                -- TOML
                "taplo",
                -- Markdown.
                -- Install mdformat manually like below:
                -- uv tool install \
                --     --with mdformat-config \
                --     --with mdformat-ruff \
                --     --with mdformat-rustfmt \
                --     --with mdformat-shfmt \
                --     --with mdformat-web \
                --     --with mdformat-frontmatter \
                --     --with mdformat-gfm \
                --     --with mdformat-gfm-alerts \
                --     mdformat
            },
        })
    end,
}
