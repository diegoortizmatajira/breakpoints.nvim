local M = {}

M.defaults = {
  markers = { "mvnw", "pom.xml", "build.gradle", "build.gradle.kts", "package.json", ".git" },
  storage_dir = vim.fn.stdpath("data") .. "/breakpoints",
  on_setup = nil,
}

M.current = vim.deepcopy(M.defaults)

function M.apply(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
