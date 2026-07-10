-- Shared picker actions: backend-agnostic list of { key, desc, fn(item) }.
-- Both the picker.nvim and telescope backends wire these to their own
-- keymap/action mechanisms so the editing logic only lives here once.
local M = {}

function M.build(deps)
  local persistence = deps.persistence
  local storage = deps.storage
  local state = deps.state
  local refresh = deps.refresh

  local function set_bp(item, opts)
    local bp_mod = require("dap.breakpoints")
    bp_mod.remove(item.value.bufnr, item.value.line)
    bp_mod.set(opts, item.value.bufnr, item.value.line)
    persistence.mark_dirty()
    persistence.save({ force = true })
    refresh()
  end

  return {
    {
      key = "d",
      desc = "Delete",
      fn = function(item)
        require("dap.breakpoints").remove(item.value.bufnr, item.value.line)
        persistence.mark_dirty()
        persistence.save({ force = true })
        refresh()
      end,
    },
    {
      key = "n",
      desc = "Normal BP",
      fn = function(item) set_bp(item, {}) end,
    },
    {
      key = "c",
      desc = "Condition",
      fn = function(item)
        vim.ui.input({ prompt = "Condition: ", default = item.value.bp.condition or "" }, function(val)
          if val == nil then return end
          set_bp(item, { condition = vim.trim(val) ~= "" and val or nil })
        end)
      end,
    },
    {
      key = "l",
      desc = "Log message",
      fn = function(item)
        vim.ui.input({ prompt = "Log message: ", default = item.value.bp.logMessage or "" }, function(val)
          if val == nil then return end
          set_bp(item, { log_message = vim.trim(val) ~= "" and val or nil })
        end)
      end,
    },
    {
      key = "h",
      desc = "Hit condition",
      fn = function(item)
        vim.ui.input({ prompt = "Hit condition: ", default = item.value.bp.hitCondition or "" }, function(val)
          if val == nil then return end
          set_bp(item, { hit_condition = vim.trim(val) ~= "" and val or nil })
        end)
      end,
    },
    {
      key = "G",
      desc = "Move to group",
      fn = function(item)
        vim.ui.input({ prompt = "Group: ", default = item.group ~= "Default" and item.group or "" }, function(val)
          if val == nil then return end
          local meta = storage.load_meta(state.active_project_key)
          local group = vim.trim(val)
          meta[item.value.key] = group ~= "" and group or nil
          storage.save_meta(meta, state.active_project_key)
          refresh()
        end)
      end,
    },
    {
      key = "s",
      desc = "Save",
      fn = function()
        persistence.save({ force = true })
        vim.notify("Breakpoints saved", vim.log.levels.INFO)
      end,
    },
  }
end

return M
