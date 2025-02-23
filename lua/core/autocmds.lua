local is_available = astronvim.is_available
local user_plugin_opts = astronvim.user_plugin_opts
local namespace = vim.api.nvim_create_namespace
local cmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local create_command = vim.api.nvim_create_user_command

vim.on_key(function(char)
  if vim.fn.mode() == "n" then
    local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
    if vim.opt.hlsearch:get() ~= new_hlsearch then vim.opt.hlsearch = new_hlsearch end
  end
end, namespace "auto_hlsearch")

cmd({ "VimEnter", "FileType", "BufEnter", "WinEnter" }, {
  desc = "URL Highlighting",
  group = augroup("highlighturl", { clear = true }),
  pattern = "*",
  callback = function() astronvim.set_url_match() end,
})

cmd("TextYankPost", {
  desc = "Highlight yanked text",
  group = augroup("highlightyank", { clear = true }),
  pattern = "*",
  callback = function() vim.highlight.on_yank() end,
})

cmd("FileType", {
  desc = "Unlist quickfist buffers",
  group = augroup("unlist_quickfist", { clear = true }),
  pattern = "qf",
  callback = function() vim.opt_local.buflisted = false end,
})

cmd("BufEnter", {
  desc = "Quit AstroNvim if more than one window is open and only sidebar windows are list",
  group = augroup("auto_quit", { clear = true }),
  callback = function()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    -- Both neo-tree and aerial will auto-quit if there is only a single window left
    if #wins <= 1 then return end
    local sidebar_fts = { aerial = true, ["neo-tree"] = true }
    for _, winid in ipairs(wins) do
      if vim.api.nvim_win_is_valid(winid) then
        local bufnr = vim.api.nvim_win_get_buf(winid)
        local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
        -- If any visible windows are not sidebars, early return
        if not sidebar_fts[filetype] then
          return
        -- If the visible window is a sidebar
        else
          -- only count filetypes once, so remove a found sidebar from the detection
          sidebar_fts[filetype] = nil
        end
      end
    end
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd.tabclose()
    else
      vim.cmd.qall()
    end
  end,
})

if is_available "alpha-nvim" then
  local group_name = augroup("alpha_settings", { clear = true })
  cmd("User", {
    desc = "Disable status and tablines for alpha",
    group = group_name,
    pattern = "AlphaReady",
    callback = function()
      local prev_showtabline = vim.opt.showtabline
      local prev_status = vim.opt.laststatus
      vim.opt.laststatus = 0
      vim.opt.showtabline = 0
      vim.opt_local.winbar = nil
      cmd("BufUnload", {
        pattern = "<buffer>",
        callback = function()
          vim.opt.laststatus = prev_status
          vim.opt.showtabline = prev_showtabline
        end,
      })
    end,
  })
  -- cmd("VimEnter", {
  --   desc = "Start Alpha when vim is opened with no arguments",
  --   group = group_name,
  --   callback = function()
  --     -- vim.cmd('SessionManager! load_current_dir_session')
  --   end,
  -- })
end

if is_available "neo-tree.nvim" then
  cmd("BufEnter", {
    desc = "Open Neo-Tree on startup with directory",
    group = augroup("neotree_start", { clear = true }),
    callback = function()
      local stats = vim.loop.fs_stat(vim.api.nvim_buf_get_name(0))
      if stats and stats.type == "directory" then require("neo-tree.setup.netrw").hijack() end
    end,
  })
end

if is_available "nvim-dap-ui" then
  vim.api.nvim_create_autocmd("FileType", {
    desc = "Make q close dap floating windows",
    group = vim.api.nvim_create_augroup("dapui", { clear = true }),
    pattern = "dap-float",
    callback = function() vim.keymap.set("n", "q", "<cmd>close!<cr>") end,
  })
end

cmd({ "VimEnter", "ColorScheme" }, {
  desc = "Load custom highlights from user configuration",
  group = augroup("astronvim_highlights", { clear = true }),
  callback = function()
    if vim.g.colors_name then
      for _, module in ipairs { "init", vim.g.colors_name } do
        for group, spec in pairs(user_plugin_opts("highlights." .. module)) do
          vim.api.nvim_set_hl(0, group, spec)
        end
      end
    end
    astronvim.event "ColorScheme"
  end,
})

vim.api.nvim_create_autocmd("BufRead", {
  group = vim.api.nvim_create_augroup("git_plugin_lazy_load", { clear = true }),
  callback = function()
    vim.fn.system("git -C " .. vim.fn.expand "%:p:h" .. " rev-parse")
    if vim.v.shell_error == 0 then
      vim.api.nvim_del_augroup_by_name "git_plugin_lazy_load"
      local packer = require "packer"
      vim.tbl_map(function(plugin) packer.loader(plugin) end, astronvim.git_plugins)
    end
  end,
})
vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("file_plugin_lazy_load", { clear = true }),
  callback = function()
    local title = vim.fn.expand "%"
    if not (title == "" or title == "[packer]" or title:match "^neo%-tree%s+filesystem") then
      vim.api.nvim_del_augroup_by_name "file_plugin_lazy_load"
      local packer = require "packer"
      vim.tbl_map(function(plugin) packer.loader(plugin) end, astronvim.file_plugins)
    end
  end,
})

create_command(
  "AstroUpdatePackages",
  function() astronvim.updater.update_packages() end,
  { desc = "Update Packer and Mason" }
)
create_command("AstroUpdate", function() astronvim.updater.update() end, { desc = "Update AstroNvim" })
create_command("AstroReload", function() astronvim.updater.reload() end, { desc = "Reload AstroNvim" })
create_command("AstroVersion", function() astronvim.updater.version() end, { desc = "Check AstroNvim Version" })
create_command("AstroChangelog", function() astronvim.updater.changelog() end, { desc = "Check AstroNvim Changelog" })
create_command("ToggleHighlightURL", function() astronvim.ui.toggle_url_match() end, { desc = "Toggle URL Highlights" })

if is_available "mason.nvim" then
  create_command("MasonUpdateAll", function() astronvim.mason.update_all() end, { desc = "Update Mason Packages" })
  create_command(
    "MasonUpdate",
    function(opts) astronvim.mason.update(opts.args) end,
    { nargs = 1, desc = "Update Mason Package" }
  )
end
