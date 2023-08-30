extends Node

var prefix = "user://"
var data_folder_name = "data"
var ext = ".gormcollection"

var collection_templates = {}
var config = {}

func Configure(configuration, templates):
	collection_templates = templates
	config = merge_dicts(configuration, config)
	_GenerateTemplates()

func DeleteCollection(collection):
	var collection_path = _build_collection_path(collection)
	var collection_exists = FileAccess.file_exists(collection_path)
	if not collection_exists:
		print_debug("Collection does not exist: ", str(collection))
		return
	
	DirAccess.remove_absolute(collection_path)
	print_debug("Collection successfully removed: ", str(collection))

func CreateCollection(collection):
	var collection_path = _build_collection_path(collection)
	var collection_exists = FileAccess.file_exists(collection_path)
	if not collection_exists:
		var dir = DirAccess.open(prefix)
		dir.make_dir_recursive(data_folder_name)
		var collection_file = FileAccess.open(collection_path, FileAccess.WRITE)
		collection_file.seek(0)
		collection_file.store_var({'_metadata':{'seed':0}}, true)
	
	return collection

func Create(collection, document, generate_defaults=true):
	var collection_path = _build_collection_path(collection)
	var collection_exists = FileAccess.file_exists(collection_path)
	
	if not collection_exists:
		print_debug("Collection '{collection}' does not exist!".format({"collection": collection}))
		return false
	
	var collection_file = FileAccess.open(collection_path, FileAccess.READ_WRITE)
	var collection_data = collection_file.get_var(true)
	if collection_data == null:
		collection_data = {"_metadata": {"seed": 0}}
	
	var collection_items = collection_data.duplicate()
	collection_items.erase("_metadata")
	var seed = collection_data["_metadata"]["seed"]
	
	document["id"] = seed
	collection_data[str(seed)] = document
	collection_data["_metadata"]["seed"] = seed + 1
	
	if generate_defaults:
		var collection_defaults = collection_templates[collection]
		collection_data[str(seed)] = MatchDefault(collection_defaults, collection_data[str(seed)])

	
	collection_file.seek(0)
	collection_file.store_var(collection_data, true)
	collection_file.close()
	return [collection_data[str(seed)]]



func Read(collection, filter={}, generate_defaults=true):
	var collection_path = _build_collection_path(collection)
	
	var collection_exists = FileAccess.file_exists(collection_path)
	
	if not collection_exists:
		print_debug("Collection '{collection}' does not exist!".format({"collection": collection}))
		return false
	
	var collection_file = FileAccess.open(collection_path, FileAccess.READ)
	var collection_items = collection_file.get_var(true)
	if collection_items == null:
		collection_items = {}
	
	var filtered_items = _filter(collection_items, filter)
	
	if generate_defaults:
		var collection_defaults = collection_templates[collection]
		for item in len(filtered_items):
			var id = filtered_items[item].id
			filtered_items[item] = MatchDefault(collection_defaults, filtered_items[item])
			filtered_items[item].id = id
	
	collection_file.close()
	return filtered_items


func Update(collection, changed_values, filter={}, generate_defaults=true):
	var collection_path = _build_collection_path(collection)
	var collection_exists = FileAccess.file_exists(collection_path)
	
	if not collection_exists:
		print_debug("Collection '{collection}' does not exist!".format({"collection": collection}))
		return false
	
	var collection_file = FileAccess.open(collection_path, FileAccess.READ_WRITE)
	var collection_items = collection_file.get_var(true)
	if collection_items == null:
		collection_items = {}
	
	var updated_items = []
	for document_id in collection_items:
		if document_id == "_metadata":
			continue
		
		if _filter_match(collection_items[document_id], filter):
			
			if "id" in changed_values:
				changed_values.erase("id")
				
			
			collection_items[document_id] = merge_dicts(collection_items[document_id], changed_values)
			
			if generate_defaults:
				var collection_defaults = collection_templates[collection]
				collection_items[document_id] = MatchDefault(collection_defaults, collection_items[document_id])
			
			updated_items.append(collection_items[document_id])
	
	collection_file.seek(0)
	collection_file.store_var(collection_items, true)
	collection_file.close()
	return updated_items



func Delete(collection, filter={}):
	var collection_path = _build_collection_path(collection)
	var collection_exists = FileAccess.file_exists(collection_path)
	
	if not collection_exists:
		print_debug("Collection '{collection}' does not exist!".format({"collection": collection}))
		return false
	
	var collection_file = FileAccess.open(collection_path, FileAccess.READ_WRITE)
	var collection_items = collection_file.get_var(true)
	if collection_items == null:
		collection_items = {}
	
	var delete_count = 0
	for document_id in collection_items.keys():
		if document_id == "_metadata":
			continue
		
		if _filter_match(collection_items[document_id], filter):
			delete_count += 1
			collection_items.erase(document_id)
	
	collection_file.seek(0)
	collection_file.store_var(collection_items, true)
	collection_file.close()
	return true

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	var documents = []
	if filter.is_empty():
		documents = Read(collection, document)
	else:
		documents = Read(collection, filter)
	
	if not documents.is_empty():
		return documents
	else:
		return Create(collection, document, generate_defaults)
		
	

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	var documents = []
	documents = Update(collection, document, filter, generate_defaults)
	
	if not documents.is_empty():
		return documents
	else:
		return Create(collection, document)

func GenerateSalt():
	randomize()
	var salt = str(randi()).sha256_text()
#	print("Salt: " + salt)
	return salt

func GenerateHashedPassword(password, salt):
	var hashed_password = password
	var rounds = pow(2,9)
#	print("Password as input: " + hashed_password)
	while rounds > 0:
		hashed_password = (hashed_password + salt).sha256_text()
		rounds -= 1
	return hashed_password


func _build_collection_path(collection):
	return prefix + data_folder_name + "/" + collection.to_upper() + ext

func _filter(collection_items, filter):
	var matched_documents = []
	var items_without_metadata = collection_items.duplicate()
	items_without_metadata.erase("_metadata") # Erase the metadata key
	for document_id in items_without_metadata:
		if filter.size() == 0 or _filter_match(items_without_metadata[document_id], filter):
			matched_documents.append(items_without_metadata[document_id])
	
	return matched_documents

func _filter_match(document, filter):
	for key in filter:
		if key == "_metadata":
			continue
	
		if typeof(document) != TYPE_DICTIONARY or not document.has(key):
			return false

		var filter_value = filter[key]
		var document_value = document[key]
	
		if typeof(filter_value) == TYPE_DICTIONARY:
			if not _filter_match(document_value, filter_value):
				return false
		elif filter_value != document_value:
			return false
	
	return true

func _GenerateTemplates():
	
	for collection in collection_templates:
		CreateCollection(collection)

func merge_dicts(dict1, dict2):
	var result = dict1.duplicate()
	for key in dict2:
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(dict2[key]) == TYPE_DICTIONARY:
			result[key] = merge_dicts(result[key], dict2[key])
		else:
			result[key] = dict2[key]
	return result

func MatchDefault(default_data, loaded_data, strict=true):
	
	if "strict_templates" in config:
		strict = config.strict_templates
	
	loaded_data = loaded_data.duplicate(true)
	var l_data = loaded_data.duplicate(true)
	
	for data in default_data:
		if not data in l_data:
			l_data[data] = default_data[data]
		elif typeof(l_data[data]) == TYPE_DICTIONARY:
				l_data[data] = MatchDefault(default_data[data], l_data[data])
	
	if strict:
		for data in loaded_data:
			if not data in default_data:
				if data == "id":
					continue
				
				l_data.erase(data)
				
	return l_data

