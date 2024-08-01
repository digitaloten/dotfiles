-- LSP settings.
--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
    -- NOTE: Remember that lua is a real programming language, and as such it is possible
    -- to define small helper and utility functions so you don"t have to repeat yourself
    -- many times.
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })

    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Goto definition" })
    vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, { desc = "Goto references" })
    vim.keymap.set("n", "gI", vim.lsp.buf.implementation, { desc = "Goto implementation" })
    vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, { desc = "Type definition" })
    vim.keymap.set("n", "<leader>ds", require("telescope.builtin").lsp_document_symbols, { desc = "Document symbols" })
    vim.keymap.set("n", "<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols,
        { desc = "Workspace symbols" })

    -- See `:help K` for why this keymap
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover Documentation" })
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature Documentation" })

    -- Lesser used LSP functionality
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Goto declaration" })
    vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, { desc = "Workspace add folder" })
    vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, { desc = "Workspace remove folder" })
    vim.keymap.set("n", "<leader>wl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, { desc = "Workspace list folders" })

    -- Format the current buffer with lsp
    vim.keymap.set("n", "<leader>F", function() vim.lsp.buf.format() end, { desc = "Format buffer" })
end

return { -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "j-hui/fidget.nvim",
        "folke/neodev.nvim", -- Additional lua configuration, makes nvim stuff amazing!
    },
    config = function()
        -- Enable the following language servers
        --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
        --
        --  Add any additional override configuration in the following tables. They will be passed to
        --  the `settings` field of the server config. You must look up that documentation yourself.
        local servers = {
            clangd = {},
            gopls = {},
            tsserver = {},
            pyright = {},
            rust_analyzer = {},
            intelephense = {},

            lua_ls = {
                Lua = {
                    workspace = { checkThirdParty = false },
                    telemetry = { enable = false },
                },
            },
        }

        -- Setup neovim lua configuration
        require("neodev").setup()

        -- nvim-cmp supports additional completion capabilities, so broadcast that to servers
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

        -- Setup mason so it can manage external tooling
        require("mason").setup()

        -- Ensure the servers above are installed
        local mason_lspconfig = require "mason-lspconfig"

        mason_lspconfig.setup {
            ensure_installed = vim.tbl_keys(servers),
        }

        mason_lspconfig.setup_handlers {
            function(server_name)
                require("lspconfig")[server_name].setup {
                    capabilities = capabilities,
                    on_attach = on_attach,
                    settings = servers[server_name],
                }
            end,
        }
    end
}
