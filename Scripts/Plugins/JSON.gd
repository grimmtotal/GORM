extends Node

var prefix = "user://"
var data_folder_name = "data"
var ext = ".grcollection"

var filter_functions = {
	"exact": "_exact_filter",
	"iexact": "_iexact_filter",
	"contains": "_contains_filter",
	"icontains": "_icontains_filter",
	"gt": "_gt_filter",
	"gte": "_gte_filter",
	"lt": "_lt_filter",
	"lte": "_lte_filter",
	"in": "_in_filter",
	"range": "_range_filter",
	"isnull": "_isnull_filter",
	"regex": "_regex_filter",
	"iregex": "_iregex_filter",
	"startswith": "_startswith_filter",
	"endswith": "_endswith_filter"
}

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
		collection_file.store_var({'_metadata':{'_seed':0}}, true)
	
	return collection

func Create(collection, document={}, generate_defaults=true):
	var collection_path = _build_collection_path(collection)
	var collection_exists = FileAccess.file_exists(collection_path)
	
	if not collection_exists:
		print_debug("Collection '{collection}' does not exist!".format({"collection": collection}))
		return false
	
	var collection_file = FileAccess.open(collection_path, FileAccess.READ_WRITE)
	var collection_data = collection_file.get_var(true)
	if collection_data == null:
		collection_data = {"_metadata": {"_seed": 0}}
	
	var collection_items = collection_data.duplicate()
	collection_items.erase("_metadata")
	var _seed = collection_data["_metadata"]["_seed"]
	
	document["id"] = _seed
	collection_data[str(_seed)] = document
	collection_data["_metadata"]["_seed"] = _seed + 1
	
	if generate_defaults:
		var collection_defaults = collection_templates[collection]
		collection_data[str(_seed)] = MatchDefault(collection_defaults, collection_data[str(_seed)])
		
	collection_data[str(_seed)]["created"] = Time.get_unix_time_from_system()
	collection_data[str(_seed)]["updated"] = Time.get_unix_time_from_system()
	
	collection_file.seek(0)
	collection_file.store_var(collection_data, true)
	collection_file.close()
	return [collection_data[str(_seed)]]



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
			
			collection_items[document_id]["updated"] = Time.get_unix_time_from_system()
			
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

func _GenerateTemplates():
	
	for collection in collection_templates:
		CreateCollection(collection)

func merge_dicts(dict1, dict2):
	dict1 = dict1.duplicate(true)
	dict2 = dict2.duplicate(true)
	var result = dict1.duplicate(true)
	for key in dict2:
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(dict2[key]) == TYPE_DICTIONARY:
			result[key] = merge_dicts(result[key], dict2[key])
		else:
			result[key] = dict2[key]
	return result

func MatchDefault(default_data, loaded_data, strict=true):
	
	loaded_data = loaded_data.duplicate(true)
	var l_data = loaded_data.duplicate(true)
	
	default_data = default_data.duplicate(true)
	
	for data in default_data:
		if not data in l_data:
			l_data[data] = default_data[data]
		elif typeof(l_data[data]) == TYPE_DICTIONARY:
				l_data[data] = MatchDefault(default_data[data], l_data[data])
	
	if strict:
		for data in loaded_data:
			if not data in default_data:
				if data in ["id", "updated", "created"]:
					continue
				
				l_data.erase(data)
				
	return l_data

func _filter(collection_items, filter):
	var matched_documents = []
	var items_without_metadata = collection_items.duplicate()
	items_without_metadata.erase("_metadata") # Erase the metadata key
	for document_id in items_without_metadata:
		if filter.size() == 0 or _filter_match(items_without_metadata[document_id], filter):
			matched_documents.append(items_without_metadata[document_id])
	
	return matched_documents

func _filter_match(document, filter):
	for key in filter.keys():
		if key == "_metadata":
			continue
		
		var split_key = key.split("__")
		var actual_key = split_key[0]
		var filter_type = split_key[1] if split_key.size() > 1 else "exact"
		
		if not document.has(actual_key):
			return false
		
		var document_value = document[actual_key]
		var filter_value = filter[key]
		
		if filter_type in filter_functions:
			var filter_func = filter_functions[filter_type]
			if not self.callv(filter_func, [document_value, filter_value]):
				return false
		else:
			print("Unknown filter type: ", filter_type)
			return false
	return true

# Filter functions
func _exact_filter(doc_value, filter_value):
	if typeof(doc_value) == typeof(filter_value):
		return doc_value == filter_value
	return false

func _iexact_filter(doc_value, filter_value):
	if typeof(doc_value) == TYPE_STRING and typeof(filter_value) == TYPE_STRING:
		return doc_value.to_lower() == filter_value.to_lower()
	return false

func _contains_filter(doc_value, filter_value):
	if typeof(doc_value) == TYPE_STRING and typeof(filter_value) == TYPE_STRING:
		return doc_value.find(filter_value) != -1
	return false

func _icontains_filter(doc_value, filter_value):
	if typeof(doc_value) == TYPE_STRING and typeof(filter_value) == TYPE_STRING:
		return doc_value.to_lower().find(filter_value.to_lower()) != -1
	return false

func _gt_filter(doc_value, filter_value):
	if typeof(doc_value) in [TYPE_INT, TYPE_FLOAT] and typeof(filter_value) in [TYPE_INT, TYPE_FLOAT]:
		return doc_value > filter_value
	return false

func _gte_filter(doc_value, filter_value):
	if typeof(doc_value) in [TYPE_INT, TYPE_FLOAT] and typeof(filter_value) in [TYPE_INT, TYPE_FLOAT]:
		return doc_value >= filter_value
	return false

func _lt_filter(doc_value, filter_value):
	if typeof(doc_value) in [TYPE_INT, TYPE_FLOAT] and typeof(filter_value) in [TYPE_INT, TYPE_FLOAT]:
		return doc_value < filter_value
	return false

func _lte_filter(doc_value, filter_value):
	if typeof(doc_value) in [TYPE_INT, TYPE_FLOAT] and typeof(filter_value) in [TYPE_INT, TYPE_FLOAT]:
		return doc_value <= filter_value
	return false

func _in_filter(doc_value, filter_value):
	if typeof(filter_value) == TYPE_ARRAY:
		return doc_value in filter_value
	return false

func _range_filter(doc_value, filter_value):
	if typeof(filter_value) == TYPE_ARRAY and filter_value.size() == 2:
		if typeof(doc_value) in [TYPE_INT, TYPE_FLOAT]:
			return doc_value >= filter_value[0] and doc_value <= filter_value[1]
	return false

func _isnull_filter(doc_value, filter_value):
	if typeof(filter_value) == TYPE_BOOL:
		return (doc_value == null and filter_value) or (doc_value != null and not filter_value)
	return false

func _regex_filter(doc_value, filter_value):
	if typeof(doc_value) == TYPE_STRING and typeof(filter_value) == TYPE_STRING:
		var regex = RegEx.new()
		regex.compile(filter_value)
		return regex.search(doc_value) != null
	return false

func _iregex_filter(doc_value, filter_value):
	if typeof(doc_value) == TYPE_STRING and typeof(filter_value) == TYPE_STRING:
		var regex = RegEx.new()
		regex.compile(filter_value.to_lower())
		return regex.search(doc_value.to_lower()) != null
	return false

func _startswith_filter(doc_value, filter_value):
	if typeof(filter_value) == TYPE_STRING:
		return str(doc_value).begins_with(filter_value)
	return false

func _endswith_filter(doc_value, filter_value):
	if typeof(filter_value) == TYPE_STRING:
		return str(doc_value).ends_with(filter_value)
	return false

