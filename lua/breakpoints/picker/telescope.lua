-- Backend for nvim-telescope/telescope.nvim.
local M = {}

local function entry_maker(item)
  return {
    value = item,
    display = item.label,
    ordinal = item.label,
    filename = item.path,
    lnum = item.lnum,
  }
end

function M.open(items, ctx)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local previewers = require("telescope.previewers")
  local telescope_actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Breakpoints",
      finder = finders.new_table({ results = items, entry_maker = entry_maker }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.vim_buffer_vimgrep.new({}),
      attach_mappings = function(prompt_bufnr, map)
        telescope_actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          telescope_actions.close(prompt_bufnr)
          if entry then ctx.jump(entry.value) end
        end)

        for _, action in ipairs(ctx.actions) do
          map("n", action.key, function()
            local entry = action_state.get_selected_entry()
            if not entry then return end
            action.fn(entry.value)
          end)
        end

        return true
      end,
    })
    :find()
end

return M
