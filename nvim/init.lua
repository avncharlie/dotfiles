--  ______                    _   _       _     
-- |  ____|                  | | (_)     | |    
-- | |__   ___ ___  ___ _ __ | |_ _  __ _| |___ 
-- |  __| / __/ __|/ _ \ '_ \| __| |/ _` | / __|
-- | |____\__ \__ \  __/ | | | |_| | (_| | \__ \
-- |______|___/___/\___|_| |_|\__|_|\__,_|_|___/

vim.g.mapleader = ','               -- map leader to comma
vim.opt.expandtab = true            -- expand all tabs to spaces
vim.opt.shiftwidth = 4              -- how many spaces to indent code by
vim.opt.tabstop = 4                 -- show tabs as spaces
vim.opt.ic = true                   -- ignore case while searching
vim.opt.incsearch = true            -- search after every keystroke
vim.opt.spell.spelllang = "en_au"   -- language to spell check in
vim.opt.spell = false               -- by default don't spell check
vim.opt.showcmd = true              -- show commands used vim
vim.opt.scrolloff = 5               -- keep cursor five lines from bottom
vim.opt.clipboard = 'unnamedplus'   -- yank everything into system clipboard
vim.opt.number = true               -- turn on line numbers
vim.opt.mouse = 'a'                 -- mouse support
vim.g.netrw_liststyle = 3           -- default netrw in tree mode
vim.opt.hidden = true               -- switch buffers without saving
vim.opt.hlsearch = true             -- highlight every match while searching
vim.opt.signcolumn = 'yes'          -- minimise window movement with diagnostics
vim.termguicolors = true
vim.cmd(                            -- true colour support
[[
let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
set termguicolors
]])
vim.cmd(                            -- mouse support within tmux
[[
if &term =~ '^screen'
    set ttymouse=xterm2
endif
]])
-- move vertically by visual line
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')
-- C-l to hide search highlighting
vim.keymap.set('n', '<C-L>', ':nohl<CR>', {silent = true})
-- map ' to search back (as , is taken by leader)
vim.keymap.set('n', "'", ',')
-- handle buffers
vim.keymap.set('n', "gn", ':bn<CR>')
vim.keymap.set('n', "gp", ':bp<CR>')
vim.keymap.set('n', "gx", ':bd<CR>')
-- move around quickfix list
vim.keymap.set('n', "]q", ':cn<CR>', { desc = 'Go to next quickfix' })
vim.keymap.set('n', "[q", ':cp<CR>', { desc = 'Go to previous quickfix' })
-- decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300
-- remember folds
vim.cmd([[
augroup remember_folds
  autocmd!
  au BufWinLeave ?* mkview 1
  au BufWinEnter ?* execute 'normal! zX' | silent! loadview 1
augroup END
]])

--  _____  _             _
-- |  __ \| |           (_)
-- | |__) | |_   _  __ _ _ _ __  ___
-- |  ___/| | | | |/ _` | | '_ \/ __|
-- | |    | | |_| | (_| | | | | \__ \
-- |_|    |_|\__,_|\__, |_|_| |_|___/
--                  __/ |
--                 |___/

-- use lazy.nvim as package manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  -- detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- undo analyser (c-y)
  'simnalamburt/vim-mundo',

  -- easy surround
  'tpope/vim-surround',

  -- file sidebar
  'nvim-tree/nvim-tree.lua',
  'nvim-tree/nvim-web-devicons',

  -- lsp config
  'neovim/nvim-lspconfig',
  -- show LSP progress messages
  -- { 'j-hui/fidget.nvim', opts = {} },
  -- make lsp renames / codeactions look nice
  { 'stevearc/dressing.nvim', opts = {}, },

  -- completion
  'hrsh7th/cmp-cmdline',
  'hrsh7th/cmp-path',
  'hrsh7th/nvim-cmp',
  'hrsh7th/cmp-nvim-lsp',
  'saadparwaiz1/cmp_luasnip',
  'L3MON4D3/LuaSnip',
  'hrsh7th/cmp-buffer',
  -- lsp-integrated completion menu
  'onsails/lspkind.nvim',

  -- treesitter
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate', },
  'nvim-treesitter/nvim-treesitter-textobjects',

  -- onedark colorscheme
  {
    'navarasu/onedark.nvim',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'onedark'
    end,
  },

  -- indentation guides
  --{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },

  -- vim + tmux integration
  {
    'christoomey/vim-tmux-navigator',
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
  },

  -- "<c-\>" to comment visual regions/lines
  'numToStr/Comment.nvim',
  -- nvim 0.10 will have this default

  -- fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'Theo-Steiner/togglescope',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
    },
  },

  -- show buffers in tabline
  'ap/vim-buftabline',

  -- fuzzy finder
  'ggandor/leap.nvim',

  -- {
  --   "jackMort/ChatGPT.nvim",
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "nvim-telescope/telescope.nvim"
  --   }
  -- }

  {
    "robitx/gp.nvim",
    config = function()

      local system_prompt = "You are a AI assisting a programmer. Be succint."
      local conf = {
        providers = {
          openai = {
            endpoint = "https://api.openai.com/v1/chat/completions",
            secret = { "cat", "/Users/alvin/.openAIKey" },
          },
        },
        agents = {
          {
            provider = "openai", name = "ChatGPT4o", chat = true, command = true,
            model = { model = "gpt-4o", temperature = 0.8, top_p = 1 },
            system_prompt = system_prompt
          },
          {
            provider = "openai", name = "CodeGPT4o", chat = true, command = true,
            model = { model = "gpt-4o", temperature = 0.8, top_p = 1 },
            system_prompt = system_prompt
          },
        },
        chat_user_prefix = "Prompt:",
        chat_assistant_prefix = { "ChatGPT: ", "[{{agent}}]" },
        chat_template = require("gp.defaults").short_chat_template,
        chat_confirm_delete = false,
        hooks = {
          Explain = function(gp, params)
            local template = "I have the following code from {{filename}}:\n\n"
              .. "```{{filetype}}\n{{selection}}\n```\n\n"
              .. "Please respond by explaining the code above."
            local agent = gp.get_chat_agent()
            gp.Prompt(params, gp.Target.popup, agent, template)
          end,
        }
      }
      require("gp").setup(conf)
    end,
  }
})

vim.keymap.set({"n", "i"}, "<C-g>c", "<cmd>GpChatNew<cr>")
vim.keymap.set("v", "<C-g>c", ":<C-u>'<,'>GpChatNew<cr>")
vim.keymap.set({"n", "i"}, "<C-g>f", "<cmd>GpChatFinder<cr>")
vim.keymap.set("v", "<C-g>e", ":<C-u>'<,'>GpExplain<cr>")

-- easy commenting 
require('Comment').setup {
  opleader = {
    line = '<C-\\>',
  },
  toggler = {
    line = '<C-\\>',
  },
}

-- tmux navigator bindings
vim.keymap.set('n', '<C-b>h', ':TmuxNavigateLeft<cr>', {silent = true})
vim.keymap.set('n', '<C-b>j', ':TmuxNavigateDown<cr>', {silent = true})
vim.keymap.set('n', '<C-b>k', ':TmuxNavigateUp<cr>', {silent = true})
vim.keymap.set('n', '<C-b>l', ':TmuxNavigateRight<cr>', {silent = true})

-- colorscheme config
require('onedark').setup  {
  style = 'dark',
  code_style = {
    comments = 'none',
  },
}
require('onedark').load()

-- nvim-tree config
-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
require("nvim-tree").setup()
-- Control n n to toggle
vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>')

-- lsp configuration
local lspconfig = require('lspconfig')
-- setup up lsps + extra capabilities for completion
-- to add new lsp: see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
--                 and https://github.com/williamboman/mason-lspconfig.nvim/blob/main/doc/server-mapping.md
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local servers = {
  'jdtls',
  'clangd',
  'pyright',
  'tsserver',
  'ocamllsp',
  'rust_analyzer',
  -- pylsp (used for pylint, setup is below)
}
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    capabilities = capabilities,
  }
end
-- special setup for pylsp. only used for pylint. there really should be a way
-- to plug in pylint directly instead of through pylsp
lspconfig.pylsp.setup {
  enable = true,
  -- disable several capabilities in favor of pyright
  -- specifically the hover messes with pyright's hover
  -- but only using pylint for python docstring linting so the other
  -- capabilities aren't needed either.
  on_attach = function (client, buffer)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.hoverProvider = false
      client.server_capabilities.renameProvider = false
  end,
  settings = {
  pylsp = {
    plugins = {
      pyflakes = { enabled = false },
      pycodestyle = { enabled = false },
      mccabe = { enabled = false },
      pylint = { enabled = true },
      },
    },
  },
}

-- diagnostics
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<c-x>', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setqflist, { desc = 'Open diagnostics list' })
-- keymaps
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    local lspmap = function(keys, func, desc)
      if desc then
        desc = 'LSP: ' .. desc
      end
      vim.keymap.set('n', keys, func, { buffer = ev.buf, desc = desc })
    end
    -- actions
    lspmap('<leader>rr', vim.lsp.buf.rename, 'Rename')
    lspmap('<leader>ca', vim.lsp.buf.code_action, 'Code Action')
    -- useful
    lspmap('K', vim.lsp.buf.hover, 'Hover Documentation')
    lspmap('gd', vim.lsp.buf.definition, 'Goto Definition')
    -- lspmap('gr', vim.lsp.buf.references, 'Goto References') -- (using telescope find references instead)
    -- less used
    lspmap('<C-k>', vim.lsp.buf.signature_help, 'Hover Signature Documentation')
    lspmap('gD', vim.lsp.buf.declaration, 'Goto Declaration')
    lspmap('gi', vim.lsp.buf.implementation, 'Goto Implementation')
    lspmap('<leader>D', vim.lsp.buf.type_definition, 'Goto Type Definition')
    -- code format with :Format
    vim.api.nvim_buf_create_user_command(ev.buf, 'Format', function(opts)
      if opts.range ~= 0 then
        local start_row, _ = unpack(vim.api.nvim_buf_get_mark(0, "<"))
        local end_row, _ = unpack(vim.api.nvim_buf_get_mark(0, ">"))
        vim.lsp.buf.format({
            range = {
                ["start"] = { start_row, 0 },
                ["end"] = { end_row, 0 },
            },
            async = true,
        })
      else 
        vim.lsp.buf.format()
      end
    end, { desc = 'Format current buffer with LSP', range = true })
  end,
})
-- turn off diagnostics
vim.diagnostic.config({virtual_text = false})

-- use internal formatting for bindings like gq. 
-- (otherwise gq doesn't work in docstrings)
vim.api.nvim_create_autocmd('LspAttach', { 
 callback = function(args) 
   vim.bo[args.buf].formatexpr = nil 
 end, 
})

-- completion config
vim.opt.completeopt = {'menu', 'menuone', 'noselect'}
local cmp = require 'cmp'
local luasnip = require 'luasnip'
local lspkind = require('lspkind')
cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-u>'] = cmp.mapping.scroll_docs(-4), -- Up
    ['<C-d>'] = cmp.mapping.scroll_docs(4), -- Down
    -- C-b (back) C-f (forward) for snippet placeholder navigation.
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  }),
  formatting = {
    format = lspkind.cmp_format(),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'path' },
    { name = 'buffer' }
  },
}
-- completion for searching '/' and commands ':'
cmp.setup.cmdline('/', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    {
      name = 'cmdline',
      option = {
        ignore_cmds = { 'Man', '!' }
      },
      keyword_length = 2
    }
  })
})

-- treesitter config
require'nvim-treesitter.configs'.setup {
  ensure_installed = "all",
  auto_install = true,
  highlight = {
    enable = true,
  },
  -- smart select
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<cr>',
      node_incremental = '<cr>',
      scope_incremental = '<c-space>',
      node_decremental = '<tab>',
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ['aa'] = '@parameter.outer',
        ['ia'] = '@parameter.inner',
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        [']]'] = '@function.outer',
        [']c'] = '@class.outer',
      },
      goto_next_end = {
        [']M'] = '@function.outer',
        [']C'] = '@class.outer',
      },
      goto_previous_start = {
        ['[['] = '@function.outer',
        ['[c'] = '@class.outer',
      },
      goto_previous_end = {
        ['[M'] = '@function.outer',
        ['[C'] = '@class.outer',
      },
      goto_next = {
        ["]i"] = "@conditional.outer",
      },
      goto_previous = {
        ["[i"] = "@conditional.outer",
      }
    },
    swap = {
      enable = true,
      swap_next = {
        ['<leader>a'] = '@parameter.inner',
      },
      swap_previous = {
        ['<leader>A'] = '@parameter.inner',
      },
    },
  },
}
-- folding with treesitter
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99

-- telescope settings
require('telescope').setup {
  defaults = {
    file_ignore_patterns = { "^.git/" },
    mappings = {
      i = {
        ['<C-n>'] = false,
        ['<C-p>'] = false,
        ['<C-j>'] = {
          require('telescope.actions').move_selection_next, type = "action",
          opts = { nowait = true, silent = true },
        },
        ['<C-k>'] = {
          require('telescope.actions').move_selection_previous, type = "action",
          opts = { nowait = true, silent = true },
        }
      },
    },
  },
  extensions = {
    -- toggle searching hidden files with c-h
    togglescope = {
      find_files = { 
        ['<c-h>'] = {
          hidden = true,
          no_ignore = true,
          togglescope_title = "Find Files (hidden)"
        }
      },
      live_grep = {
        ['<c-h>'] = {
          additional_args = {
            '--hidden',
            '--no-ignore',
          },
          togglescope_title = "Live Grep (hidden)"
        }
      }
    }
  },
}
pcall(require('telescope').load_extension, 'fzf')

local function telescope_live_grep_open_files()
  require('telescope.builtin').live_grep {
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  }
end
local function telescope_current_buffer_find()
  require('telescope.builtin').current_buffer_fuzzy_find({
    -- previewer = false,
  })
end
vim.keymap.set('n', '<leader>sk', require('telescope.builtin').keymaps, { desc = 'Telescope: Search keymaps' })
vim.keymap.set('n', '<leader>s/', telescope_live_grep_open_files, { desc = 'Telescope: Search in Open Buffers/Files' })
vim.keymap.set('n', 'gr', require('telescope.builtin').lsp_references, { desc = 'Telescope: Find References' })
vim.keymap.set('n', '<c-r>', require('telescope.builtin').resume, { desc = 'Telescope: Resume Search' })
vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = 'Telescope: Search Diagnostics' })
vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = 'Telescope: Fuzzy search current file' })
vim.keymap.set('n', '<leader>S', require('telescope.builtin').lsp_document_symbols, { desc = 'Telescope: Search Symbols in file' })
vim.keymap.set('n', '<leader>ss', require('telescope.builtin').lsp_dynamic_workspace_symbols, { desc = 'Telescope: Search Symbols in workspace' })
vim.keymap.set('n', '<c-f>', require('telescope').extensions.togglescope.find_files, { desc = 'Telescope: Find files' })
vim.keymap.set('n', '<leader>f', require('telescope').extensions.togglescope.live_grep, { desc = 'Telescope: Search string in Workspace' })
vim.keymap.set('n', '<leader><space>', require('telescope.builtin').buffers, { desc = 'Telescope: View open buffers' })
vim.keymap.set('n', '<leader>/', telescope_current_buffer_find, { desc = 'Telescope: Search in current buffer' })

-- function to find the git root directory based on the current buffer's path
local function find_git_root()
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir
  local cwd = vim.fn.getcwd()
  if current_file == '' then
    current_dir = cwd
  else
    current_dir = vim.fn.fnamemodify(current_file, ':h')
  end
  local git_root = vim.fn.systemlist('git -C ' .. vim.fn.escape(current_dir, ' ') .. ' rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 then
    print 'Not a git repository. Searching on current working directory'
    return cwd
  end
  return git_root
end
local function telescope_find_in_git_root()
  local git_root = find_git_root()
  print("hi!")
  if git_root then
    require('telescope.builtin').live_grep {
      search_dirs = { git_root },
      prompt_title = 'Search',
      vimgrep_arguments = {
        'rg',
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
        '--smart-case',
        '-u'
      },
    }
  end
end
vim.api.nvim_create_user_command('FindInGitRoot', telescope_find_in_git_root, {})

-- leap
-- keybindings: s and S
require('leap').create_default_mappings()

--  _______                _
-- |__   __|              | |
--    | | ___   __ _  __ _| | ___  ___
--    | |/ _ \ / _` |/ _` | |/ _ \/ __|
--    | | (_) | (_| | (_| | |  __/\__ \
--    |_|\___/ \__, |\__, |_|\___||___/
--              __/ | __/ |
--             |___/ |___/

-- toggle quickfix
local function toggle_quickfix()
  local windows = vim.fn.getwininfo()
  for _, win in pairs(windows) do
    if win["quickfix"] == 1 then
      vim.cmd.cclose()
      return
    end
  end
  vim.cmd.copen()
end
vim.keymap.set('n', '<leader>qt', toggle_quickfix, { desc = "Toggle Quickfix Window (c-q to send telescope to quickfix)" })

-- toggle paste
vim.cmd([[
let g:ispastetoggle = 0
let g:origLastStatus = 0
func! TogglePaste()
    if g:ispastetoggle == 0
        let g:origLastStatus = &laststatus
        set laststatus=2
        set statusline+=%=%#Search#\ PASTE\ 
        set paste
        let g:ispastetoggle = 1
    else
        let &laststatus=g:origLastStatus
        let &statusline=substitute(&statusline, "%=%#Search# PASTE $", "", "g")
        set nopaste
        let g:ispastetoggle = 0
    endif
endfunc
map <silent> ,p :call TogglePaste()<CR>
]])

-- line number toggle
vim.cmd([[
map ,n :set nu!\|:set nu?<CR>
]])

-- relative line number toggle
vim.cmd([[
map ,N :set rnu!\|:set rnu?<CR>
]])

-- list toggle (show whitespace)
vim.cmd([[
map ,l :set list!<CR>
]])

-- ruler toggle
vim.cmd([[
nnoremap <C-r> :execute "set colorcolumn=" . (&colorcolumn == "" ? "81" : "")<CR>
]])
