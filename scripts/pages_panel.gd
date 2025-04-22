func _on_page_button_pressed():
	var new_page = preload("res://scene/monitoring_page.tscn").instantiate()
	var page_container = get_node("HSplitContainer/ScrollContainer/PageContainer")

	page_container.get_children().map(func(child): child.queue_free())
	page_container.add_child(new_page)
