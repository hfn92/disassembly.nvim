local log = require("qf-virtual-text.log")
local const = require("qf-virtual-text.const")

local M = {}

local config = const
local ns_id = vim.api.nvim_create_namespace("qf-virtual-text")

-- GTest error formats
--
-- _TRUE, _FALSE
-- Value of: false
--   Actual: false
-- Expected: true
--

--
-- _EQ
-- Expected equality of these values:
--   1
--   2
--
-- Expected equality of these values:
--   1 - 1
--     Which is: 0
--   2 + 3
--     Which is: 5
--
-- _Gx, _Lx and _NE (why different from EQ?)
--  Expected: (2) <= (1), actual: 2 vs 1
--  Expected: (2 + 3) != (2 + 3), actual: 5 vs 5
--  Expected: (std::string("test")) != (std::string("test")), actual: "test" vs "test"

local function clear()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  end
end

local function remove_prefix(text, prefix)
  if text:find(prefix, 1, true) == 1 then
    return true, text:sub(#prefix + 1)
  end
  return false, text
end

local function starts_with(text, prefix)
  return text:find(prefix, 1, true) == 1
end

local function get_text_gtest(qf_items, idx, item)
  local next = qf_items[idx + 1]
  -- if not next then
  --   return item.text, "error"
  -- end

  if next.text == "Expected equality of these values:" then
    local removed = false
    local left = qf_items[idx + 2].text
    local right = qf_items[idx + 3].text
    local check_right = 4
    removed, right = remove_prefix(right, "    Which is: ")
    if removed then
      left = right
      right = qf_items[idx + 4].text
      check_right = 5
    end

    local temp = ""
    removed, temp = remove_prefix(qf_items[idx + check_right].text, "    Which is: ")
    if removed then
      right = temp
    end

    return next.text .. " " .. left .. " vs " .. right
  end

  if starts_with(next.text, "Value of: ") then
    return qf_items[idx + 3].text .. qf_items[idx + 2].text
  end

  if starts_with(next.text, "Expected: ") then
    return next.text
  end

  return item.text
end

local function get_text(qf_items, idx, item)
  if item.text == " Failure" then
    local ok, text = pcall(function()
      return get_text_gtest(qf_items, idx, item)
    end)
    if ok then
      return text, "error"
    end
  end

  if starts_with(item.text, "warning:") or starts_with(item.text, " warning:") then
    return item.text, "warn"
  end

  if starts_with(item.text, "error:") or starts_with(item.text, " error:") then
    return item.text, "error"
  end

  return item.text, "info"
end

local function show_virt_text()
  local qf_items = vim.fn.getqflist()
  for idx, v in ipairs(qf_items) do
    if v.valid then
      local bnr = v.bufnr
      local line_num = v.lnum - 1

      local text, type = get_text(qf_items, idx, v)

      text = "   " .. text

      local opts = {
        virt_text = { { text, config.highlight[type] } },
      }
      local ok, err = pcall(function()
        vim.api.nvim_buf_set_extmark(bnr, ns_id, line_num, 0, opts)
      end)
    end
  end
end

local function refresh_job()
  clear()
  show_virt_text()

  vim.defer_fn(function()
    refresh_job()
  end, config.refresh_rate_ms)
end

function M.setup(values)
  vim.tbl_deep_extend("force", config, values)
  refresh_job()
end

return M
