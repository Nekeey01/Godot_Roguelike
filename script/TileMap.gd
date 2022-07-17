extends TileMap

# Вы можете создать узел AStar только из кода, а не из вкладки Scene
onready var astar_node = AStar2D.new()
# Узел Tilemap не имеет четких границ, поэтому мы определяем здесь пределы карты.
var map_size = Vector2(100, 100)

# Переменные начала и конца пути используют методы установки
# Вы можете найти их внизу скрипта 
var path_start_position = Vector2() setget _set_path_start_position
var path_end_position = Vector2() setget _set_path_end_position

var _point_path = []

const BASE_LINE_WIDTH = 10.0
const DRAW_COLOR = Color('#fff')

# get_used_cells_by_id - метод из узла TileMap
# здесь id 0 соответствует серой плитке, препятствия
var obstacles #= get_used_cells_by_id(0)
var _half_cell_size #= cell_size / 2
var free_points = []

var index_arr = []


func Astar_run(point_arr, size_map):
	map_size = size_map
	obstacles = get_used_cells_by_id(0)
	free_points = point_arr
	_half_cell_size = cell_size / 2
#	var walkable_cells_list = astar_add_walkable_cells(obstacles)
#	astar_connect_walkable_cells(walkable_cells_list)

	astar_add_walkable_cells_my(point_arr)
	astar_connect_walkable_cells(point_arr)
	
##############################################################
func astar_add_walkable_cells_my(point_arr):
	for point in point_arr:
		var point_index = calculate_point_index(point)
#		index_arr.append(point)
		astar_node.add_point(point_index, Vector2(point.x, point.y))


###############################################################

# Перебирает все ячейки в пределах карты и
# добавляет все точки к astar_node, кроме препятствий
func astar_add_walkable_cells(obstacles = []):
	var points_array = []
	for y in range(map_size.y):
		for x in range(map_size.x):
			var point = Vector2(x, y)
			if point in obstacles:
				continue

			points_array.append(point)
			# Класс AStar ссылается на точки с индексами
# Использование функции для вычисления индекса по координатам точки
# гарантирует, что мы всегда получим один и тот же индекс с одной и той же входной точкой
			var point_index = calculate_point_index(point)
			# AStar работает как для 2d, так и для 3d, поэтому мы должны преобразовать точку
# координаты от и до Vector3s
			astar_node.add_point(point_index, Vector2(point.x, point.y))
	
	
	return points_array


# После того, как вы добавили все точки в узел AStar, вам нужно их подключить.
# Точки не обязательно должны быть на сетке: вы можете использовать этот класс
# для создания удобных графиков, как вы хотите
# Сначала это немного сложнее кодировать, но работает для 2d, 3d,
# ортогональные сетки, шестиугольные сетки, игры в жанре Tower Defense ...
func astar_connect_walkable_cells(points_array):
	for point in points_array:
		var point_index = calculate_point_index(point)
		# Для каждой ячейки на карте мы проверяем одну вверху справа. 
		# слева и внизу. Если он на карте, а не препятствие, 
		# Связываем с ним текущую точку
		var points_relative = PoolVector2Array([
			Vector2(point.x + 1, point.y),
			Vector2(point.x - 1, point.y),
			Vector2(point.x, point.y + 1),
			Vector2(point.x, point.y - 1)])
		for point_relative in points_relative:
			var point_relative_index = calculate_point_index(point_relative)

			if is_outside_map_bounds(point_relative):
				continue
			if not astar_node.has_point(point_relative_index):
				continue
			# Обратите внимание на третий аргумент. Он сообщает astar_node, что мы хотим
# соединение должно быть двусторонним: от точки A к B и B к A
# Если вы установите это значение в false, это станет односторонним путем
# По мере того, как мы перебираем все точки, мы можем установить для него значение false
			astar_node.connect_points(point_index, point_relative_index, false)


# Это вариант описанного выше метода.
# Соединяет ячейки по горизонтали, вертикали и диагонали
func astar_connect_walkable_cells_diagonal(points_array):
	for point in points_array:
		var point_index = calculate_point_index(point)
		for local_y in range(3):
			for local_x in range(3):
				var point_relative = Vector2(point.x + local_x - 1, point.y + local_y - 1)
				var point_relative_index = calculate_point_index(point_relative)

				if point_relative == point or is_outside_map_bounds(point_relative):
					continue
				if not astar_node.has_point(point_relative_index):
					continue
				astar_node.connect_points(point_index, point_relative_index, true)


func is_outside_map_bounds(point):
	return point.x < 0 or point.y < 0 or point.x >= map_size.x or point.y >= map_size.y


func calculate_point_index(point):
#	print("calculate_point_index - ", point.x + map_size.x * point.y)
	return point.x + map_size.x * point.y


func find_path(world_start, world_end):
	self.path_start_position = world_to_map(world_start)
	self.path_end_position = world_to_map(world_end)
	_recalculate_path()
	var path_world = []
	for point in _point_path:
		var point_world = map_to_world(Vector2(point.x, point.y)) + _half_cell_size
		path_world.append(point_world)
		
	
	return path_world

var old_point_path

var test_err : PoolVector2Array = []
func _recalculate_path():
	old_point_path = _point_path
	clear_previous_path_drawing()
	var start_point_index = calculate_point_index(path_start_position)
	var end_point_index = calculate_point_index(path_end_position)
	# Этот метод дает нам массив точек. Обратите внимание, вам нужно начало и конец
	#Индексы точек в качестве входных
	

	_point_path = astar_node.get_point_path(start_point_index, end_point_index)
#	print("_point_path - ", _point_path)
	if _point_path == test_err:
		_point_path = old_point_path
	
	for i in _point_path:
		set_cellv(Vector2(i.x, i.y),2)
	# Перерисуйте линии и круги от начальной до конечной точки
#	update()


func clear_previous_path_drawing():
	if not _point_path:
		return
	var point_start = _point_path[0]
	var point_end = _point_path[len(_point_path) - 1]
#	set_cell(point_start.x, point_start.y, -1)
#	set_cell(point_end.x, point_end.y, -1)


func _draw():
	if not _point_path:
		return
	var point_start = _point_path[0]
	var point_end = _point_path[len(_point_path) - 1]

#	set_cell(point_start.x, point_start.y, 1)
#	set_cell(point_end.x, point_end.y, 2)

	var last_point = map_to_world(Vector2(point_start.x, point_start.y)) + _half_cell_size
	for index in range(1, len(_point_path)):
		var current_point = map_to_world(Vector2(_point_path[index].x, _point_path[index].y)) + _half_cell_size
#		draw_line(last_point, current_point, DRAW_COLOR, BASE_LINE_WIDTH, false)
#		draw_circle(current_point, BASE_LINE_WIDTH * 2.0, DRAW_COLOR)
		set_cellv(last_point,2)
		last_point = current_point


# Установщики значений начального и конечного пути.
func _set_path_start_position(value):
#	if value in obstacles:
#		return
	if is_outside_map_bounds(value):
		return

#	set_cell(path_start_position.x, path_start_position.y, -1)
#	set_cell(value.x, value.y, 1)
	path_start_position = value
	if path_end_position and path_end_position != path_start_position:
		_recalculate_path()


func _set_path_end_position(value):
#	if value in obstacles:
#		return
	if is_outside_map_bounds(value):
		return

#	set_cell(path_start_position.x, path_start_position.y, -1)
#	set_cell(value.x, value.y, 2)
	path_end_position = value
	if path_start_position != value:
		_recalculate_path()
