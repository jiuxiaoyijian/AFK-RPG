extends RefCounted
class_name RuntimeTextureLoader


static func load_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null

	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	var import_sidecar_path: String = "%s.import" % absolute_path
	if FileAccess.file_exists(import_sidecar_path):
		var imported_resource: Resource = ResourceLoader.load(resource_path)
		if imported_resource is Texture2D:
			return imported_resource as Texture2D

	if not FileAccess.file_exists(absolute_path):
		return null

	var image: Image = Image.new()
	var err: Error = image.load(absolute_path)
	if err != OK:
		return null

	return ImageTexture.create_from_image(image)
