extends OptionButton

signal enum_selected(index: int)

func _init() -> void:
	item_selected.connect(on_item_selected)

func on_item_selected(index: int) -> void:
	enum_selected.emit(get_item_id(index))
