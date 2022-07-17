extends Node2D

const Player = preload("res://scene/Player.tscn")
const Exit = preload("res://scene/ExitDoor.tscn")
const Wolf = preload("res://scene/Wolf.tscn")
const Enemy = preload("res://scene/Enemy.tscn")
const GUI = preload("res://scene/GUI.tscn")

var size_map:Vector2 = Vector2(100,100)
var player
var wolf

var borders = Rect2(1, 1, size_map.x, size_map.y)
var _rng = RandomNumberGenerator.new()

onready var tileMap = $TileMap

var bar

const DIRECTIONS: Array = [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]

var step_history:Array = [] # массив с клетками свободными
var rooms =[]
var rooms_history = []
var rooms_count = 0
var all_rooms_count = 0


#########
# процент "поворота", наверное
var windingPercent = 40
#Обратный шанс добавления коннектора между двумя регионами, которые  уже были соединены. 
#Увеличение этого числа ведет к более слабосвязанным  подземельям.
var extraConnectorChance = 2

#карта мапы
var _regions:Array

# Лог, для просмотра, сколько раз запустился алгоритм лабиринта
var schet_maze = 0
# The index of the current region being carved.
var _currentRegion = -1



##############################################




#############################################
func _ready():
	generate_level()

func generate_level():
	_rng.randomize()
	for x in range(0, borders.size.x+1):
		for y in range(0, borders.size.y+1):
			tileMap.set_cell(x,y, 0)

#	tileMap.update_bitmask_region(borders.position, borders.end)
	tileMap.update_dirty_quadrants()
	walk()
	create_wolf()
	create_wolf()
	create_wolf()
	create_exit()
	create_player()
	
	tileMap.Astar_run(step_history, size_map)
	
func create_wolf():
	## Создание игрока
	wolf = Enemy.instance()
	add_child(wolf)
	wolf.position = step_history[_rng.randi() % step_history.size()]*32
#	wolf.position = rooms[_rng.randi() % rooms.size()]*32

	wolf.old_pos_player = step_history.front()*32
	wolf.connect("hit", self, "hit_player")
	
	
var text_hp
func create_player():
	## Создание игрока
	player = Player.instance()
	add_child(player)
	player.position = step_history.front()*32

	bar = player.get_node("Camera2D/GUI/MarginContainer/HBoxContainer/Bars/Bar/HP")
	text_hp = player.get_node('Camera2D/GUI/MarginContainer/HBoxContainer/Bars/Bar/Count/Background/Number')
	

#	player.position = step_history[_rng.randi() % step_history.size()]*32
	
#func create_exit(walker):
func create_exit():

	## Создание комнаты выхода
	var exit = Exit.instance()
	add_child(exit)
#	exit.position = walker.get_end_room().position*32
#	exit.position = step_history.back()*32
	exit.position = step_history[_rng.randi() % step_history.size()]*32
	exit.connect("leaving_level", self, "reload_level")
	
	
func reload_level():
	get_tree().reload_current_scene()


func hit_player(damage):
	player.hp -= damage
	text_hp.text = str(int(text_hp.text) - damage)
	bar.value -= damage
	if player.hp <= 0:
		reload_level()
	
func _input(event):
	if event.is_action_pressed("reload"):
		reload_level()

## Создание комнаты
func make_rooms(max_rooms):
#	_rng.randomize()
	for r in range(max_rooms):
		#случайный размер
		var size = Vector2(randi() % 8 +4, randi() % 8 +4)
		#случайное положение без выхода за границы карты		
		var x = _rng.randi_range(3, borders.size.x - size.x - 2)
		var y = _rng.randi_range(3, borders.size.y - size.y - 2)
		
#		var size = Vector2(3,3)
		
		var pos_room:Vector2 = Vector2(x,y)
		var new_room:Rect2 = Rect2(x, y, size[0], size[1])
		var failed = false
		for other_room in rooms:
			if new_room.intersects(other_room.grow(3), true):
				failed = true
				break
		if not failed and can_place_room(new_room.grow(-1)):
			_startRegion()
			place_room(new_room)
			rooms.append(new_room)

#		else:
#			max_rooms+=1

var first_tile:Vector2
var last_tile:Vector2


## сама постройка
func walk():
	_rng.randomize()
	schet_maze = 0
#	Создание двумерного массива _regions
	var dop_reg = []
	for y in borders.size.y:
#		dop_reg.append(y)
		for x in borders.size.x:
			_regions.append(null)

	make_rooms(7)
#	print("создалось комнат - ", all_rooms_count)	

	## 
	for y in range(1, borders.size.y, 2):
		for x in range(1, borders.size.x, 2):
			var pos = Vector2(x, y)

#			Если клетка уже вырезана, то продолжить. Иначе делать лабиринт.
			if (tileMap.get_cellv(pos) != 0):
				 continue
			_growMaze(pos);

			tileMap.update_bitmask_region(borders.position, borders.end)

## Удалить клетки в комнате, к которым невозможно попасть (в углах)
	_removeDeadEndsInRooms()
	tileMap.update_bitmask_region(borders.position, borders.end)

## Добавить двери на каждой стороне двери
	add_doors()
	tileMap.update_bitmask_region(borders.position, borders.end)

##	Функция для соеденения коридоров и создания дверей
	_connectRegions()
#	print("кол-во добавленных проходов - ", kk)
	tileMap.update_dirty_quadrants()


## Удалить концы коридоров
	_removeDeadEnds()
	tileMap.update_bitmask_region(borders.position, borders.end)


## Удаляем одиночные стены
	_removeDeadWall()
	tileMap.update_bitmask_region(borders.position, borders.end)


## Удаляем одиночные свободные клетки
	_removeDeadFloor()
	tileMap.update_bitmask_region(borders.position, borders.end)
	
	

## Определение дистанции до объекта
func distanceTo(source, other):
	var dx = source.x - other.x;
	var dy = source.y - other.y;
	return sqrt(dx * dx + dy * dy);

## Если комната рядом - то true
func room_is_close(source) -> bool:
	for cell in rooms:
		if distanceTo(source, cell['position']) <= 2:
			return true
	return false
	
## Проверка то, можно ли разместить комнату. Проверяется каждая клетка. Если можно - true
func can_place_room(room) -> bool:
	var room_pos: Vector2 = room.position
	## адд в список для отрисовки координаты комнаты
	for x in room.size.x:
		for y in room.size.y:
			## По сути начиная с левого верхнего угла (наверное)
			var jopa = room_pos+Vector2(x,y)
			if borders.has_point(jopa) and tileMap.get_cellv(jopa) == 0:
				return true
	return false

## создание комнаты
func place_room(room):
	all_rooms_count += 1
	rooms_count +=1
	var size = room["size"]
	var room_pos: Vector2 = room.position
	## адд в список для отрисовки координаты комнаты
	for x in room.size.x:
		for y in room.size.y:
			## По сути начиная с левого верхнего угла (наверное)
			var jopa = room_pos+Vector2(x,y)
			if borders.has_point(jopa):
				tileMap.set_cellv(jopa,1)
				_regions[jopa.x * jopa.y] = _currentRegion;
				step_history.append(jopa)
				rooms_history.append(jopa)


## Получить последнюю комнату
func get_end_room():
	var end_room = rooms.pop_front()
	var starting_position = step_history.front()
	for room in rooms:
		if starting_position.distance_to(room.position) > starting_position.distance_to(end_room.position):
			end_room = room
	return end_room	
	
func add_doors():
	for room in rooms:
		var cell_for_door_x_down:Array
		var cell_for_door_x_up:Array
		var cell_for_door_y_left:Array
		var cell_for_door_y_right:Array
		
		var room_first_x = room.position.x 
		var room_last_x = room.end.x
		var room_first_y = room.position.y
		var room_last_y = room.end.y
		
		for x in range(room_first_x, room_last_x):
			if tileMap.get_cell(x,room_first_y-2) == 1:
				cell_for_door_x_up.append(Vector2(x,room_first_y-1))
				
			if tileMap.get_cell(x,room_last_y+1) == 1:
				cell_for_door_x_down.append(Vector2(x,room_last_y))
				

		for y in range(room_first_y, room_last_y):
			if tileMap.get_cell(room_first_x-2,y) == 1:
				cell_for_door_y_left.append(Vector2(room_first_x-1,y))
				
			if tileMap.get_cell(room_last_x+1,y) == 1:
				cell_for_door_y_right.append(Vector2(room_last_x,y))

		
		if not cell_for_door_x_down.empty():
			_addJunction(cell_for_door_x_down[randi()%cell_for_door_x_down.size()])
			
		if not cell_for_door_x_up.empty():
			_addJunction(cell_for_door_x_up[randi()%cell_for_door_x_up.size()])
			
		if not cell_for_door_y_left.empty():
			_addJunction(cell_for_door_y_left[randi()%cell_for_door_y_left.size()])
			
		if not cell_for_door_y_right.empty():
			_addJunction(cell_for_door_y_right[randi()%cell_for_door_y_right.size()])

	
	
## Постройка лабиринта
func _growMaze(start:Vector2):
	var cells:Array
	var lastDir

	_startRegion()
	step(start)
	schet_maze += 1
	print("Кол-во запусков алгоритма лабиринта - ", schet_maze)
	
	cells.append(start)
	
	## Пока клетки не пустые
	while not cells.empty():
		## Тест варик
#		var kek = cells.back()
#		if _rng.randi_range(0,3) == 0:
#			kek = cells[_rng.randi_range(0,cells.size()-1)]
#		if _rng.randi_range(0,4) == 0:
#			kek = cells.front()
		
		
		## 1 тип лабиринта - говно
#		var kek =cells.front()
		
		
		## 2 тип лабиринта
		var kek = cells.back()
		if _rng.randi_range(0,4) == 0:
			kek = cells[_rng.randi_range(0,cells.size()-1)]

		## 3 тип лабиринта
#		var kek = cells.back();

		var cell = kek
#		See which adjacent cells are open.
		var unmadeCells:Array

		## Выбор направления
		for dir in DIRECTIONS:
			if (_canCarve(cell, dir)):
				unmadeCells.append(dir);

		## Если есть пустые клетки
		if not unmadeCells.empty():
			## Если следующая по направлению клетка пустая и рандом число > windingPercent
			## то направление = прошлому направлению. Иначе направление - случайная незаполненная клетка
			var dir
			if (unmadeCells.has(lastDir) and _rng.randi()%100+1 > windingPercent):
			  dir = lastDir;
			else:
			  dir = unmadeCells[_rng.randi() % unmadeCells.size()]

			## Создание клетки на каждом шаге
			step(cell + dir);
			## И через шаг
			step(cell + dir * 2);

			cells.append(cell + dir * 2);
			lastDir = dir;
			
		else:
#			No adjacent uncarved cells.
#			cells.pop_back()
			cells.erase(kek)

#			 This path has ended.
			lastDir = null;


## Можно ли вырезать
func _canCarve(pos:Vector2, direction) -> bool:
#	// Must end in bounds.

	var dop_pos = pos + direction * 3
	if not borders.has_point(dop_pos):
		return false

## Проверка, чтобы коридоры лабиринта не заходили к комнатам.
	for room in rooms:
		if room.grow(1).has_point(pos+direction*2):
			return false
	# Если стена, то можно вырезать
	var dop_pos_2 = pos + direction * 2

	return tileMap.get_cellv(dop_pos_2) == 0
		


  
## Шаг
func step(pos:Vector2):
#	## Добавление в список на отрисовку
	step_history.append(pos)
	tileMap.set_cellv(pos,1)
	_regions[pos.x*pos.y] = _currentRegion;
	tileMap.update_dirty_quadrants()
	


var openRegions:Array
var connectors:Array
var connectorRegions:Dictionary


func _connectRegions():
#	Найдите все плитки, которые могут соединить два (или более) региона.
	connectorRegions = {}
	
	## Позиции внутри игрвого квадрата
	for y in range(1, borders.size.y):
		for x in range(1,borders.size.x):
			var pos = Vector2(x, y)
#	Уже не может быть частью региона
#			Если клетка свободна, то в жопу ее 
			if tileMap.get_cellv(pos)!=0:
				continue

			var regions:Array = []
			## Выбор направления
			for dir in DIRECTIONS:
				var pos_dir_xy = (pos[0] + dir[0]) * (pos[1] + dir[1])
				var region = _regions[pos_dir_xy]
				if (region != null):
					if not regions.has(region):
						regions.append(region);
		  
##### Ошибка в том, что _regions заполняется очень странно, из-за этого строчка
##### if not regions.has(region): не дает добавить доп. элементы
			if (regions.size() < 2):
				continue

			connectorRegions[pos] = regions;
	
	## Ключи из заполненых клеток

	connectors = connectorRegions.keys()
	
#	Следите за тем, какие регионы были объединены. 
#	Это сопоставляет исходный индекс региона с тем, с которым он был объединен.
	var merged:Dictionary;
	openRegions = []

	for i in range(_currentRegion+1):
		merged[i] = i;
		if not openRegions.has(i):
			openRegions.append(i);

#	Продолжайте соединять регионы, пока не останется один.
	var g = 0
	print("размер openRegions - ", openRegions.size())
	print("размер connectors - ", connectors.size())
	while (openRegions.size() > 1 and connectors.size()>0):
		print("удалилось раз - ", g)
		var connector =connectors[_rng.randi_range(0,connectors.size()-1)]

#		Вырежьте соединение.
		_addJunction(connector);

#		Объедините подключенные регионы. 
#		Мы выберем один регион (произвольно) и сопоставим все остальные регионы с его индексом

		var regions = []
		for region in connectorRegions[connector]:
			regions.push_back(merged[region])
		
		var dest = regions.front()
		var sources = regions.duplicate()
		sources.pop_front()
		
#		Объедините все затронутые регионы. Мы должны смотреть на *все* регионы, 
#		потому что другие регионы могли быть ранее объединены 
#		с некоторыми из тех, которые мы объединяем сейчас.
		for i in range(_currentRegion):
			if (sources.has(merged[i])):
				merged[i] = dest;

#		Удаляет все элементы в списке
##		Источники больше не используются

		for i in sources:
			remove_all_elements(openRegions, i)
	  # Удалите все разъемы, которые больше не нужны.
		for pos in connectors:
#			Создание нового неповторяющегося массива
##			Если коннектор не охватывает разные регионы, он нам не нужен.

			var _regionss = []
			for region in connectorRegions[pos]:
				if not _regionss.has(merged[region]):
					_regionss.push_back(merged[region])
					
##			Не размещайте разъемы рядом друг с другом.		
			var xx = connector - pos
			if (connector - pos < Vector2(2,2)):
				connectors.erase(pos)
				g+=1
			elif (_regionss.size() > 1):
				pass
#			else:
##				remove_all_elements(connectors, pos)
#				connectors.erase(pos)
#				g+=1
#			Этот соединитель не нужен, но подключайте его время от времени, чтобы 
##			подземелье не было подключено по отдельности.
#			if (_rng.randi_range(0,extraConnectorChance)==0):
#				 _addJunction(pos);
	


#Метод, вычисляющий, какая дверь должна быть поставлена. Шанс 3 к 4, что закрытая. 
#Иначе шанс 1 к 3, что открытая. Иначе пол
var kk = 0
func _addJunction(pos:Vector2):
	kk+=1
	tileMap.set_cellv(pos, 1)
	step_history.append(pos)
	tileMap.update_bitmask_region(borders.position, borders.end)
	
#	var exit = Exit.instance()
#	add_child(exit)
#	exit.position = pos*32
	
	
	
#	exit.connect("leaving_level", self, "reload_level")
#	if _rng.randi_range(0,4)==0:
#
#		tileMap.set_cellv()
#		setTile(pos, rng.oneIn(3) ? Tiles.openDoor : Tiles.floor);
#	else:
#		setTile(pos, Tiles.closedDoor);
	pass
	
## Удаляет все элементы element из массива arr
func remove_all_elements(arr:Array, element):
	var arr_for_del = []
	for i in range(arr.size()):
		if arr[i] == element:
			arr_for_del.append(i)
			
	for i in arr_for_del:
		arr.remove(i)

## хз че это, но из-за нее ошибка
func _startRegion():
	_currentRegion+=1
 
## Удаление тупиков
func _removeDeadEnds():
	var done = false;
	var test = 0
	var test_2 = 0
	while (!done):
		
		done = true;
		## Позиции внутри игрового квадрата
		## Если нужна куча тупиков по краям карты, то юзать этот цикл
		for y in borders.size.y:
			for x in borders.size.x:
				var pos = Vector2(x, y)
				if tileMap.get_cellv(pos)==0:
					continue
			#  Если у него только один выход, это тупик.
				var exits = 0;
				for dir in DIRECTIONS:
					## мб надо приписать not. Не разобрался еще
					if tileMap.get_cellv(pos+dir)!=0:
						 exits+=1;
				if (exits != 1):
					 continue;
				done = false;
				test+=1
				step_history.erase(pos) 
				tileMap.set_cellv(pos, 0)
				tileMap.update_dirty_quadrants()
	print("удалено говна - ", test)


func _removeDeadWall():
	for y in borders.grow(-1).size.y:
		for x in borders.grow(-1).size.x:
			var pos = Vector2(x, y)
			if tileMap.get_cellv(pos)==1:
				continue
		#  Если у него только один выход, это тупик.
			var exits = 0;
			for dir in DIRECTIONS:
				## мб надо приписать not. Не разобрался еще
				if tileMap.get_cellv(pos+dir)==1:
					 exits+=1;
			if (exits != 4):
				 continue;
			step_history.append(pos) 
			tileMap.set_cellv(pos, 1)
			tileMap.update_dirty_quadrants()


func _removeDeadFloor():
	## Позиции внутри игрового квадрата
	## Возможно, надо юзать именно это
	for y in borders.grow(-1).size.y:
		for x in borders.grow(-1).size.x:
			var pos = Vector2(x, y)
			if tileMap.get_cellv(pos)==0:
				continue

		#  Если у него только один выход, это тупик.
			var exits = 0;
			for dir in DIRECTIONS:
				## мб надо приписать not. Не разобрался еще
				if tileMap.get_cellv(pos+dir)==0:
					 exits+=1;
			
			if (exits != 4):
				 continue;
			step_history.erase(pos) 
			tileMap.set_cellv(pos, 0)
			tileMap.update_dirty_quadrants()

## Удалить клетки в комнате, к которым невозможно попасть (в углах)
func _removeDeadEndsInRooms():
	var done = false;
	var test = 0
	var test_2 = 0
	for room in rooms:
		for y in range(room.position.y-1,room.end.y+1):
			for x in range(room.position.x-1,room.end.x+1):
				var pos = Vector2(x, y)
				if tileMap.get_cellv(pos)==0:
					continue

			#  Если у него только один выход, это тупик.
				var exits = 0;
				for dir in DIRECTIONS:
					## мб надо приписать not. Не разобрался еще
					if tileMap.get_cellv(pos+dir)==0:
						 exits+=1;
				

				if (exits != 3):
					 continue;

				step_history.erase(pos) 
				tileMap.set_cellv(pos, 0)
				tileMap.update_dirty_quadrants()
#	print("удалено говна - ", test)
