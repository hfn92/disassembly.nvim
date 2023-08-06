local ds = require("disassembly")

vim.api.nvim_create_user_command(
  "DisassembleFile", -- name
  ds.disassemble_file, -- command
  { -- opts
    nargs = 0,
  }
)

vim.api.nvim_create_user_command(
  "DisassembleFunction", -- name
  ds.disassemble_function, -- command
  { -- opts
    nargs = 0,
  }
)

vim.api.nvim_create_user_command(
  "DisassembleClose", -- name
  ds.disassemble_close, -- command
  { -- opts
    nargs = 0,
  }
)
