local log = require("disassembly.log")
local const = require("disassembly.const")
local Path = require("plenary.path")
local has_ts, ts_utils = pcall(require, "nvim-treesitter.ts_utils")

local M = {}

local config = const

function M.setup(values)
  config = vim.tbl_deep_extend("force", config, values)
end

local function get_path(i)
  if type(i) == "string" then
    return i
  elseif type(i) == "function" then
    return i()
  end

  log.error("path is not a function or string")
  error()
end

local function parse_compile_commands()
  local path = get_path(config.compile_commands_path)

  path = path .. "/compile_commands.json"

  local codemodel = Path:new(path)
  if not codemodel:exists() then
    error("file not found")
  end
  return vim.json.decode(codemodel:read())
end

-- select for multiple
local function get_current_obj_file()
  local currentfile = vim.fn.expand("%:."):gsub("\\", "/")
  local ccs = parse_compile_commands()
  local build_dir = get_path(config.build_directory)

  currentfile = vim.fn.fnamemodify(currentfile, ":p") -- .. "/" .. vim.fn.fnamemodify(currentfile, ":t")

  local objfile = nil

  -- dir
  for _, v in ipairs(ccs) do
    if v.file and v.file:gsub("\\", "/") == currentfile then
      objfile = build_dir .. "/" .. v.output
    end
  end

  if not Path:new(objfile):exists() then
    log.warn("objectfile not found:" .. vim.inspect(objfile))
    error()
  end
  return objfile
end

local function get_output(cmd)
  return vim.fn.systemlist(cmd)
end

local function seek_line(lines)
  local line = vim.fn.line(".")
  local line_asm = -1
  local lines_searched = 0

  while line_asm < 0 do
    line_asm = vim.fn.matchstrpos(lines, vim.fn.expand("%:t") .. ":" .. line)[2]
    -- line_asm = vim.fn.matchstrpos(lines, vim.fn.expand("%:t") .. ":" .. line .. [[\(\s*(discriminator \d*)\)*$]])[2]
    lines_searched = lines_searched + 1
    line = line + 1

    if lines_searched > 20 then
      -- error("Not found?")
      return -1
    end
  end

  return line_asm
end

local screen = {
  src = nil,
  src_win = nil,
  asm = nil,
  asm_win = nil,
}

local function get_objdump(file, fn)
  local sym = ""
  if fn then
    sym = '--disassemble="' .. fn .. '" '
  end
  local lines = get_output(
    "objdump --demangle --line-numbers --file-headers --file-offsets --source --no-show-raw-insn -w -S " .. sym .. file
  )
  -- local lines = vim.split(output, "\n")
  local line = seek_line(lines)

  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "asm")
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "delete")

  screen.asm = buf
  screen.src = vim.api.nvim_get_current_buf()
  screen.src_win = vim.api.nvim_get_current_win()

  vim.cmd(":vsp")
  vim.cmd(":buffer " .. buf)
  vim.api.nvim_win_set_cursor(0, { line, 0 })

  screen.asm_win = vim.api.nvim_get_current_win()
  local group = vim.api.nvim_create_augroup("disassembly.nvim", { clear = true })

  local startLine = 1
  local startCol = 1
  local endCol = -1 -- -1 means until the end of the line

  -- Set the highlight for the specified range in the buffer
  vim.api.nvim_buf_add_highlight(screen.asm, -1, "CursorLine", startLine - 1, startCol - 1, endCol)
  local ns = vim.api.nvim_create_namespace("disassembly.nvim")
  vim.api.nvim_set_hl(ns, "CursorLine", { bg = "#2a2b2b" })
  vim.api.nvim_win_set_hl_ns(screen.asm_win, ns)

  local cmdid = vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = screen.src,
    callback = function()
      line = seek_line(lines)
      if line > 0 then
        vim.api.nvim_win_set_cursor(screen.asm_win, { line + 1, 0 })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    buffer = screen.asm,
    once = true,
    callback = function()
      vim.api.nvim_clear_autocmds({ group = group })
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      if ev.file == "" .. screen.asm_win then
        vim.api.nvim_clear_autocmds({ group = group })
      end
    end,
  })

  vim.api.nvim_set_current_win(screen.src_win)
  vim.api.nvim_set_current_buf(screen.src)
end

if has_ts then
  local function get_current_function()
    local current_node = ts_utils.get_node_at_cursor()
    if not current_node then
      return ""
    end

    local expr = current_node

    while expr do
      if expr:type() == "function_definition" then
        break
      end
      expr = expr:parent()
    end

    if not expr then
      return ""
    end

    return vim.treesitter.get_node_text(expr:child(1), 0)
  end

  function M.disassemble_function()
    pcall(function()
      local fn = get_current_function()
      local objfile = get_current_obj_file()
      get_objdump(objfile, fn)
    end)
  end
end

function M.disassemble_file()
  pcall(function()
    local objfile = get_current_obj_file()
    get_objdump(objfile)
  end)
end

function M.disassemble_close()
  pcall(function()
    vim.api.nvim_win_close(screen.asm_win, false)
  end)
end

return M
