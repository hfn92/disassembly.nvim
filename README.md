# disassembly.nvim

Experimental nvim plugin inspired by [disassemble.nvim](https://github.com/mdedonno1337/disassemble.nvim/tree/master).

This pluging parses `compile_commands.json` to determine the correct object file to be parsed.

`objdump` is required.

## commands

`DisassembleFile` Opens a split with the disassembly for the current file

`DisassembleFunction` Opens a split with the disassembly for the current function as determined ty `treesittter`

`DisassembleClose` Close the spli

## config

```lua
{
  compile_commands_path = ".", -- function or string
  build_directory = ".", -- function or string, path to build_directory (should the same as compile_commands_path if compile_commands.json is in the build directory)
}
```

`lazy.nvim` example with `cmake-tools.nvim`

```lua
 {
   "hfn92/disassembly.nvim",
    cmd = { "DisassembleFunction", "DisassembleFile" },
    config = function()
      require("disassembly").setup {
        build_directory = function()
          local cmake = require "cmake-tools"
          return cmake.get_config().build_directory:expand()
        end,
        compile_commands_path = function()
          local cmake = require "cmake-tools"
          return cmake.get_config().build_directory:expand()
        end,
      }
    end,
 },

```
