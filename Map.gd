extends Spatial

var cam_speed = 0.5
var cam_acceleration = 10.0
var cam_direction = Vector3(0.0, 0.0, 0.0)
var cam_velocity = Vector3(0.0, 0.0, 0.0)

var hiddenmap_data = null
var last_mouse_pos3D = null

var ColorRGB = []
var province_name
var provinces_json

func _ready():
	
	# Load provinces json file
	var provinces_file
	provinces_file = File.new()
	provinces_file.open("res://provinces.json", File.READ)
	provinces_json = JSON.parse(provinces_file.get_as_text())
	provinces_file.close()

	# Load and lock map for selection
	var temp_texture = ImageTexture.new()
	var temp_image = Image.new()
	
	temp_image.load("res://map_test1_provinces.bmp")
	temp_texture.create_from_image(temp_image)
	hiddenmap_data = temp_texture.get_data()
	hiddenmap_data.lock()
	
	# Adding debug info to the overlay
	var overlay = load("res://debug_overlay.tscn").instance()
	overlay.add_stat("Color of pixel", self, "ColorRGB", false)
	overlay.add_stat("Province", self, "province_name", false)
	add_child(overlay)

func _physics_process(delta):
	# Define -1 to +1 direction changes
	cam_direction.x = (-int(Input.is_action_pressed("map_left")) + int(Input.is_action_pressed("map_right")))
	cam_direction.y = (-int(Input.is_action_pressed("map_down")) + int(Input.is_action_pressed("map_up")))
	cam_direction.z = (-int(Input.is_action_pressed("map_zoom_in")) + int(Input.is_action_pressed("map_zoom_out")))
	cam_direction = cam_direction.normalized()
	
	# Interpolate velocity and modify cam position
	cam_velocity = cam_velocity.linear_interpolate(cam_direction * cam_speed, cam_acceleration * delta)
	$Camera.transform.origin += cam_velocity

func _unhandled_input(event):
	# Handling both hover and click
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if hiddenmap_data == null: return false
		# Get mesh size to detect edges and make conversions
		# This code only support PlaneMesh and QuadMesh
		var quad_mesh_size = $BackgroundColored/MeshInstance.mesh.size
		
		# Find mouse position in Area
		var from = $Camera.project_ray_origin(event.global_position)
		var dist = 100
		var to = from + $Camera.project_ray_normal(event.global_position) * dist
		var result = get_world().direct_space_state.intersect_ray(from, to, [], $BackgroundColored/MeshInstance/Area.collision_layer,false,true)
		var mouse_pos3D = null
		if result.size() > 0: mouse_pos3D = result.position
		# Check if the mouse is outside of bounds, use last position to avoid errors
		var is_mouse_inside = mouse_pos3D != null
		if is_mouse_inside:
			# Convert click_pos from world coordinate space to a coordinate space
			mouse_pos3D = $BackgroundColored/MeshInstance/Area.global_transform.affine_inverse() * mouse_pos3D
			last_mouse_pos3D = mouse_pos3D
		else:
			mouse_pos3D = last_mouse_pos3D
			if mouse_pos3D == null:
				mouse_pos3D = Vector3.ZERO

		# Convert the relative event position from 3D to 2D
		# Could do one-liner but here split for readability
		var mouse_pos2D = Vector2(mouse_pos3D.x, -mouse_pos3D.y)
		mouse_pos2D.x += quad_mesh_size.x / 2.0
		mouse_pos2D.y += quad_mesh_size.y / 2.0
		mouse_pos2D.x = mouse_pos2D.x / (quad_mesh_size.x)
		mouse_pos2D.y = mouse_pos2D.y / (quad_mesh_size.y)
		mouse_pos2D.x = mouse_pos2D.x * 4084.0
		mouse_pos2D.y = mouse_pos2D.y * 3056.0

		# Finally, detect color
		var pxColour = hiddenmap_data.get_pixel(int(mouse_pos2D.x), int(mouse_pos2D.y))
		ColorRGB = [pxColour.r8, pxColour.g8, pxColour.b8]
		
		# Detect province name 
		var prov_data
		prov_data = provinces_json.result

		for id in range(8):
			if ColorRGB[0] == prov_data["%s" % id].r8 and ColorRGB[1] == prov_data["%s" % id].g8 and ColorRGB[2] == prov_data["%s" % id].b8:
				province_name = prov_data["%s" % id].name
			
		

			# Watch out with Sprite3D depth-sorting
			# It's precise mainly when alpha cut is set to discard
			# Other options (eg. disable) prohibit close z pos between map and selection sprite
			
			
