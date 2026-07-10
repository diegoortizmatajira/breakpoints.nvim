local M = {}

-- Backends are tried in this order when config.picker == "auto".
local BACKENDS = {
  { name = "picker.nvim", module = "breakpoints.picker.picker_nvim", available = function() return pcall(require, "picker") end },
  { name = "telescope", module = "breakpoints.picker.telescope", available = function() return pcall(require, "telescope") end },
}

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

-- Returns backend, handled. `handled` is true when a misconfiguration was
-- already reported to the user, so the caller shouldn't also emit the
-- generic "no picker found" warning.
local function resolve_backend()
  local picker_opt = require("breakpoints.config").current.picker

  if picker_opt and picker_opt ~= "auto" then
    for _, backend in ipairs(BACKENDS) do
      if backend.name == picker_opt then
        if backend.available() then return require(backend.module), true end
        vim.notify("breakpoints.nvim: picker '" .. picker_opt .. "' is not installed", vim.log.levels.ERROR)
        return nil, true
      end
    end
    vim.notify("breakpoints.nvim: unknown picker '" .. picker_opt .. "'", vim.log.levels.ERROR)
    return nil, true
  end

  for _, backend in ipairs(BACKENDS) do
    if backend.available() then return require(backend.module), true end
  end
  return nil, false
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

  local backend, handled = resolve_backend()
  if not backend then
    if not handled then
      vim.notify(
        "breakpoints.nvim: no supported picker found — install picker.nvim or telescope.nvim",
        vim.log.levels.WARN
      )
    end
    return
  end

  local persistence = require("breakpoints.persistence")
  local storage = require("breakpoints.storage")
  local state = require("breakpoints.state")

  local function refresh() vim.schedule(function() M.open() end) end

  local actions = require("breakpoints.picker.actions").build({
    persistence = persistence,
    storage = storage,
    state = state,
    refresh = refresh,
  })

  local function jump(item)
    vim.cmd("edit " .. vim.fn.fnameescape(item.value.filename))
    vim.api.nvim_win_set_cursor(0, { item.value.line, 0 })
  end

  backend.open(items, { actions = actions, jump = jump })
end

return M
