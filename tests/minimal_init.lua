-- Minimal init for breakpoints.nvim tests
-- Adds plugin and mock dependencies to rtp
vim.cmd("set rtp+=.")

-- Mock dap module
local dap_breakpoints = {}
local dap_breakpoints_data = {}
local dap_breakpoints_subscribers = {}

function dap_breakpoints.get(bufnr)
  if bufnr then
    return { [bufnr] = dap_breakpoints_data[bufnr] or {} }
  end
  return dap_breakpoints_data
end

function dap_breakpoints.set(opts, bufnr, line)
  dap_breakpoints_data[bufnr] = dap_breakpoints_data[bufnr] or {}
  local entry = { line = line }
  if opts.condition then entry.condition = opts.condition end
  if opts.log_message then entry.logMessage = opts.log_message end
  if opts.hit_condition then entry.hitCondition = opts.hit_condition end
  table.insert(dap_breakpoints_data[bufnr], entry)
  for _, cb in ipairs(dap_breakpoints_subscribers) do cb() end
end

function dap_breakpoints.remove(bufnr, line)
  local list = dap_breakpoints_data[bufnr]
  if not list then return end
  for i, bp in ipairs(list) do
    if bp.line == line then
      table.remove(list, i)
      break
    end
  end
  for _, cb in ipairs(dap_breakpoints_subscribers) do cb() end
end

function dap_breakpoints.clear()
  dap_breakpoints_data = {}
end

function dap_breakpoints.subscribe(fn)
  table.insert(dap_breakpoints_subscribers, fn)
end

-- Expose mock for tests to manipulate
_G._test_dap_breakpoints = dap_breakpoints
_G._test_dap_breakpoints_data = function() return dap_breakpoints_data end
_G._test_dap_breakpoints_set_data = function(d) dap_breakpoints_data = d end

package.loaded["dap"] = {
  set_breakpoint = function(condition, hit_condition, log_message)
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    dap_breakpoints.set({
      condition = condition,
      hit_condition = hit_condition,
      log_message = log_message,
    }, bufnr, line)
  end,
  toggle_breakpoint = function() end,
  clear_breakpoints = function() dap_breakpoints.clear() end,
}
package.loaded["dap.breakpoints"] = dap_breakpoints

-- Mock picker.nvim (just captures calls)
_G._test_picker_calls = {}
package.loaded["picker"] = {
  select_items = function(items, opts, on_choice)
    table.insert(_G._test_picker_calls, { items = items, opts = opts, on_choice = on_choice })
  end,
}
