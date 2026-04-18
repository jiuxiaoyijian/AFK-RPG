extends RefCounted
class_name RuntimeTextureLoader


static func load_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null

	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	if _should_prefer_raw_image(resource_path):
		var raw_texture: Texture2D = _load_raw_image_texture(absolute_path)
		if raw_texture != null:
			return raw_texture

	var import_sidecar_path: String = "%s.import" % absolute_path
	if FileAccess.file_exists(import_sidecar_path):
		var imported_resource: Resource = ResourceLoader.load(resource_path)
		if imported_resource is Texture2D:
			return imported_resource as Texture2D

	return _load_raw_image_texture(absolute_path)


static func _should_prefer_raw_image(resource_path: String) -> bool:
	return resource_path.begins_with("res://assets/generated/")


static func _load_raw_image_texture(absolute_path: String) -> Texture2D:
	if not FileAccess.file_exists(absolute_path):
		return null

	var image: Image = Image.new()
	var err: Error = image.load(absolute_path)
	if err != OK:
		return null

	return ImageTexture.create_from_image(image)
