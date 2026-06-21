local M = {}

function M.setup(opts)
  opts = opts or {}
  require("breakpoints.config").apply(opts)
  require("breakpoints.hooks").setup(opts)
end

function M.save(o) return require("breakpoints.persistence").save(o) end
function M.load(o) return require("breakpoints.persistence").load(o) end
function M.mark_dirty() return require("breakpoints.persistence").mark_dirty() end
function M.save_async() vim.schedule(function() pcall(M.save) end) end
function M.picker() return require("breakpoints.picker").open() end
function M.icon_for(...) return require("breakpoints.icons").icon_for(...) end
function M.short_path(...) return require("breakpoints.icons").short_path(...) end
function M.has_saved_project() return require("breakpoints.storage").has_saved_project() end

function M.assign_group()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then return end
  local storage = require("breakpoints.storage")
  local state = require("breakpoints.state")
  local persistence = require("breakpoints.persistence")

  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
  local bp_mod = require("dap.breakpoints")
  local by_buf = bp_mod.get(bufnr) or {}
  local has_bp = false
  persistence.iter_breakpoints(by_buf[bufnr] or by_buf, function(bp)
    if not has_bp and bp.line == line then has_bp = true end
  end)
  if not has_bp then
    dap.set_breakpoint()
    vim.schedule(function() M.save() end)
  end
  vim.ui.input({ prompt = "Breakpoint group: " }, function(group)
    if not group or group == "" then return end
    local meta = storage.load_meta(state.active_project_key)
    meta[storage.bp_key(fname, line)] = group
    storage.save_meta(meta, state.active_project_key)
    vim.notify("Breakpoint → group «" .. group .. "»", vim.log.levels.INFO)
  end)
end

return M
