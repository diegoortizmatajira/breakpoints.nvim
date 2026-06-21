local M = {}

local state = require("breakpoints.state")
local storage = require("breakpoints.storage")

function M.iter_breakpoints(list, on_bp, seen, depth)
  if type(list) ~= "table" then return end
  depth = depth or 0
  if depth > 4 then return end
  seen = seen or {}
  if seen[list] then return end
  seen[list] = true

  if type(list.line) == "number" then
    on_bp(list)
    return
  end

  for _, item in ipairs(list) do
    if type(item) == "table" then
      M.iter_breakpoints(item, on_bp, seen, depth + 1)
    end
  end
end

function M.mark_dirty()
  state.dirty = true
end

function M.save(opts)
  opts = opts or {}
  if not state.dirty and not opts.force then return end
  local key = opts.key or state.active_project_key or storage.project_key()
  local ok_dap, _ = pcall(require, "dap")
  if not ok_dap then return end
  local bp_mod = require("dap.breakpoints")

  local all = bp_mod.get()
  local data = {}
  local live_keys = {}
  for bufnr, list in pairs(all) do
    if type(bufnr) ~= "number" then goto continue end
    local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
    if fname ~= "" then
      local out = {}
      M.iter_breakpoints(list, function(bp)
        if type(bp.line) ~= "number" then return end
        out[#out + 1] = {
          line = bp.line,
          condition = bp.condition,
          logMessage = bp.logMessage,
          hitCondition = bp.hitCondition,
        }
        live_keys[storage.bp_key(fname, bp.line)] = true
      end)
      if #out > 0 then data[fname] = out end
    end
    ::continue::
  end

  if next(data) == nil then
    os.remove(storage.bp_path(key))
  else
    local file = io.open(storage.bp_path(key), "w")
    if file then
      file:write(vim.json.encode(data))
      file:close()
    end
  end

  local meta = storage.load_meta(key)
  local changed = false
  for meta_key, _ in pairs(meta) do
    if not live_keys[meta_key] then
      meta[meta_key] = nil
      changed = true
    end
  end
  if changed then
    storage.save_meta(meta, key)
  end

  state.dirty = false
end

function M.load(opts)
  opts = opts or {}
  local key = opts.key or storage.project_key()

  local ok_dap, _ = pcall(require, "dap")
  if not ok_dap then return end
  local bp_mod = require("dap.breakpoints")

  local path = storage.bp_path(key)
  local file = io.open(path, "r")
  if not file then
    bp_mod.clear()
    state.active_project_key = key
    state.dirty = false
    return
  end
  local raw = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or not data then
    vim.notify("Failed decoding breakpoints file: " .. storage.bp_path(key), vim.log.levels.WARN)
    bp_mod.clear()
    state.active_project_key = key
    state.dirty = false
    return
  end

  bp_mod.clear()
  local count = 0
  local silently_loaded = {}
  local saved_ei = vim.o.eventignore
  vim.o.eventignore = "FileType,BufReadPost,BufEnter,BufWinEnter"

  local ok_apply, err = pcall(function()
    for fname, list in pairs(data) do
      if vim.fn.filereadable(fname) == 1 then
        local bufnr = vim.fn.bufadd(fname)
        vim.fn.bufload(bufnr)
        silently_loaded[#silently_loaded + 1] = bufnr
        M.iter_breakpoints(list, function(bp)
          if type(bp.line) ~= "number" then return end
          bp_mod.set({
            condition = bp.condition,
            log_message = bp.logMessage,
            hit_condition = bp.hitCondition,
          }, bufnr, bp.line)
          count = count + 1
        end)
      end
    end
  end)

  vim.o.eventignore = saved_ei
  if not ok_apply then
    vim.notify("Failed loading breakpoints: " .. tostring(err), vim.log.levels.WARN)
    return
  end

  for _, bufnr in ipairs(silently_loaded) do
    vim.api.nvim_create_autocmd("BufWinEnter", {
      buffer = bufnr,
      once = true,
      callback = function() vim.cmd("filetype detect") end,
    })
  end

  if count > 0 and key ~= state.last_loaded_notice_key then
    state.last_loaded_notice_key = key
    vim.notify(string.format(
      "Loaded %d breakpoint(s) [%s]", count,
      vim.fn.fnamemodify(storage.project_root(), ":t")
    ), vim.log.levels.INFO)
  end

  state.active_project_key = key
  state.dirty = false
end

return M
