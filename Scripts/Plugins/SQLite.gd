extends Node

var db : SQLite = null
var db_name := "res://data/gorm"

const verbosity_level : int = SQLite.QUIET

var _collection_templates = {}

var _config = {}

func _ready():
	db = SQLite.new()
	db.path = db_name
	db.verbosity_level = verbosity_level
	

func Configure(config={}, collection_templates={}):
	_config = config
	_collection_templates = collection_templates
	_GenerateTemplates()

func CreateCollection(collection):
	
	var table_dict : Dictionary = Dictionary()
	table_dict["id"] = {"data_type":"int", "primary_key": true, "not_null": true}
	table_dict["document_id"] = {"data_type":"int", "not_null": true}
	table_dict["key"] = {"data_type":"text"}
	table_dict["value"] = {"data_type":"text"}
	table_dict["value_type"] = {"data_type":"int"}
	table_dict["updated"] = {"data_type":"real"}
	table_dict["created"] = {"data_type":"real"}
	
	db.open_db()
	if not db.query("SELECT * FROM %s LIMIT 1;" % collection):
		db.create_table(collection, table_dict)
		db.query("CREATE INDEX IF NOT EXISTS index_on_document_id ON %s (document_id);" % collection)
		db.close_db()
		Create(collection, {"_seed":0}, false)
	else:
		db.close_db()
	

func DeleteCollection(collection):
	db.open_db()
	db.drop_table(collection)
	db.close_db()

func Create(collection, document={}, generate_defaults=true):
	document.erase("id")
	document.erase("updated")
	document.erase("created")
	
	if generate_defaults:
		document = MatchDefault(_collection_templates[collection], document)
	
	
	var flattened_document : Dictionary = flatten_dict(document)
	
	var new_id : int = 0
	
	var meta_data = Read(collection, {"id":0}, false, true)
	print(meta_data)
	if not meta_data.is_empty():
		new_id = meta_data[0]["_seed"] + 1
		Update(collection, {"_seed": new_id}, {"id":0}, false, true)
		
	db.open_db()
	var rows = []
	for key in flattened_document:
		var value = flattened_document[key]
		rows.append({
			"document_id": new_id,
			"key": key,
			"value": str(value),
			"value_type": typeof(value),
			"updated": Time.get_unix_time_from_system(),
			"created": Time.get_unix_time_from_system()
		})
	
	
	var succeeded = db.insert_rows(collection, rows)
	
	if not succeeded:
		return []
	
	document["id"] = new_id
	db.close_db()
	return [document]

func Read(collection, filter={}, generate_defaults=true, show_hidden=false):
	var where_clause = _where_clause_from_filter(filter)
	var query = "SELECT * FROM %s WHERE %s;" % [collection, where_clause]
	
	db.open_db()
	db.query(query)
	db.close_db()
	
	var initial_results = db.query_result.duplicate(true)
	
	var document_ids = []
	for result in initial_results:
		if not result.document_id in document_ids:
			document_ids.append(result.document_id)
	
	var formatted_results = []
	for doc_id in document_ids:
		db.open_db()
		db.query("SELECT * FROM %s WHERE document_id = %s;" % [collection, doc_id])
		var result = db.query_result.duplicate(true)
		var formatted_result = {}
		
		var updated_values = []
		var created_values = []
		
		for item in result:
			if item.document_id == 0 and not show_hidden:
				continue
			
			formatted_result["id"] = item.document_id
			formatted_result[item.key] = type_convert(str_to_var(item.value), item.value_type)
			updated_values.append(item.updated)
			created_values.append(item.created)
		
		updated_values.sort()
		created_values.sort()
		
		if not updated_values.is_empty() and not created_values.is_empty():
			formatted_result["updated"] = updated_values.pop_back()
			formatted_result["created"] = created_values.pop_front()
		
		if not formatted_result.is_empty():
			formatted_results.append(unflatten_dict(formatted_result))
		
		db.close_db()
		
	return formatted_results

func Update(collection, changed_values, filter={}, generate_defaults=true, show_hidden=false):
	var affected_documents = Read(collection, filter, generate_defaults, show_hidden)
	
	changed_values.erase("id")
	changed_values.erase("updated")
	changed_values.erase("created")
	
	changed_values = flatten_dict(changed_values)
	
	var updated_ids = []
	for document in affected_documents:
		updated_ids.append({"id": document.id})
		for key in changed_values:
			var value = changed_values[key]
			var query = "UPDATE %s SET \"value\" = '%s', \"updated\" = '%s' WHERE \"key\" = '%s' AND \"document_id\" = '%s'" % [collection, value, Time.get_unix_time_from_system(), key, document.id]
			db.open_db()
			db.query(query)
			db.close_db()
	
	return updated_ids

func Delete(collection, filter={}):
	var affected_documents = Read(collection, filter, false)
	for document in affected_documents:
		var query = "DELETE FROM %s WHERE \"document_id\" = '%s';" % [collection, document.id]
		
		db.open_db()
		db.query(query)
		db.close_db()
	
	return []

func MatchDefault(default_data, loaded_data, strict=true):
	
	loaded_data = loaded_data.duplicate(true)
	var l_data = loaded_data.duplicate(true)
	
	default_data = default_data.duplicate(true)
	
	for data in default_data:
		if not data in l_data:
			l_data[data] = default_data[data]
		elif typeof(l_data[data]) == TYPE_DICTIONARY:
			if default_data[data] != {}:
				l_data[data] = MatchDefault(default_data[data], l_data[data])
	
	if strict:
		for data in loaded_data:
			if not data in default_data:
				if data in ["id", "updated", "created"]:
					continue
				
				l_data.erase(data)
				
	return l_data

func flatten_dict(input_dict: Dictionary, parent_key: String = "", sep: String = ".") -> Dictionary:
	var flat_dict = Dictionary()
	for key in input_dict.keys():
		var new_key = (parent_key + sep if parent_key != "" else "") + key
		if input_dict[key] is Dictionary:
			var sub_dict = flatten_dict(input_dict[key], new_key, sep)
			for sub_key in sub_dict.keys():
				flat_dict[sub_key] = sub_dict[sub_key]
		else:
			flat_dict[new_key] = input_dict[key]
	return flat_dict

func unflatten_dict(flat_dict: Dictionary, sep: String = ".") -> Dictionary:
	var nested_dict = Dictionary()
	for key in flat_dict.keys():
		var parts = key.split(sep)
		var current_level = nested_dict
		for i in range(parts.size()):
			var part = parts[i]
			if i == parts.size() - 1:
				current_level[part] = flat_dict[key]
			else:
				if not current_level.has(part):
					current_level[part] = Dictionary()
				current_level = current_level[part]
	return nested_dict

func _construct_where_clause(filter_key, filter_value):
	var split_filter = filter_key.split("__")
	var key_path = split_filter[0]  # The column 'key' retains the dot notation
	var filter_type = split_filter[1] if split_filter.size() > 1 else "exact"
	
	if key_path == "id":
		return _construct_vanilla_where_clause( "document_id__" + filter_type, filter_value)
	
	var clause = ""
	match filter_type:
		"exact":
			clause = "\"key\" = '%s' AND \"value\" = '%s'" % [key_path, filter_value]
		"iexact":
			clause = "LOWER(\"key\") = LOWER('%s') AND LOWER(\"value\") = LOWER('%s')" % [key_path, filter_value]
		"contains":
			clause = "\"key\" LIKE '%%%s%%' AND \"value\" LIKE '%%%s%%'" % [key_path, filter_value]
		"icontains":
			clause = "LOWER(\"key\") LIKE LOWER('%%%s%%') AND LOWER(\"value\") LIKE LOWER('%%%s%%')" % [key_path, filter_value]
		"gt":
			clause = "\"key\" = '%s' AND CAST(\"value\" AS INTEGER) > %s" % [key_path, str(filter_value)]
		"gte":
			clause = "\"key\" = '%s' AND CAST(\"value\" AS INTEGER) >= %s" % [key_path, str(filter_value)]
		"lt":
			clause = "\"key\" = '%s' AND CAST(\"value\" AS INTEGER) < %s" % [key_path, str(filter_value)]
		"lte":
			clause = "\"key\" = '%s' AND CAST(\"value\" AS INTEGER) <= %s" % [key_path, str(filter_value)]
		"in":
			print_debug("Filter types 'regex', 'iregex', 'startswith', 'istartswith', 'endswith', 'iendswith' are not supported by default in SQLite")			
			clause = ""
		"range":
			# Assuming filter_value is a two-element array [min, max]
			clause = "\"key\" = '%s' AND CAST(\"value\" AS INTEGER) BETWEEN %s AND %s" % [key_path, str(filter_value[0]), str(filter_value[1])]
		"isnull":
			clause = "\"key\" = '%s' AND \"value\" IS NULL" % key_path if filter_value else "\"key\" = '%s' AND \"value\" IS NOT NULL" % key_path
		"regex", "iregex", "startswith", "istartswith", "endswith", "iendswith":
			# SQLite does not support the REGEXP operator by default
			print_debug("Filter types 'regex', 'iregex', 'startswith', 'istartswith', 'endswith', 'iendswith' are not supported by default in SQLite")
			clause = ""
		_:
			print("Unknown filter type: ", filter_type)
			clause = ""
	
	return clause
	

func _construct_vanilla_where_clause(filter_key, filter_value):
	var split_filter = filter_key.split("__")
	var key_path = split_filter[0]  # The column 'key' retains the dot notation
	var filter_type = split_filter[1] if split_filter.size() > 1 else "exact"
	
	var clause = ""
	match filter_type:
		"exact":
			clause = "\"%s\" = '%s'" % [key_path, filter_value]
		"iexact":
			clause = "LOWER(\"%s\") = LOWER('%s')" % [key_path, filter_value]
		"contains":
			clause = "\"%s\" LIKE '%%%s%%'" % [key_path, filter_value]
		"icontains":
			clause = "LOWER(\"%s\") LIKE LOWER('%%%s%%')" % [key_path, filter_value]
		"gt":
			clause = "CAST(\"%s\" AS INTEGER) > %s" % [key_path, str(filter_value)]
		"gte":
			clause = "CAST(\"%s\" AS INTEGER) >= %s" % [key_path, str(filter_value)]
		"lt":
			clause = "CAST(\"%s\" AS INTEGER) < %s" % [key_path, str(filter_value)]
		"lte":
			clause = "CAST(\"%s\" AS INTEGER) <= %s" % [key_path, str(filter_value)]
		"in":
			print_debug("Filter types 'regex', 'iregex', 'startswith', 'istartswith', 'endswith', 'iendswith' are not supported by default in SQLite")
			clause = ""
		"range":
			# Assuming filter_value is a two-element array [min, max]
			clause = "CAST(\"%s\" AS INTEGER) BETWEEN %s AND %s" % [key_path, str(filter_value[0]), str(filter_value[1])]
		"isnull":
			clause = "'%s' IS NULL" % key_path if filter_value else "\"key\" = '%s' AND \"value\" IS NOT NULL" % key_path
		"regex", "iregex", "startswith", "istartswith", "endswith", "iendswith":
			# SQLite does not support the REGEXP operator by default
			print_debug("Filter types 'regex', 'iregex', 'startswith', 'istartswith', 'endswith', 'iendswith' are not supported by default in SQLite")
			clause = ""
		_:
			print("Unknown filter type: ", filter_type)
			clause = ""
	
	return clause

func _where_clause_from_filter(filter):
	var where_clauses = []
	for key in filter.keys():
		var clause = _construct_where_clause(key, filter[key])
		if clause != "":
			where_clauses.append(clause)
	
	return " AND ".join(where_clauses) if where_clauses.size() > 0 else "1=1"

func _GenerateTemplates():
	for collection in _collection_templates:
		CreateCollection(collection)
