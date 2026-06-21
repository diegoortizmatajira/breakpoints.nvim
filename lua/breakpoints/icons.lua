local M = {}

function M.icon_for_bp(bp)
  if bp.logMessage and bp.logMessage ~= "" then return "◉" end
  if bp.condition and bp.condition ~= "" then return "◆" end
  if bp.hitCondition and bp.hitCondition ~= "" then return "◇" end
  return "●"
end

function M.icon_for(lnum_str, path)
  local ok_bp, dap_bp = pcall(require, "dap.breakpoints")
  if not ok_bp then return "●" end
  local lnum = tonumber(lnum_str)
  for bufnr, entries in pairs(dap_bp.get() or {}) do
    local buffer_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
    if buffer_name == path then
      for _, bp in ipairs(entries) do
        if bp.line == lnum then return M.icon_for_bp(bp) end
      end
    end
  end
  return "●"
end

function M.short_path(path)
  local parts = vim.split(path, "/")
  if #parts <= 3 then return path end
  return parts[#parts - 1] .. "/" .. parts[#parts]
end

return M
