-- Standalone Cursor Dark Midnight palette; no theme engine or language overrides.
vim.o.background = "dark"
vim.o.termguicolors = true
vim.cmd("highlight clear")
if vim.g.syntax_on then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "cursor-midnight"

local p = {
  bg = "#1e2127",
  terminal = "#191c22",
  float = "#20242c",
  fg = "#7b88a1",
  text = "#d8dee9",
  faint = "#4b5163",
  dim = "#4c566a",
  border = "#272c36",
  selection = "#434c5e",
  sidebar = "#7c818e",
  red = "#bf616a",
  green = "#a3be8c",
  yellow = "#ebcb8b",
  blue = "#81a1c1",
  purple = "#b48ead",
  cyan = "#88c0d0",
  teal = "#8fbcbb",
  orange = "#d08770",
  white = "#eceff4",
  gold = "#ffd700",
  orchid = "#da70d6",
  azure = "#179fff",
}
local function blend(rgba, background)
  local alpha, channels = tonumber(rgba:sub(8, 9), 16) / 255, {}
  background = background or p.bg
  for i = 2, 6, 2 do
    local fg, bg = tonumber(rgba:sub(i, i + 1), 16), tonumber(background:sub(i, i + 1), 16)
    channels[#channels + 1] = math.floor(fg * alpha + bg * (1 - alpha) + 0.5)
  end
  return string.format("#%02x%02x%02x", unpack(channels))
end
local function set(names, style)
  for name in names:gmatch("%S+") do
    vim.api.nvim_set_hl(0, name, style)
  end
end
local function link(names, target)
  set(names, { link = target })
end

set("Normal NormalNC", { fg = p.fg, bg = p.bg })
set("NormalFloat", { fg = p.text, bg = p.float })
set("FloatBorder FloatTitle FloatFooter", { fg = p.border, bg = p.float })
set("Cursor lCursor", { fg = p.bg, bg = p.text })
set("TermCursor", { fg = p.terminal, bg = p.teal })
set("CursorLine CursorColumn ColorColumn", { bg = blend("#434c5e33") })
set("LineNr LineNrAbove LineNrBelow SignColumn FoldColumn", { fg = p.dim, bg = p.bg })
set("CursorLineNr", { fg = "#687692" })
set("Whitespace NonText SpecialKey", { fg = blend("#4c566ab3") })
set("EndOfBuffer", { fg = p.bg })
set("WinSeparator", { fg = blend("#ffffff0d") })
set("Visual", { bg = blend("#434c5e99") })
set("VisualNOS", { bg = p.selection })
set("Search", { fg = p.fg, bg = blend("#88c0d033") })
set("IncSearch CurSearch", { fg = p.fg, bg = blend("#88c0d066") })
set("MatchParen", { fg = p.cyan, bg = p.bg })
set("Pmenu PmenuKind PmenuExtra", { fg = p.text, bg = p.terminal })
set("PmenuSel PmenuKindSel PmenuExtraSel", { fg = p.text, bg = p.selection })
set("PmenuSbar", { bg = p.border })
set("PmenuThumb", { bg = p.dim })
set("StatusLine StatusLineNC TabLine TabLineFill WinBar WinBarNC", { fg = p.faint, bg = p.terminal })
set("TabLineSel", { fg = p.text, bg = p.bg })
set("Folded", { fg = p.dim, bg = p.float })
set("Directory MoreMsg Question Title", { fg = p.cyan })
set("Error ErrorMsg", { fg = p.red })
set("WarningMsg", { fg = p.yellow })
set("ModeMsg", { fg = p.fg })
set("Conceal", { fg = p.dim })
set("QuickFixLine", { bg = p.selection })
set("Comment", { fg = blend("#8597bca6"), italic = true })
set("Identifier", { fg = p.text })
set("Type Constant", { fg = p.fg })
set("Function", { fg = p.cyan })
set("Statement Keyword Operator", { fg = p.blue })
set("String", { fg = p.green })
set("Number Boolean Float", { fg = p.purple })
set("PreProc", { fg = "#5e81ac" })
set("Special Character SpecialChar CursorMidnightCharacter", { fg = p.yellow })
set("Delimiter CursorMidnightPunctuation", { fg = p.white })
set("CursorMidnightDecorator", { fg = p.orange })
set("Todo", { fg = p.yellow, bg = p.bg })
set("Underlined", { fg = p.cyan, underline = true })
set("Ignore", { fg = p.faint })
link("Conditional Repeat Label Exception", "Statement")
link("Structure Typedef", "Type")
link("StorageClass Tag", "Keyword")
link("Include Define Macro PreCondit", "PreProc")
link("SpecialComment", "Comment")
link("Debug", "Special")

link("@comment @comment.documentation", "Comment")
link("@variable @variable.parameter", "Identifier")
link("@variable.member @property", "Type")
link("@type @type.builtin @type.definition @constructor @constant @constant.builtin", "Type")
link("@variable.builtin @keyword @operator", "Keyword")
link("@function @function.builtin @function.call @function.macro", "Function")
link("@function.method @function.method.call", "Function")
link("@string @string.documentation", "String")
link("@string.escape @character @character.special", "Character")
set("@string.regexp", { fg = p.yellow })
link("@number @number.float @boolean", "Number")
link("@punctuation.bracket @punctuation.delimiter @punctuation.special", "Delimiter")
link("@attribute @attribute.builtin", "CursorMidnightDecorator")
link("@module @module.builtin @label @tag @tag.builtin @tag.delimiter", "Keyword")
set("@tag.attribute", { fg = p.teal })
set("@markup.strong", { fg = p.fg, bold = true })
set("@markup.italic", { fg = p.fg, italic = true })
set("@markup.heading", { fg = p.cyan })
set("@markup.raw.block", { fg = p.fg })
set("@markup.quote", { fg = p.dim })
set("@markup.raw @markup.link.url", { fg = p.teal })
set("@markup.link @markup.link.label", { fg = p.cyan })
link("@markup.list", "Keyword")
link("@comment.error", "DiagnosticError")
link("@comment.warning @comment.todo", "DiagnosticWarn")
link("@comment.note", "DiagnosticInfo")

-- Semantic tokens must not erase contextual Tree-sitter field/variable colors.
link("@lsp.type.type @lsp.type.class @lsp.type.struct @lsp.type.enum @lsp.type.interface", "Type")
link("@lsp.type.typeParameter @lsp.type.typeAlias @lsp.type.builtinType @lsp.type.enumMember", "Type")
link("@lsp.type.function @lsp.type.method", "Function")
link("@lsp.type.keyword @lsp.type.operator @lsp.type.namespace", "Keyword")
link("@lsp.type.string", "String")
link("@lsp.type.number", "Number")
link("@lsp.type.decorator", "CursorMidnightDecorator")
set("@lsp.type.property @lsp.type.variable @lsp.type.parameter @lsp.type.comment", {})
for _, modifier in ipairs({
  "declaration",
  "definition",
  "readonly",
  "static",
  "deprecated",
  "abstract",
  "async",
  "modification",
  "documentation",
  "defaultLibrary",
}) do
  set("@lsp.mod." .. modifier, {})
end

local diagnostics = { Error = p.red, Warn = p.yellow, Info = p.cyan, Hint = p.teal, Ok = p.green }
for severity, color in pairs(diagnostics) do
  set("Diagnostic" .. severity, { fg = color })
  link("DiagnosticSign" .. severity .. " DiagnosticFloating" .. severity, "Diagnostic" .. severity)
  set("DiagnosticVirtualText" .. severity .. " DiagnosticVirtualLines" .. severity, { fg = color })
  set("DiagnosticUnderline" .. severity, { sp = color, undercurl = true })
end
set("DiagnosticUnnecessary", { fg = p.faint })
set("DiagnosticDeprecated", { sp = p.red, undercurl = true })
for group, color in pairs({ SpellBad = p.red, SpellCap = p.blue, SpellLocal = p.cyan, SpellRare = p.purple }) do
  set(group, { sp = color, undercurl = true })
end
set("DiffAdd", { bg = blend("#a3be8c22") })
set("DiffDelete", { fg = p.red, bg = blend("#bf616a22") })
set("DiffChange", { bg = blend("#81a1c14d") })
set("DiffText", { bg = blend("#81a1c166") })
set("Added GitSignsAdd", { fg = p.green })
set("Changed GitSignsChange", { fg = p.yellow })
set("Removed GitSignsDelete", { fg = p.red })

set("NeoTreeNormal NeoTreeNormalNC", { fg = p.sidebar, bg = p.terminal })
set("NeoTreeRootName", { fg = p.fg })
set(
  "NeoTreeDirectoryName NeoTreeDirectoryIcon NeoTreeFileName NeoTreeFileIcon NeoTreeSymbolicLinkTarget",
  { fg = p.sidebar }
)
set("NeoTreeExpander NeoTreeIndentMarker NeoTreeDotfile NeoTreeHiddenByName", { fg = p.sidebar })
set("NeoTreeGitModified NeoTreeGitConflict", { fg = p.yellow })
set("NeoTreeGitAdded NeoTreeGitUntracked", { fg = p.cyan })
set("NeoTreeGitDeleted", { fg = p.red })
set("NeoTreeGitIgnored", { fg = p.faint })
set("NeoTreeWinSeparator", { fg = blend("#ffffff0d", p.terminal), bg = p.terminal })
set("NeoTreeCursorLine", { bg = "#21242b" })
link("NeoTreeFloatBorder", "CursorMidnightTerminalBorder")
set(
  "TelescopeNormal TelescopePromptNormal TelescopeResultsNormal TelescopePreviewNormal",
  { fg = p.text, bg = p.terminal }
)
set(
  "TelescopeBorder TelescopePromptBorder TelescopeResultsBorder TelescopePreviewBorder",
  { fg = p.border, bg = p.terminal }
)
set("TelescopeSelection", { fg = p.white, bg = "#21242b" })
set("TelescopeMatching", { fg = p.cyan })
set("TelescopeSelectionCaret TelescopeMultiSelection", { fg = p.blue })
set(
  "TelescopePromptTitle TelescopeResultsTitle TelescopePreviewTitle TelescopePromptPrefix",
  { fg = p.fg, bg = p.terminal }
)
set(
  "MiniStatuslineModeNormal MiniStatuslineModeInsert MiniStatuslineModeVisual MiniStatuslineModeReplace MiniStatuslineModeCommand MiniStatuslineModeOther",
  { fg = p.fg, bg = p.terminal }
)
set(
  "MiniStatuslineDevinfo MiniStatuslineFileinfo MiniStatuslineFilename MiniStatuslineInactive",
  { fg = p.faint, bg = p.terminal }
)
set("CursorMidnightTerminal", { fg = p.text, bg = p.terminal })
set("CursorMidnightTerminalBorder", { fg = p.border, bg = p.terminal })
link("ToggleTermNormal", "CursorMidnightTerminal")
link("ToggleTermBorder", "CursorMidnightTerminalBorder")
set("CursorMidnightBracket1", { fg = p.gold })
set("CursorMidnightBracket2", { fg = p.orchid })
set("CursorMidnightBracket3", { fg = p.azure })

-- Preserve the source palette's exact normal and bright ANSI variants.
local ansi = {
  "#272c36",
  "#bf616a",
  "#a3be8c",
  "#ebcb8b",
  "#81a1c1",
  "#7d7c9b",
  "#88c0d0",
  "#e5e9f0",
  "#4c566a",
  "#bf616a",
  "#a3be8c",
  "#ebcb8b",
  "#81a1c1",
  "#b48ead",
  "#8fbcbb",
  "#eceff4",
}
for i, color in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
