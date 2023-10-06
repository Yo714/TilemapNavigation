extends NavigationRegion2D

@export var tileMap: TileMap

func _ready():
	spawn_navigation_mesh()
	refresh_navigation_mesh()

func spawn_navigation_mesh():
	var navigationMesh: Array[PackedVector2Array] = []
	var allMergePolygon: Array[PackedVector2Array] = []
	var polygon: NavigationPolygon = get_navigation_polygon()
	var allTile: Array = tileMap.get_used_cells(0)
	allTile.sort_custom(func(a, b): return a[0] < b[0])
	for tile in allTile:
		var tileRegion: Vector2 = tileMap.map_to_local(tile)
		var tileTransform: Transform2D = Transform2D(Vector2(1,0), Vector2(0,1), -tileRegion)
		var polygonBp: PackedVector2Array = tileMap.get_cell_tile_data(0, tile).get_navigation_polygon(0).get_vertices()
		var polygonTile: PackedVector2Array  = polygonBp * tileTransform
		if navigationMesh.is_empty():
			navigationMesh.append(polygonTile)
		else:
			allMergePolygon = merge_polygon(navigationMesh, polygonTile)
			if navigationMesh == allMergePolygon:
				break
			navigationMesh.clear()
			navigationMesh.append_array(allMergePolygon)
	print(navigationMesh)
	polygon.clear_outlines()
	for navigation in navigationMesh:
		polygon.add_outline(navigation)
	
func refresh_navigation_mesh():
	var allPolygonOutline: Array[PackedVector2Array] = []
	var allMergePolygon: Array[PackedVector2Array] = []
	var allClipPolygons: Array[PackedVector2Array] = []
	var initialOutlines: Array[PackedVector2Array] = []
	
	var polygon: NavigationPolygon = get_navigation_polygon()
	var allChildren = get_all_children(tileMap)
	print(allChildren)
	var collisionPolygonNodes: Array = get_collision_polygon_nodes(allChildren)
	for i in polygon.get_outline_count():
		initialOutlines.append(polygon.get_outline(i))
		
	for polygonNode in collisionPolygonNodes:
		var collisionTransform: Transform2D = polygonNode.get_global_transform()
		var collisionPolygon: PackedVector2Array = polygonNode.get_polygon()
#		var collisionPolygonOffset: Array[PackedVector2Array] = Geometry2D.offset_polygon(collisionPolygon, 25, Geometry2D.JOIN_MITER)
		var collisionPolygonOutline: PackedVector2Array = collisionTransform * collisionPolygon
		allPolygonOutline.append(collisionPolygonOutline)
	
	if not allPolygonOutline.is_empty():
		for num in allPolygonOutline.size():
			var firstPolygon = allPolygonOutline.pop_front()
			allMergePolygon = merge_polygon(allPolygonOutline, firstPolygon)
			allPolygonOutline.clear()
			for mergePolygon in allMergePolygon:
				allPolygonOutline.append(mergePolygon)
				
		for mergePolygonChild in allMergePolygon:
			for initialOutline in initialOutlines:
				if is_vertex_in_initial_outline(mergePolygonChild, initialOutline):
					var clipPolygon: Array[PackedVector2Array] = Geometry2D.clip_polygons(initialOutline, mergePolygonChild)
					initialOutlines.erase(initialOutline)
					initialOutlines.append(clipPolygon.front())
					if clipPolygon.size() != 1:
						allClipPolygons.append(clipPolygon.back())
					break
					
	polygon.clear_outlines()
	for initialOutline in initialOutlines:
		polygon.add_outline(initialOutline)
	for clipPolygon in allClipPolygons:
		polygon.add_outline(clipPolygon)
	polygon.make_polygons_from_outlines()
	set_navigation_polygon(polygon)

func get_collision_polygon_nodes(allChildren: Array) -> Array:
	var collisionPolygonNodes = []

	for child in allChildren:
		if child.is_in_group("NavigationArea"):
			child = child.get_child(0)
			collisionPolygonNodes.append(child)

	return collisionPolygonNodes

func merge_polygon(newAllPolygonOutline: Array[PackedVector2Array], newPolygon: PackedVector2Array):
	var allMergePolygon: Array[PackedVector2Array] = []
	if newAllPolygonOutline.is_empty():
		allMergePolygon.append(newPolygon)
	else:
		for polygonOutline in newAllPolygonOutline:

			var isPointInPolygon = false
			for vertex in newPolygon:
				if Geometry2D.is_point_in_polygon(vertex, polygonOutline):
					var mergePolygon = Geometry2D.merge_polygons(polygonOutline, newPolygon)
					newPolygon.clear()
					newPolygon.append_array(mergePolygon.pop_front())
					while mergePolygon.size() > 0:
						allMergePolygon.append(mergePolygon.pop_front())
					isPointInPolygon = true
					break
			if isPointInPolygon:
				pass
			else:
				allMergePolygon.append(polygonOutline)
		allMergePolygon.append(newPolygon)
	return allMergePolygon
	
func is_vertex_in_initial_outline(mergePolygon: PackedVector2Array, initialOutline: PackedVector2Array):
	for vertex in mergePolygon:
		if Geometry2D.is_point_in_polygon(vertex, initialOutline):
			return true
	return false

func get_all_children(node: Node):
	var retVal: Array[Node] = []
	for child in node.get_children():
		retVal.push_back(child)
		if child.get_child_count() > 0:
			retVal.append_array(get_all_children(child))
	return retVal
