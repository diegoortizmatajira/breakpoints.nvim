-- Backend for lenincamp/picker.nvim.
local M = {}

function M.open(items, ctx)
  local picker = require("picker")

  local actions = {}
  for _, action in ipairs(ctx.actions) do
    actions[action.key] = {
      desc = action.desc,
      fn = function(_, item)
        if not item then return end
        action.fn(item)
      end,
    }
  end

  picker.select_items(items, {
    prompt = "Breakpoints",
    layout = "intellij_grep",
    preview = function(item) return item and item.path or nil end,
    preview_open = true,
    preview_lnum = function(item) return item and item.lnum end,
    actions = actions,
  }, function(item)
    if not item then return end
    ctx.jump(item)
  end)
end

return M
