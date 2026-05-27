vim.cmd 'source ~/.vimrc-keys'

-- Save and exit with Ctrl+s
vim.api.nvim_set_keymap("i", "<C-s>", "<esc>:wq!<cr>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-s>", ":wq!<cr>", { noremap = true })
