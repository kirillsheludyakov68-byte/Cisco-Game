extends MarginContainer
class_name ConfigPanel

const SECTION_SETTINGS := "settings"
const SECTION_INTERFACE := "interface"

@onready var nav_panel: PanelContainer = $Root/NavPanel
@onready var global_header_button: Button = $Root/NavPanel/NavScroll/NavList/GlobalHeaderButton
@onready var global_items: VBoxContainer = $Root/NavPanel/NavScroll/NavList/GlobalItems
@onready var settings_button: Button = $Root/NavPanel/NavScroll/NavList/GlobalItems/SettingsButton
@onready var interface_header_button: Button = $Root/NavPanel/NavScroll/NavList/InterfaceHeaderButton
@onready var interface_items: VBoxContainer = $Root/NavPanel/NavScroll/NavList/InterfaceItems
@onready var global_page: GlobalSettingsPage = $Root/PageStack/GlobalSettingsPage
@onready var interface_page_host: Control = $Root/PageStack/InterfacePageHost

var device: Device = null
var selected_interface_name: String = ""
var current_section: String = SECTION_SETTINGS

# Состояния групп независимы. Свёрнутая группа скрывает только свои пункты.
var global_expanded: bool = true
var interface_expanded: bool = true

var _nav_group: ButtonGroup
var _interface_buttons: Dictionary = {}
var _interface_page: Control = null
var _interface_page_path: String = ""


func _ready() -> void:
	_apply_styles()
	_nav_group = ButtonGroup.new()
	_nav_group.allow_unpress = false
	settings_button.button_group = _nav_group
	settings_button.button_pressed = true

	settings_button.pressed.connect(_on_settings_pressed)
	global_header_button.pressed.connect(_toggle_global_group)
	interface_header_button.pressed.connect(_toggle_interface_group)
	global_page.interface_selected.connect(_on_interface_selected_from_settings)
	_apply_group_visibility()


func setup(dev: Device) -> void:
	if device != null and device.interfaces_changed.is_connected(_on_interfaces_changed):
		device.interfaces_changed.disconnect(_on_interfaces_changed)

	device = dev
	if device != null and not device.interfaces_changed.is_connected(_on_interfaces_changed):
		device.interfaces_changed.connect(_on_interfaces_changed)

	_free_interface_page()
	selected_interface_name = ""
	if device != null and not device.interfaces.is_empty():
		selected_interface_name = device.interfaces[0].interface_name

	_build_interface_nav()
	global_page.setup(device, selected_interface_name)
	_show_settings()


func refresh() -> void:
	refresh_interfaces()


func refresh_interfaces() -> void:
	if device == null:
		selected_interface_name = ""
		_build_interface_nav()
		return

	if selected_interface_name.is_empty() or device.get_interface(selected_interface_name) == null:
		selected_interface_name = (
			device.interfaces[0].interface_name if not device.interfaces.is_empty() else ""
		)

	_build_interface_nav()

	if current_section == SECTION_SETTINGS:
		global_page.set_selected_interface(selected_interface_name)
		global_page.refresh()
		return

	var iface := device.get_interface(selected_interface_name)
	if iface == null:
		_show_settings()
		return
	_display_interface(iface)


func commit_pending() -> void:
	_commit_current_section()


func _build_interface_nav() -> void:
	for child in interface_items.get_children():
		interface_items.remove_child(child)
		child.queue_free()
	_interface_buttons.clear()

	if device != null:
		for iface in device.interfaces:
			var button := Button.new()
			button.text = iface.interface_name
			button.toggle_mode = true
			button.button_group = _nav_group
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			PanelNavStyles.apply_item_button(
				button,
				global_header_button.get_theme_font("font"),
				HORIZONTAL_ALIGNMENT_LEFT
			)
			button.pressed.connect(_on_interface_button_pressed.bind(iface.interface_name))
			interface_items.add_child(button)
			_interface_buttons[iface.interface_name] = button

	if _interface_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Нет интерфейсов"
		empty_label.custom_minimum_size = Vector2(0, PanelNavStyles.ITEM_HEIGHT)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ConfigStyles.apply_label(empty_label, 12, true)
		interface_items.add_child(empty_label)

	_update_nav_selection()


func _update_nav_selection() -> void:
	for interface_name in _interface_buttons:
		var button: Button = _interface_buttons[interface_name]
		button.button_pressed = (
			current_section == SECTION_INTERFACE
			and interface_name == selected_interface_name
		)
	if current_section == SECTION_SETTINGS:
		settings_button.button_pressed = true


func _toggle_global_group() -> void:
	global_expanded = not global_expanded
	_apply_group_visibility()


func _toggle_interface_group() -> void:
	interface_expanded = not interface_expanded
	_apply_group_visibility()


func _apply_group_visibility() -> void:
	global_items.visible = global_expanded
	interface_items.visible = interface_expanded


func _on_settings_pressed() -> void:
	_show_settings()


func _show_settings() -> void:
	_commit_current_section()
	current_section = SECTION_SETTINGS
	global_page.visible = true
	interface_page_host.visible = false
	settings_button.button_pressed = true
	global_page.set_selected_interface(selected_interface_name)
	global_page.refresh()
	_update_nav_selection()


func _on_interface_button_pressed(interface_name: String) -> void:
	_show_interface(interface_name)


func _show_interface(interface_name: String) -> void:
	if device == null:
		return
	var iface := device.get_interface(interface_name)
	if iface == null:
		refresh_interfaces()
		return

	_commit_current_section()
	_display_interface(iface)


func _display_interface(iface: DeviceInterface) -> void:
	if device == null or iface == null:
		return

	current_section = SECTION_INTERFACE
	selected_interface_name = iface.interface_name
	global_page.set_selected_interface(selected_interface_name)

	_ensure_interface_page(iface.source_module)
	if _interface_page != null and _interface_page.has_method("setup"):
		_interface_page.setup(device, iface, iface.source_module)

	global_page.visible = false
	interface_page_host.visible = true
	_update_nav_selection()


func _on_interface_selected_from_settings(interface_name: String) -> void:
	selected_interface_name = interface_name
	if current_section == SECTION_INTERFACE:
		var iface := device.get_interface(interface_name) if device != null else null
		if iface != null:
			_display_interface(iface)


func _on_interfaces_changed() -> void:
	refresh_interfaces()


func _ensure_interface_page(source_module: String) -> void:
	var page_scene := ConfigPageRegistry.get_page_scene(source_module)
	if page_scene == null:
		return

	var path := page_scene.resource_path
	if _interface_page != null and _interface_page_path == path:
		return

	_free_interface_page()
	_interface_page = page_scene.instantiate()
	_interface_page_path = path
	_interface_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface_page_host.add_child(_interface_page)


func _free_interface_page() -> void:
	if _interface_page == null:
		return
	if _interface_page.get_parent() != null:
		_interface_page.get_parent().remove_child(_interface_page)
	_interface_page.queue_free()
	_interface_page = null
	_interface_page_path = ""


func _commit_current_section() -> void:
	if current_section == SECTION_SETTINGS:
		global_page.commit_pending()
	elif _interface_page != null and _interface_page.has_method("commit_pending"):
		_interface_page.commit_pending()


func _apply_styles() -> void:
	nav_panel.add_theme_stylebox_override("panel", PanelNavStyles.make_panel_style())
	PanelNavStyles.apply_header_button(global_header_button)
	PanelNavStyles.apply_header_button(interface_header_button)
	PanelNavStyles.apply_item_button(
		settings_button,
		global_header_button.get_theme_font("font"),
		HORIZONTAL_ALIGNMENT_LEFT
	)
