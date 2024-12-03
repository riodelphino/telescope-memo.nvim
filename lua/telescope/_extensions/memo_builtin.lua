local conf = require'telescope.config'.values
local entry_display = require'telescope.pickers.entry_display'
local builtin = require'telescope.builtin'
local finders = require'telescope.finders'
local from_entry = require'telescope.from_entry'
local Path = require'plenary.path'
local pickers = require'telescope.pickers'
local previewers = require'telescope.previewers'
local utils = require'telescope.utils'

local M = {}

local sep = string.char(9)

local echo = function(msg, hl)
  vim.api.nvim_echo({{'[telescope-memo] '..msg, hl}}, true, {})
end

local function gen_from_memo(opts)
  local displayer = entry_display.create{
    separator = ' : ',
    items = {
      {}, -- File
      {}, -- Title
    },
  }

  local function make_display(entry)
    return displayer{
      {entry.value, 'TelescopeResultsIdentifier'},
      entry.title,
    }
  end

  return function(line)
    local fields = vim.split(line, sep, true)
    return {
      display = make_display,
      filename = fields[1],
      ordinal = fields[1],
      path = opts.memo_dir..Path.path.sep..fields[1],
      title = fields[2],
      value = fields[1],
    }
  end
end

local function detect_memo_dir(memo_bin)
  local lines = utils.get_os_command_output{memo_bin, 'config', '--cat'}
  for _, line in ipairs(lines) do
    local dir = line:match'memodir%s*=%s*"(.*)"'
    if dir then
      return vim.fn.expand(dir)
    end
  end
  echo('cannot detect memodir', 'ErrorMsg')
end

local function set_default(opts)
  opts = opts or {}
  opts.memo_bin = vim.F.if_nil(opts.memo_bin, 'memo')
  opts.memo_dir = utils.get_lazy_default(opts.memo_dir, detect_memo_dir, opts.memo_bin)
  opts.add_title = false;
  return opts
end


M.list = function(opts)
    opts = set_default(opts)
    opts.add_title_to_file_list = opts.add_title_to_file_list or false

    local find_command
    if opts.add_title_to_file_list then
        find_command = { opts.memo_bin, "list", "--format", "{{.File}}" .. sep .. "{{.Title}}" }
    else
        find_command = { opts.memo_bin, "list", "--format", "{{.File}}" }
    end

    pickers.new(opts, {
        prompt_title = "Memo List",
        finder = finders.new_oneshot_job(find_command, opts),
        entry_maker = gen_from_memo(opts),
        sorter = conf.file_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            define_preview = function(self, entry, status)
                local filepath = entry.path

                -- ファイルを読み込む
                if vim.fn.filereadable(filepath) == 1 then
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
                        vim.fn.bufload(filepath)
                        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                    end)
                else
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "File not found: " .. filepath })
                end
            end,
        }),
    }):find()
end

M.live_grep = function(opts)
  local memo_opts = set_default(opts)
  opts = vim.tbl_extend('force', {cwd = memo_opts.memo_dir}, opts or {})
  builtin.live_grep(opts)
end

M.grep_string = function(opts)
  local memo_opts = set_default(opts)
  opts = vim.tbl_extend('force', {cwd = memo_opts.memo_dir}, opts or {})
  builtin.grep_string(opts)
end

M.grep = function(opts)
  echo('DEPELECATED: use live_grep or grep_string instead of grep', 'WarningMsg')
  opts = set_default(opts)
  builtin.live_grep{cwd = opts.memo_dir}
end

return M
