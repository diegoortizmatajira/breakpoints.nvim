local M = {}

local persistence = require("breakpoints.persistence")
local state = require("breakpoints.state")
local storage = require("breakpoints.storage")

local function patch_dap_mutators()
  if state.dap_mutators_patched then return end
  local ok_dap, dap_mod = pcall(require, "dap")
  if not ok_dap then return end

  local bp_mod = require("dap.breakpoints")
  if bp_mod.subscribe then
    bp_mod.subscribe(function() persistence.mark_dirty() end)
  else
    local function wrap(name)
      local original = dap_mod[name]
      if type(original) ~= "function" then return end
      dap_mod[name] = function(...)
        original(...)
        persistence.mark_dirty()
      end
    end
    wrap("toggle_breakpoint")
    wrap("set_breakpoint")
    wrap("clear_breakpoints")
  end

  state.dap_mutators_patched = true
end

function M.setup(opts)
  if state.setup_done then return end
  opts = opts or {}
  state.setup_done = true

  local config = require("breakpoints.config")
  if config.current.on_setup then
    config.current.on_setup()
  end

  local group = vim.api.nvim_create_augroup("BreakpointsPersist", { clear = true })
  state.active_project_key = storage.project_key()
  patch_dap_mutators()

  vim.api.nvim_create_autocmd("VimLeave", {
    group = group,
    callback = function() persistence.save({ force = true }) end,
    desc = "Auto-save breakpoints on exit",
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      local next_key = storage.project_key()
      if next_key == state.active_project_key then return end
      if state.active_project_key then
        persistence.save({ force = true, key = state.active_project_key })
      end
      persistence.load({ key = next_key })
    end,
    desc = "Load breakpoints after project directory changes",
  })

  if opts.load ~= false then
    vim.schedule(persistence.load)
  end
end

return M
