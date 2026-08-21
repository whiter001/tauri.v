// menu.v — 自定义应用菜单栏（对应 Tauri 的 Menu API）
// 平台实现：macOS 见 menu_darwin.v（NSMenu 主菜单栏，替换默认菜单）；其他平台为桩（打印提示）。
//
// 数据模型：MenuDef 描述一个顶级菜单（title + 菜单项列表），
// set_menus 用一份 []MenuDef 整体替换应用菜单栏。
//
// 注意：macOS 会把第一个顶级菜单的标题强制显示为应用名（App 菜单约定），
// 但该菜单仍须在 set_menus 中显式声明，否则应用名菜单缺失。

module vtauri

// 快捷键修饰键位或常量（对应桥侧 setKeyEquivalentModifierMask 的位映射）。
pub const mod_cmd = 1 // Command（⌘）
pub const mod_shift = 2 // Shift（⇧）
pub const mod_alt = 4 // Option（⌥）
pub const mod_ctrl = 8 // Control（⌃）

// MenuItemDef 描述一个菜单项。separator=true 时为分隔线，忽略其它字段。
pub struct MenuItemDef {
pub:
	id        string // 点击回调回传的 id；与 action 二选一
	action    string // 系统 ObjC selector（如 'copy:'、'orderFrontStandardAboutPanel:'），target=nil 走 responder chain
	label     string // 显示文本
	key       string // 快捷键主键如 'q'，空 = 无
	mods      int    // mod_cmd|mod_shift|... 位或
	separator bool   // true = 分隔线，忽略其它字段
}

// MenuDef 描述一个顶级菜单。
pub struct MenuDef {
pub:
	title string
	items []MenuItemDef
}

// set_menus 完全替换应用菜单栏（macOS；须在 build() 之后调用）。
// 第一个菜单的标题会被系统强制显示为应用名（macOS 行为）。
// cb 收到点击项的 id；action 项不回传。非 macOS 打印提示。
pub fn (mut app App) set_menus(menus []MenuDef, cb fn (id string)) {
	$if macos {
		app.set_menus_darwin(menus, cb)
	} $else {
		eprintln('set_menus: custom app menu not supported on this platform')
	}
}
