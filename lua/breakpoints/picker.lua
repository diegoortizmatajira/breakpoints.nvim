local M = {}

local function collect_items()
  local ok, bp_mod = pcall(require, "dap.breakpoints")
  if not ok then return {} end

  local state = require("breakpoints.state")
  local storage = require("breakpoints.storage")
  local icons = require("breakpoints.icons")
  local persistence = require("breakpoints.persistence")
  local meta = storage.load_meta(state.active_project_key)
  local items = {}

  for bufnr, list in pairs(bp_mod.get() or {}) do
    if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
      local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
      if fname ~= "" then
        persistence.iter_breakpoints(list, function(bp)
          local key = storage.bp_key(fname, bp.line)
          local rel = vim.fn.fnamemodify(fname, ":~:.")
          local icon = icons.icon_for_bp(bp)
          local meta_str = ""
          if bp.condition and bp.condition ~= "" then
            meta_str = " if " .. bp.condition
          elseif bp.logMessage and bp.logMessage ~= "" then
            meta_str = " log " .. bp.logMessage
          elseif bp.hitCondition and bp.hitCondition ~= "" then
            meta_str = " hit " .. bp.hitCondition
          end

          items[#items + 1] = {
            label = string.format("%s %s  %s:%d%s", meta[key] or "Default", icon, rel, bp.line, meta_str),
            value = { bufnr = bufnr, filename = fname, line = bp.line, key = key, bp = bp },
            group = meta[key] or "Default",
            path = fname,
            lnum = bp.line,
          }
        end)
      end
    end
  end

  table.sort(items, function(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.value.filename ~= b.value.filename then return a.value.filename < b.value.filename end
    return a.value.line < b.value.line
  end)
  return items
end

function M.open()
  local ok_dap, _ = pcall(require, "dap")
  if not ok_dap then return end

  require("breakpoints.hooks").setup({ load = false })

  local items = collect_items()
  if #items == 0 and require("breakpoints.storage").has_saved_project() then
    require("breakpoints.persistence").load()
    items = collect_items()
  end
  if #items == 0 then
    vim.notify("No breakpoints in this project", vim.log.levels.INFO)
    return
  end

  local picker = require("picker")
  local persistence = require("breakpoints.persistence")
  local storage = require("breakpoints.storage")
  local state = require("breakpoints.state")

  local function refresh() vim.schedule(function() M.open() end) end

  local function set_bp(item, opts)
    local bp_mod = require("dap.breakpoints")
    bp_mod.remove(item.value.bufnr, item.value.line)
    bp_mod.set(opts, item.value.bufnr, item.value.line)
    persistence.mark_dirty()
    persistence.save({ force = true })
    refresh()
  end

  picker.select_items(items, {
    prompt = "Breakpoints",
    layout = "intellij_grep",
    preview = function(item) return item and item.path or nil end,
    preview_open = true,
    preview_lnum = function(item) return item and item.lnum end,
    actions = {
      d = { desc = "Delete", fn = function(_, item)
        if not item then return end
        require("dap.breakpoints").remove(item.value.bufnr, item.value.line)
        persistence.mark_dirty()
        persistence.save({ force = true })
        refresh()
      end },
      n = { desc = "Normal BP", fn = function(_, item)
        if not item then return end
        set_bp(item, {})
      end },
      c = { desc = "Condition", fn = function(_, item)
        if not item then return end
        vim.ui.input({ prompt = "Condition: ", default = item.value.bp.condition or "" }, function(val)
          if val == nil then return end
          set_bp(item, { condition = vim.trim(val) ~= "" and val or nil })
        end)
      end },
      l = { desc = "Log message", fn = function(_, item)
        if not item then return end
        vim.ui.input({ prompt = "Log message: ", default = item.value.bp.logMessage or "" }, function(val)
          if val == nil then return end
          set_bp(item, { log_message = vim.trim(val) ~= "" and val or nil })
        end)
      end },
      h = { desc = "Hit condition", fn = function(_, item)
        if not item then return end
        vim.ui.input({ prompt = "Hit condition: ", default = item.value.bp.hitCondition or "" }, function(val)
          if val == nil then return end
          set_bp(item, { hit_condition = vim.trim(val) ~= "" and val or nil })
        end)
      end },
      G = { desc = "Move to group", fn = function(_, item)
        if not item then return end
        vim.ui.input({ prompt = "Group: ", default = item.group ~= "Default" and item.group or "" }, function(val)
          if val == nil then return end
          local meta = storage.load_meta(state.active_project_key)
          local group = vim.trim(val)
          meta[item.value.key] = group ~= "" and group or nil
          storage.save_meta(meta, state.active_project_key)
          refresh()
        end)
      end },
      s = { desc = "Save", fn = function()
        persistence.save({ force = true })
        vim.notify("Breakpoints saved", vim.log.levels.INFO)
      end },
    },
  }, function(item)
    if not item then return end
    vim.cmd("edit " .. vim.fn.fnameescape(item.value.filename))
    vim.api.nvim_win_set_cursor(0, { item.value.line, 0 })
  end)
end

return M
