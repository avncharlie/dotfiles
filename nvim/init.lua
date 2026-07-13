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
-- use lazy.nvim as package manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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
  {
    'saghen/blink.cmp',
    version = '1.*',
    build = function() require('blink.cmp').build():pwait() end,
    dependencies = { { 'saghen/blink.compat', opts = {} } },
    opts = {
      keymap = {
        preset = 'enter',
        ['<Tab>'] = { 'snippet_forward', 'select_next', 'fallback' },
        ['<S-Tab>'] = { 'snippet_backward', 'select_prev', 'fallback' },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer', 'avante_commands', 'avante_mentions', 'avante_shortcuts', 'avante_files' },
        providers = {
          avante_commands = {
            name = 'avante_commands',
            module = 'blink.compat.source',
            score_offset = 90,
            opts = {},
          },
          avante_files = {
            name = 'avante_files',
            module = 'blink.compat.source',
            score_offset = 100,
            opts = {},
          },
          avante_mentions = {
            name = 'avante_mentions',
            module = 'blink.compat.source',
            score_offset = 1000,
            opts = {},
          },
          avante_shortcuts = {
            name = 'avante_shortcuts',
            module = 'blink.compat.source',
            score_offset = 1000,
            opts = {},
          },
        },
      },
      snippets = { preset = 'default' },
      completion = {
        list = {
          selection = {
            preselect = false,
            auto_insert = true,
          },
        },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        menu = {
          draw = {
            columns = { { 'kind_icon' }, { 'label', gap = 1 } },
            components = {
              label = {
                text = function(ctx)
                  return require('colorful-menu').blink_components_text(ctx)
                end,
                highlight = function(ctx)
                  return require('colorful-menu').blink_components_highlight(ctx)
                end,
              },
            },
          },
        },
      },
      cmdline = {
        enabled = true,
        keymap = { preset = 'cmdline' },
      },
    },
  },

  -- colorful completion menu (treesitter-highlighted labels)
  {
    'xzbdmw/colorful-menu.nvim',
    config = function()
      require('colorful-menu').setup {}
    end,
  },

  -- treesitter (main branch: parser management only; highlighting via built-in)
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    init = function()
      local ensure_installed = require('nvim-treesitter.config').get_available()
      local already = require('nvim-treesitter.config').get_installed()
      local to_install = vim.iter(ensure_installed)
        :filter(function(p) return not vim.tbl_contains(already, p) end)
        :totable()
      if #to_install > 0 then
        require('nvim-treesitter').install(to_install)
      end
    end,
    config = function()
      require('nvim-treesitter').setup()
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('UserTreesitter', { clear = true }),
        callback = function()
          pcall(vim.treesitter.start)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    init = function()
      vim.g.no_plugin_maps = true
    end,
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

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
    branch = 'master',
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

  -- nice indent
  'Vimjas/vim-python-pep8-indent',

  -- fuzzy finder
  { url = 'https://codeberg.org/andyg/leap.nvim' },

  { 'lervag/vimtex' },

  {
    "yetone/avante.nvim",
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    -- ⚠️ must add this setting! ! !
    build = vim.fn.has("win32") ~= 0
        and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
        or "make",
    event = "VeryLazy",
    version = false, -- Never set this value to "*"! Never!
    ---@module 'avante'
    ---@type avante.Config
    opts = {
      provider = "openrouter",
      behaviour = {
        auto_apply_diff_after_generation = false, -- Prevents applying changes instantly
        auto_approve_tool_permissions = false,    -- Stops agentic mode from auto-approving
      },
      selection = {
        hint_display = "none",
      },
      selector = { provider = "telescope" },
      providers = {
        openrouter = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          model = "z-ai/glm-5.2",
          api_key_name = "cmd:cat ~/.openrouter_key",
        },
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "stevearc/dressing.nvim", -- for input provider dressing
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "Avante" },
        },
        ft = { "Avante" },
      },
    },
  },

})

-- C-h to open Avante history
vim.keymap.set('n', '<C-H>', ':AvanteHistory<CR>', {silent = true})

-- vimtex
vim.g.vimtex_view_method='skim'

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
-- setup up lsps + extra capabilities for completion
-- to add new lsp: see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
--                 and https://github.com/williamboman/mason-lspconfig.nvim/blob/main/doc/server-mapping.md
-- lsp configuration (Neovim 0.11+)
local capabilities = require('blink.cmp').get_lsp_capabilities()

local servers = {
  'jdtls',
  'clangd',
  'pyright',
  'ts_ls', -- if you switch from tsserver to the new ts_ls
  -- 'asm_lsp',
  'cssls',
  'cssmodules_ls',
  'ocamllsp',
  'rust_analyzer',
}

for _, name in ipairs(servers) do
  -- register/augment config
  vim.lsp.config(name, {
    capabilities = capabilities,
    -- on_attach = function(client, bufnr) ... end,  -- if you want per-server hooks
    -- cmd = {...}, root_dir = function() ... end,   -- only if you need to override defaults
  })
  -- start/enable it (auto-starts on matching buffers)
  vim.lsp.enable(name)
end

-- diagnostics
vim.keymap.set('n', '[d', function() vim.diagnostic.jump({count=-1, float=true}) end, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', function() vim.diagnostic.jump({count=1, float=true}) end, { desc = 'Go to next diagnostic message' })
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

-- treesitter textobjects config (main branch: explicit keymaps)
local tto = require('nvim-treesitter-textobjects')
tto.setup {
  select = { lookahead = true },
  move = { set_jumps = true },
}
local tto_select = require('nvim-treesitter-textobjects.select')
local tto_move = require('nvim-treesitter-textobjects.move')
local tto_swap = require('nvim-treesitter-textobjects.swap')

-- select textobjects
for _, lhs in ipairs({ 'aa', 'ia', 'af', 'if', 'ac', 'ic' }) do
  local capture = ({
    aa = '@parameter.outer', ia = '@parameter.inner',
    af = '@function.outer',  ['if'] = '@function.inner',
    ac = '@class.outer',     ic = '@class.inner',
  })[lhs]
  vim.keymap.set({ 'x', 'o' }, lhs, function()
    tto_select.select_textobject(capture, 'textobjects')
  end)
end

-- move textobjects
vim.keymap.set({ 'n', 'x', 'o' }, ']]', function() tto_move.goto_next_start('@function.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, ']c', function() tto_move.goto_next_start('@class.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, ']M', function() tto_move.goto_next_end('@function.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, ']C', function() tto_move.goto_next_end('@class.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, '[[', function() tto_move.goto_previous_start('@function.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, '[c', function() tto_move.goto_previous_start('@class.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, '[M', function() tto_move.goto_previous_end('@function.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, '[C', function() tto_move.goto_previous_end('@class.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, ']i', function() tto_move.goto_next('@conditional.outer', 'textobjects') end)
vim.keymap.set({ 'n', 'x', 'o' }, '[i', function() tto_move.goto_previous('@conditional.outer', 'textobjects') end)

-- swap textobjects
vim.keymap.set('n', '<leader>a', function() tto_swap.swap_next('@parameter.inner') end)
vim.keymap.set('n', '<leader>A', function() tto_swap.swap_previous('@parameter.inner') end)

-- folding with treesitter (built-in foldexpr)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99

-- telescope settings
require('telescope').setup {
  defaults = {
    history = { limit = 100, cycle_wrap = true },
    file_ignore_patterns = { "^.git/" },
    mappings = {
      i = {
        ['<C-n>'] = false,
        ['<C-p>'] = false,
        ['<Up>']   = require('telescope.actions').cycle_history_prev,
        ['<Down>'] = require('telescope.actions').cycle_history_next,
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
-- keybindings: s and S (Sneak-style)
vim.keymap.del('x', 'S')  -- visual mode
vim.keymap.set({'n', 'x', 'o'}, 's',  '<Plug>(leap-forward)')
vim.keymap.set({'n', 'x', 'o'}, 'S',  '<Plug>(leap-backward)')
vim.keymap.set('n',             'gs', '<Plug>(leap-from-window)')

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


------------------ 

local function preview_location_telescope()
    local line = vim.api.nvim_get_current_line()
    
    -- Remove any leading status markers like [OK], [VULN], etc.
    local cleaned = line:gsub("^%s*%[[^%]]*%]%s*", "")
    
    -- Now match file:line:rest
    -- This handles paths with spaces, dots, slashes, etc.
    local file, lnum, text = cleaned:match("^([^:]+):(%d+):(.*)")
    
    if not file or not lnum then
        vim.notify("No file:line found on current line", vim.log.levels.WARN)
        vim.notify("Line content: " .. line, vim.log.levels.DEBUG)
        return
    end
    
    -- Trim any whitespace
    file = vim.trim(file)
    
    -- Remove leading ./ if present
    file = file:gsub("^%./", "")
    
    -- Convert to absolute path
    if not vim.startswith(file, "/") then
        file = vim.fn.getcwd() .. "/" .. file
    end
    
    -- Normalize path (resolve .., ., etc)
    file = vim.fn.fnamemodify(file, ":p")
    
    -- Debug output
    print("Resolved file path: " .. file)
    
    -- Check file exists
    if vim.fn.filereadable(file) == 0 then
        vim.notify("File not found: " .. file, vim.log.levels.ERROR)
        -- Try to find it relative to current buffer's directory
        local bufdir = vim.fn.expand('%:p:h')
        local alt_file = bufdir .. "/" .. vim.fn.fnamemodify(file, ":t")
        if vim.fn.filereadable(alt_file) == 1 then
            file = alt_file
            vim.notify("Found at: " .. file, vim.log.levels.INFO)
        else
            return
        end
    end
    
    -- Create single-entry quickfix and open telescope
    vim.fn.setqflist({{
        filename = file,
        lnum = tonumber(lnum),
        col = 1,
        text = vim.trim(text or ""),
    }})
    
    require('telescope.builtin').quickfix()
end

vim.keymap.set('n', 'gl', preview_location_telescope, { desc = 'Preview location in Telescope' })

-- vim.api.nvim_create_autocmd("DirChanged", {
--   callback = function(args)
--     vim.notify("CWD changed to: " .. vim.fn.getcwd() .. "\nTriggered by: " .. vim.inspect(args), vim.log.levels.WARN)
--     -- Print stack trace to find the culprit
--     print(debug.traceback())
--   end,
-- })
