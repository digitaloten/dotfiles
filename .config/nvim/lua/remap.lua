-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<space>", "<nop>", { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", 'v:count == 0 ? "gk" : "k"', { expr = true, silent = true })
vim.keymap.set("n", "j", 'v:count == 0 ? "gj" : "j"', { expr = true, silent = true })

-- Mappings for tabs
vim.keymap.set("n", "<leader>k", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>j", "<cmd>tabprev<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>t", "<cmd>tabnew<cr>", { desc = "New tab" })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank()
    end,
    group = highlight_group,
    pattern = "*",
})

local vimgrep_arguments = { unpack(require("telescope.config").values.vimgrep_arguments) }
table.insert(vimgrep_arguments, "--hidden")
table.insert(vimgrep_arguments, "--glob")
table.insert(vimgrep_arguments, "!**/.git/*")

-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
require("telescope").setup {
    defaults = {
        vimgrep_arguments = vimgrep_arguments,
        mappings = {
            i = {
                ["<C-u>"] = false,
                ["<C-d>"] = false,
            },
        },
    },

    pickers = {
        find_files = {
            find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" }
        }
    }
}

-- Enable telescope fzf native, if installed
pcall(require("telescope").load_extension, "fzf")

-- See `:help telescope.builtin`
vim.keymap.set("n", "<leader>?", require("telescope.builtin").oldfiles, { desc = "Search recent files" })
vim.keymap.set("n", "<leader><space>", require("telescope.builtin").buffers, { desc = "Search buffers" })
vim.keymap.set("n", "<leader>/", function()
    -- You can pass additional configuration to telescope to change theme, layout, etc.
    require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown {
        winblend = 10,
        previewer = false,
    })
end, { desc = "Search current buffer" })

vim.keymap.set("n", "<leader>sf", require("telescope.builtin").find_files, { desc = "Search files" })
vim.keymap.set("n", "<leader>sh", require("telescope.builtin").help_tags, { desc = "Search help" })
vim.keymap.set("n", "<leader>sw", require("telescope.builtin").grep_string, { desc = "Search current word" })
vim.keymap.set("n", "<leader>sg", require("telescope.builtin").live_grep, { desc = "Search by grep" })
vim.keymap.set("n", "<leader>sd", require("telescope.builtin").diagnostics, { desc = "Search diagnostics" })

-- [[ Configure Treesitter ]]
-- See `:help nvim-treesitter`
require("nvim-treesitter.configs").setup {
    -- Add languages to be installed here that you want installed for treesitter
    ensure_installed = {
        "c",
        "cpp",
        "go",
        "lua",
        "python",
        "rust",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
    },

    -- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)
    auto_install = false,

    highlight = { enable = true },
    indent = { enable = true, disable = { "python" } },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = "<c-space>",
            node_incremental = "<c-space>",
            scope_incremental = "<c-s>",
            node_decremental = "<M-space>",
        },
    },
    textobjects = {
        select = {
            enable = true,
            lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["aa"] = "@parameter.outer",
                ["ia"] = "@parameter.inner",
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
            },
        },
        move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
                ["]m"] = "@function.outer",
                ["]]"] = "@class.outer",
            },
            goto_next_end = {
                ["]M"] = "@function.outer",
                ["]["] = "@class.outer",
            },
            goto_previous_start = {
                ["[m"] = "@function.outer",
                ["[["] = "@class.outer",
            },
            goto_previous_end = {
                ["[M"] = "@function.outer",
                ["[]"] = "@class.outer",
            },
        },
        swap = {
            enable = true,
            swap_next = {
                ["<leader>a"] = "@parameter.inner",
            },
            swap_previous = {
                ["<leader>A"] = "@parameter.inner",
            },
        },
    },
}

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- Dismiss Noice Notifications
vim.keymap.set("n", "<leader>m", "<cmd>NoiceDismiss<cr>", { desc = "Dismiss notifications" })

-- Toggle DBUI for DadBod
vim.keymap.set("n", "<leader>d", "<cmd>DBUIToggle<cr>", { desc = "Toggle database client" })

-- Git stuff
require('gitsigns').setup {
    on_attach = function()
        local gitsigns = require('gitsigns')

        -- Navigation
        vim.keymap.set('n', ']c', function()
            if vim.wo.diff then
                vim.cmd.normal({ ']c', bang = true })
            else
                gitsigns.nav_hunk('next')
            end
        end)

        vim.keymap.set('n', '[c', function()
            if vim.wo.diff then
                vim.cmd.normal({ '[c', bang = true })
            else
                gitsigns.nav_hunk('prev')
            end
        end)

        -- Actions
        vim.keymap.set('n', '<leader>gr', gitsigns.reset_hunk, { desc = "Git reset hunk" })
        vim.keymap.set('v', '<leader>gr', function() gitsigns.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
            { desc = "Git reset hunk" })
        vim.keymap.set('n', '<leader>gs', gitsigns.stage_hunk, { desc = "Git stage hunk" })
        vim.keymap.set('v', '<leader>gs', function() gitsigns.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
            { desc = "Git stage hunk" })
        vim.keymap.set('n', '<leader>gS', gitsigns.stage_buffer, { desc = "Git stage buffer" })
        vim.keymap.set('n', '<leader>gR', gitsigns.reset_buffer, { desc = "Git reset buffer" })
        vim.keymap.set('n', '<leader>gp', gitsigns.preview_hunk, { desc = "Git preview hunk" })
        vim.keymap.set('n', '<leader>gb', gitsigns.blame, { desc = "Git blame" })
        vim.keymap.set('n', '<leader>gd', gitsigns.diffthis, { desc = "Git diff" })
        vim.keymap.set('n', '<leader>gD', function() gitsigns.diffthis('~') end, { desc = "Git diff full" })
        vim.keymap.set('n', '<leader>gtb', gitsigns.toggle_current_line_blame, { desc = "Git toggle blame line" })
        vim.keymap.set('n', '<leader>gtd', gitsigns.toggle_deleted, { desc = "Git toggle delete" })

        -- Text object
        vim.keymap.set({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')

        -- Add commit hook
        vim.keymap.set("n", "<leader>gc", "<cmd>Git commit<cr>", { desc = "Git commit" })
    end
}
