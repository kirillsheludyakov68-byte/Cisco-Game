extends HBoxContainer
class_name ModuleInfoPanel

# Панель описания выбранного модуля на вкладке Physical.
# Слева — текст описания, справа — настраиваемая сцена ModulePreview.

@onready var description_label: Label = $DescriptionPanel/DescriptionMargin/DescriptionLabel
@onready var module_preview: ModulePreview = $ModulePreview

var current_module: String = ""


func show_module(module_name: String) -> void:
	current_module = module_name
	description_label.text = ModuleCatalog.get_description(module_name)
	module_preview.show_module(module_name)


func clear() -> void:
	current_module = ""
	description_label.text = ""
	module_preview.clear()
