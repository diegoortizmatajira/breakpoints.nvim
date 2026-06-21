-- icons_spec.lua: Tests for breakpoints.icons module
local icons = require("breakpoints.icons")

describe("breakpoints.icons", function()
  describe("icon_for_bp", function()
    it("returns ◉ for log breakpoint", function()
      assert.equals("◉", icons.icon_for_bp({ logMessage = "hello" }))
    end)

    it("returns ◆ for conditional breakpoint", function()
      assert.equals("◆", icons.icon_for_bp({ condition = "x > 0" }))
    end)

    it("returns ◇ for hit condition breakpoint", function()
      assert.equals("◇", icons.icon_for_bp({ hitCondition = "5" }))
    end)

    it("returns ● for plain breakpoint", function()
      assert.equals("●", icons.icon_for_bp({}))
    end)

    it("prioritizes log over condition", function()
      assert.equals("◉", icons.icon_for_bp({ logMessage = "msg", condition = "x" }))
    end)

    it("handles empty strings as absent", function()
      assert.equals("●", icons.icon_for_bp({ logMessage = "", condition = "" }))
    end)
  end)

  describe("icon_for", function()
    it("returns ● when no dap breakpoints match", function()
      assert.equals("●", icons.icon_for("999", "nonexistent.lua"))
    end)

    it("resolves icon from dap.breakpoints data", function()
      local buf = vim.api.nvim_create_buf(true, false)
      local tmp = vim.fn.tempname() .. ".lua"
      vim.fn.writefile({ "line1" }, tmp)
      vim.api.nvim_buf_set_name(buf, tmp)

      local dap_bp = _G._test_dap_breakpoints
      dap_bp.set({ condition = "active" }, buf, 1)

      local rel = vim.fn.fnamemodify(tmp, ":.")
      assert.equals("◆", icons.icon_for("1", rel))

      vim.api.nvim_buf_delete(buf, { force = true })
      vim.fn.delete(tmp)
    end)
  end)

  describe("short_path", function()
    it("returns original for short paths", function()
      assert.equals("a/b.lua", icons.short_path("a/b.lua"))
    end)

    it("shortens long paths to last 2 segments", function()
      assert.equals("c/d.lua", icons.short_path("a/b/c/d.lua"))
    end)

    it("returns 3 segment paths unchanged", function()
      assert.equals("a/b/c.lua", icons.short_path("a/b/c.lua"))
    end)
  end)
end)
