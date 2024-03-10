extends Node

var _collection_templates = {}

var _result = []

var client = HTTPRequest.new()

var _config = {
	"USER":"USER",
	"PASSWORD":"PASSWORD",
	"HOST":"localhost",
	"PORT":5432,
	"DATABASE":"DATABASE",
}

var database: PostgreSQLClient = PostgreSQLClient.new()

func _init():
	database.connect("connection_established", Callable(self, "_connection_established"))
	database.connect("authentication_error", Callable(self, "_authentication_error"))
	database.connect("connection_closed", Callable(self, "_connection_close"))
	database.connect("data_received", Callable(self, "_data_received"))



func Configure(config={}, collection_templates={}):
	_config = config
	_collection_templates = collection_templates
	
	database.connect_to_host("postgresql://%s:%s@%s:%d/%s" % [_config.USER, _config.PASSWORD, _config.HOST, _config.PORT, _config.DATABASE])
	

func CreateCollection(collection):
	var query = """
		CREATE TABLE public.%s (
			id SERIAL PRIMARY KEY,
			data JSONB NOT NULL
		);
	""" % collection
	database.execute(query)
	
	await database.data_received
	
	return _result.duplicate(true)

func DeleteCollection(collection):
	var query = """
		DROP TABLE IF EXISTS public.%s;
	""" % collection
	database.execute(query)
	
	await database.data_received
	
	return _result.duplicate(true)

func Create(collection, document={}, generate_defaults=true):
	if generate_defaults and collection in _collection_templates:
		document = MatchDefault(_collection_templates[collection], document)
	
	if "id" in document:
		document.erase("id")
	
	var json_document = str(document)
	
	var query = "INSERT INTO public.%s (data) VALUES ('%s') RETURNING id;" % [collection, json_document]
	var result = database.execute(query)
	
	await database.data_received
	
	return _result.duplicate(true)


func Read(collection, filter={}, generate_defaults=true):
	var where_clauses = []
	for key in filter.keys():
		var clause = _construct_where_clause(key, filter[key])
		if clause != "":
			where_clauses.append(clause)
	
	var where_clause = " AND ".join(where_clauses) if where_clauses.size() > 0 else "1=1"
	var query = "SELECT * FROM public.%s WHERE %s;" % [collection, where_clause]
	var result = database.execute(query)

	await database.data_received
	
	return _result.duplicate(true)

func Update(collection, changed_values, filter={}, generate_defaults=true):
	var affected_rows = await Read(collection, filter, generate_defaults)
	
	var set_clauses = []
	for key in changed_values.keys():
		var value = changed_values[key]
		var set_clause = "data = jsonb_set(data, '{%s}', '\"%s\"')" % [key.replace(".", ","), str(value).json_escape()]
		set_clauses.append(set_clause)
	var set_clause_str = ", ".join(set_clauses)
	
	var where_clauses = []
	for key in filter.keys():
		var clause = _construct_where_clause(key, filter[key])
		if clause != "":
			where_clauses.append(clause)
	var where_clause = " AND ".join(where_clauses) if where_clauses.size() > 0 else "TRUE"
	
	var query = "UPDATE public.%s SET %s WHERE %s;" % [collection, set_clause_str, where_clause]
	var result = database.execute(query)
	
	await database.data_received
	
	_result.clear()
	for row in affected_rows:
		_result.append({"id": row.id})
	
	return _result.duplicate(true)


func Delete(collection, filter={}):
	var where_clauses = []
	for key in filter.keys():
		var clause = _construct_where_clause(key, filter[key])
		if clause != "":
			where_clauses.append(clause)
	
	var where_clause = " AND ".join(where_clauses) if where_clauses.size() > 0 else "1=0"
	var query = "DELETE FROM public.%s WHERE %s;" % [collection, where_clause]
	var result = database.execute(query)

	await database.data_received
	
	return _result.duplicate(true)

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	var documents = []
	if filter.is_empty():
		documents = await Read(collection, document)
	else:
		documents = await Read(collection, filter)
	
	if not documents.is_empty():
		return documents
	else:
		return await Create(collection, document, generate_defaults)
		

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	var documents = []
	documents = await Update(collection, document, filter, generate_defaults)
	
	if not documents.is_empty():
		return documents
	else:
		return await Create(collection, document)

func MatchDefault(default_data, loaded_data, strict=false):
	
	if "strict_templates" in _config:
		strict = _config.strict_templates
	
	loaded_data = loaded_data.duplicate(true)
	var l_data = loaded_data.duplicate(true)
	
	for data in default_data:
		if not data in l_data:
			l_data[data] = default_data[data]
		elif typeof(l_data[data]) == TYPE_DICTIONARY:
			if default_data[data] != {}:
				l_data[data] = MatchDefault(default_data[data], l_data[data])
	
	if strict:
		for data in loaded_data:
			if not data in default_data or data == "id":
				l_data.erase(data)
				
	return l_data


func _exit_tree() -> void:
	database.close()

func _process(_delta: float) -> void:
	database.poll()


func _connection_established() -> void:
	print("Connected")

func _data_received(error_object: Dictionary, transaction_status: PostgreSQLClient.TransactionStatus, datas: Array) -> void:
	match transaction_status:
		database.TransactionStatus.NOT_IN_A_TRANSACTION_BLOCK:
			pass
			#print_debug("NOT_IN_A_TRANSACTION_BLOCK")
		database.TransactionStatus.IN_A_TRANSACTION_BLOCK:
			pass
			#print_debug("IN_A_TRANSACTION_BLOCK")
		database.TransactionStatus.IN_A_FAILED_TRANSACTION_BLOCK:
			print_debug("IN_A_FAILED_TRANSACTION_BLOCK")
	
	_result.clear()
	for data in datas:
		for row in data.data_row:
			var formatted_row = {}
			for item in len(row):
				var key = data.row_description[item].field_name
				var value = row[item]
				
				formatted_row[key] = value
			
			_result.append(formatted_row)
	
	if not error_object.is_empty():
		print_debug("Error:", error_object)
	
	

func _authentication_error(error_object: Dictionary) -> void:
	prints("Error connection to database:", error_object["message"])


func _connection_close(clean_closure := true) -> void:
	prints("DB CLOSE,", "Clean closure:", clean_closure)

func _construct_where_clause(key, value):
	var split_key = key.split("__")
	var json_path = split_key[0].replace(".", ",") # Convert dot notation to comma-separated for JSONB path
	var filter_type = split_key[1] if split_key.size() > 1 else "exact"
	var raw_key = split_key[0]
	
	var clause = ""
	match filter_type:
		"exact":
			clause = "data #>> '{%s}' = '%s'" % [json_path, value]
		"iexact":
			clause = "LOWER(data #>> '{%s}') = LOWER('%s')" % [json_path, value]
		"contains":
			# For strings, checking if the substring exists in the JSONB value
			clause = "data #>> '{%s}' LIKE '%%%s%%'" % [json_path, value]
		"icontains":
			clause = "LOWER(data #>> '{%s}') LIKE LOWER('%%%s%%')" % [json_path, value]
		"gt", "gte", "lt", "lte":
			# Assuming the value is numeric. Adjust accordingly for other data types.
			var operator = {"gt": ">", "gte": ">=", "lt": "<", "lte": "<="}[filter_type]
			clause = "(data #>> '{%s}')::numeric %s %s" % [json_path, operator, value]
		"in":
			# This requires constructing an array and checking if the value is contained within it
			# Note: Adjust the syntax based on your exact requirements and PostgreSQL version
			var in_list = value.join(",")
			clause = "data #>> '{%s}' = ANY(ARRAY[%s])" % [json_path, in_list]
		"range":
			# Assuming value is a two-element array [min, max] and the target is numeric
			clause = "(data #>> '{%s}')::numeric BETWEEN %s AND %s" % [json_path, value[0], value[1]]
		"isnull":
			if value:
				clause = "data #>> '{%s}' IS NULL" % json_path
			else:
				clause = "NOT (data #>> '{%s}' IS NULL)" % json_path
		"regex", "iregex", "startswith", "istartswith", "endswith", "iendswith":
			print_debug("regex, startswith, and endswith filter types are currently not supported in the Postgres plugin, please consider the contains filters as an alternative")
			clause = ""
		_:
			print("Unknown filter type: ", filter_type)
			clause = ""
	
	if raw_key == "id":
		clause = clause.replace("data #>> ", "").replace("{", "").replace("}", "").replace("'", "")
		
		
	
	return clause
