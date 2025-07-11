extends OptionButton

signal string_selected(string: String)

func _init() -> void:
	item_selected.connect(on_item_selected)

func on_item_selected(index: int) -> void:
	string_selected.emit(get_item_text(index))
