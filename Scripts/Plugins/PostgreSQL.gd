extends Node
## GORM PostgreSQL plugin.
##
## Each collection is a table with an `id`, the document stored as JSONB in `data`,
## and `created` / `updated` unix timestamps.
## All values are sent to the backend as bound parameters, never pasted into the SQL,
## and collection names must be plain identifiers (letters, digits, underscore).
## Collection names are case-insensitive ("Worlds" and "worlds" are the same table).
##
## Every method is a coroutine: call it with await. Queries run one at a time, in order.
## On failure a method returns [] (or false) and the error is kept in last_error.

signal _connect_finished(success: bool)
signal _query_finished(result: Dictionary)
signal _query_slot_released

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }

var database: PostgreSQLClient = PostgreSQLClient.new()

## The last error reported by the backend or by this plugin (empty if none yet).
var last_error := {}

var _config = {
	"USER": "USER",
	"PASSWORD": "PASSWORD",
	"HOST": "localhost",
	"PORT": 5432,
	"DATABASE": "DATABASE",
	"SSL": false,
	"CONNECT_TIMEOUT": 10.0,
}

var _collection_templates = {}

var _connection_state := ConnectionState.DISCONNECTED
var _query_running := false
var _connect_attempt := 0
var _identifier_regex := RegEx.new()


func _init():
	_identifier_regex.compile("^[a-z_][a-z0-9_]*$")

	database.connect("connection_established", Callable(self, "_connection_established"))
	database.connect("authentication_error", Callable(self, "_authentication_error"))
	database.connect("connection_closed", Callable(self, "_connection_close"))
	database.connect("data_received", Callable(self, "_data_received"))


## Connects to the backend and creates the template collections.
## Returns OK, or an error code if the connection failed.
func Configure(config={}, collection_templates={}):
	for key in config:
		_config[key] = config[key]
	_collection_templates = collection_templates
	last_error = {}

	if _connection_state == ConnectionState.CONNECTED:
		database.close()

	var url = "postgresql://%s:%s@%s:%d/%s" % [_config.USER, _config.PASSWORD, _config.HOST, _config.PORT, _config.DATABASE]
	var method = PostgreSQLClient.SecureConnectionMethod.SSL if _config.SSL else PostgreSQLClient.SecureConnectionMethod.NONE

	_connection_state = ConnectionState.CONNECTING
	if database.connect_to_host(url, method) != OK:
		_connection_state = ConnectionState.DISCONNECTED
		_set_error({"message": "Invalid PostgreSQL connection settings"})
		return ERR_INVALID_PARAMETER

	_connect_attempt += 1
	if is_inside_tree():
		get_tree().create_timer(_config.CONNECT_TIMEOUT).timeout.connect(_connect_timeout.bind(_connect_attempt))

	if not await _connect_finished:
		return ERR_CANT_CONNECT

	await _GenerateTemplates()
	return OK


func CreateCollection(collection):
	var table = _table(collection)
	if table == "":
		return false

	var result = await _query("""
		CREATE TABLE IF NOT EXISTS %s (
			id BIGSERIAL PRIMARY KEY,
			data JSONB NOT NULL DEFAULT '{}'::jsonb,
			created DOUBLE PRECISION NOT NULL DEFAULT extract(epoch from now()),
			updated DOUBLE PRECISION NOT NULL DEFAULT extract(epoch from now())
		);
	""" % table)

	if result.ok:
		# Tables made by earlier versions of this plugin only have id and data.
		result = await _query("""
			ALTER TABLE %s
				ADD COLUMN IF NOT EXISTS created DOUBLE PRECISION NOT NULL DEFAULT extract(epoch from now()),
				ADD COLUMN IF NOT EXISTS updated DOUBLE PRECISION NOT NULL DEFAULT extract(epoch from now());
		""" % table)

	return result.ok


func DeleteCollection(collection):
	var table = _table(collection)
	if table == "":
		return false

	var result = await _query("DROP TABLE IF EXISTS %s;" % table)
	return result.ok


## Inserts a document. Returns [document] with its new id, created and updated.
func Create(collection, document={}, generate_defaults=true):
	var table = _table(collection)
	if table == "":
		return []

	document = _expand_dotted_keys(document.duplicate(true))
	for key in ["id", "created", "updated"]:
		document.erase(key)

	if generate_defaults and collection in _collection_templates:
		document = MatchDefault(_collection_templates[collection], document)

	var now = Time.get_unix_time_from_system()
	var result = await _query(
		"INSERT INTO %s (data, created, updated) VALUES ($1::jsonb, $2, $2) RETURNING id;" % table,
		[document, now])

	if not result.ok:
		return []

	document["id"] = result.rows[0].id
	document["created"] = now
	document["updated"] = now
	return [document]


## Returns every document matching filter (all documents if filter is empty).
func Read(collection, filter={}, _generate_defaults=true):
	var table = _table(collection)
	if table == "":
		return []

	var params = []
	var where_clause = _where_clause_from_filter(filter, params)
	if where_clause == "":
		return []

	var result = await _query(
		"SELECT id, data, created, updated FROM %s WHERE %s ORDER BY id;" % [table, where_clause],
		params)

	if not result.ok:
		return []

	var documents = []
	for row in result.rows:
		var document = JSON.parse_string(row.data) if row.data is String else row.data
		if not document is Dictionary:
			document = {}

		if collection in _collection_templates:
			_restore_types(_collection_templates[collection], document)

		document["id"] = row.id
		document["created"] = row.created
		document["updated"] = row.updated
		documents.append(document)

	return documents


## Merges changed_values into every document matching filter (nested dictionaries are
## merged key by key, "a.b" keys update nested values). Returns [{"id": ...}] per document.
func Update(collection, changed_values, filter={}, _generate_defaults=true):
	var table = _table(collection)
	if table == "":
		return []

	var changes = _expand_dotted_keys(changed_values.duplicate(true))
	for key in ["id", "created", "updated"]:
		changes.erase(key)

	var params = [changes, Time.get_unix_time_from_system()]
	var where_clause = _where_clause_from_filter(filter, params)
	if where_clause == "":
		return []

	var result = await _query(
		"UPDATE %s SET data = gorm_deep_merge(data, $1::jsonb), updated = $2 WHERE %s RETURNING id;" % [table, where_clause],
		params)

	if not result.ok:
		return []

	var updated_ids = []
	for row in result.rows:
		updated_ids.append({"id": row.id})
	return updated_ids


## Deletes every document matching filter. An empty filter deletes nothing.
## Returns [{"id": ...}] per deleted document.
func Delete(collection, filter={}):
	var table = _table(collection)
	if table == "":
		return []

	if filter.is_empty():
		return []

	var params = []
	var where_clause = _where_clause_from_filter(filter, params)
	if where_clause == "":
		return []

	var result = await _query("DELETE FROM %s WHERE %s RETURNING id;" % [table, where_clause], params)

	if not result.ok:
		return []

	var deleted_ids = []
	for row in result.rows:
		deleted_ids.append({"id": row.id})
	return deleted_ids


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
	var documents = await Update(collection, document, filter, generate_defaults)

	if not documents.is_empty():
		return documents
	else:
		return await Create(collection, document, generate_defaults)


func MatchDefault(default_data, loaded_data, strict=false):

	if "strict_templates" in _config:
		strict = _config.strict_templates

	default_data = default_data.duplicate(true)
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
	if _connection_state == ConnectionState.CONNECTED:
		database.close()


func _process(_delta: float) -> void:
	database.poll()


# --- Connection ---

func _connection_established() -> void:
	if _connection_state == ConnectionState.CONNECTING:
		_connection_state = ConnectionState.CONNECTED
		_connect_finished.emit(true)


func _authentication_error(error_object: Dictionary) -> void:
	_set_error(error_object)
	_fail_connection()


func _connect_timeout(attempt: int) -> void:
	if attempt == _connect_attempt and _connection_state == ConnectionState.CONNECTING:
		_set_error({"message": "Timed out connecting to PostgreSQL at %s:%d" % [_config.HOST, _config.PORT]})
		database.client.disconnect_from_host()
		_fail_connection()


func _connection_close(_clean_closure := true) -> void:
	if _connection_state == ConnectionState.CONNECTING:
		# The driver reports the close before it has read the error message
		# (e.g. a wrong password), so give it a moment to arrive.
		_fail_connection.call_deferred()
		return

	_connection_state = ConnectionState.DISCONNECTED
	if _query_running:
		_query_finished.emit({"ok": false, "rows": [], "error": {"message": "Connection to PostgreSQL closed"}})


func _fail_connection() -> void:
	if _connection_state == ConnectionState.CONNECTING:
		if last_error.is_empty():
			_set_error({"message": "Could not connect to PostgreSQL at %s:%d" % [_config.HOST, _config.PORT]})
		_connection_state = ConnectionState.DISCONNECTED
		_connect_finished.emit(false)


# --- Queries ---

## Runs one statement and returns {"ok": bool, "rows": Array[Dictionary], "error": Dictionary}.
## Waits for any query already running to finish first.
func _query(sql: String, params: Array = []) -> Dictionary:
	while _query_running:
		await _query_slot_released

	if _connection_state != ConnectionState.CONNECTED:
		var not_connected = {"message": "Not connected to PostgreSQL"}
		_set_error(not_connected)
		return {"ok": false, "rows": [], "error": not_connected}

	_query_running = true

	var result: Dictionary
	var error = database.execute_params(sql, params)
	if error == OK:
		result = await _query_finished
	else:
		result = {"ok": false, "rows": [], "error": {"message": "Could not send query (%s)" % error_string(error)}}

	_query_running = false
	_query_slot_released.emit()

	if not result.ok:
		_set_error(result.error)

	return result


func _data_received(error_object: Dictionary, _transaction_status: PostgreSQLClient.TransactionStatus, datas: Array) -> void:
	if not _query_running:
		return

	var rows = []
	for data in datas:
		for row in data.data_row:
			var formatted_row = {}
			for item in len(row):
				formatted_row[data.row_description[item].field_name] = row[item]
			rows.append(formatted_row)

	_query_finished.emit({"ok": error_object.is_empty(), "rows": rows, "error": error_object.duplicate(true)})


func _set_error(error_object: Dictionary) -> void:
	last_error = error_object.duplicate(true)
	push_error("GORM PostgreSQL: %s" % error_object.get("message", error_object))


func _GenerateTemplates():
	# Recursively merges two JSON objects; used by Update so nested values can be
	# changed without replacing the whole object.
	await _query("""
		CREATE OR REPLACE FUNCTION gorm_deep_merge(a jsonb, b jsonb) RETURNS jsonb
		LANGUAGE plpgsql IMMUTABLE AS $body$
		BEGIN
			IF jsonb_typeof(a) = 'object' AND jsonb_typeof(b) = 'object' THEN
				RETURN (
					SELECT COALESCE(jsonb_object_agg(k,
						CASE
							WHEN a ? k AND b ? k THEN gorm_deep_merge(a -> k, b -> k)
							WHEN b ? k THEN b -> k
							ELSE a -> k
						END), '{}'::jsonb)
					FROM (SELECT jsonb_object_keys(a) UNION SELECT jsonb_object_keys(b)) AS keys(k)
				);
			END IF;
			RETURN b;
		END
		$body$;
	""")

	for collection in _collection_templates:
		await CreateCollection(collection)


## Returns the quoted table name for a collection, or "" if the name is not allowed.
func _table(collection) -> String:
	var table_name = str(collection).to_lower()
	if not _identifier_regex.search(table_name):
		_set_error({"message": "Invalid collection name '%s' (use letters, digits and underscores)" % collection})
		return ""
	return "\"%s\"" % table_name


# --- Filters ---

## Builds the WHERE clause for filter, appending its values to params.
## Returns "" if any filter is invalid, so a bad filter never widens a query.
func _where_clause_from_filter(filter, params: Array) -> String:
	var where_clauses = []
	for key in filter:
		var clause = _construct_where_clause(str(key), filter[key], params)
		if clause == "":
			return ""
		where_clauses.append(clause)

	return " AND ".join(where_clauses) if where_clauses.size() > 0 else "TRUE"


func _construct_where_clause(key: String, value, params: Array) -> String:
	var split_key = key.split("__")
	var key_path = split_key[0]
	var filter_type = split_key[1] if split_key.size() > 1 else "exact"

	var add_param = func(param) -> String:
		params.append(param)
		return "$%d" % params.size()

	# The same comparisons work on columns and on values inside the document.
	var json_value: String
	var text_value: String
	var number_value: String
	if key_path in ["id", "created", "updated"]:
		json_value = "to_jsonb(%s)" % key_path
		text_value = "%s::text" % key_path
		number_value = key_path
	else:
		var path = []
		for segment in key_path.split("."):
			path.append(add_param.call(segment) + "::text")
		json_value = "jsonb_extract_path(data, %s)" % ", ".join(path)
		text_value = "jsonb_extract_path_text(data, %s)" % ", ".join(path)
		number_value = "(CASE WHEN jsonb_typeof(%s) = 'number' THEN (%s)::numeric END)" % [json_value, text_value]

	match filter_type:
		"exact":
			match typeof(value):
				TYPE_NIL:
					return "COALESCE(jsonb_typeof(%s), 'null') = 'null'" % json_value
				TYPE_BOOL:
					return "%s = to_jsonb(%s::boolean)" % [json_value, add_param.call(value)]
				TYPE_INT, TYPE_FLOAT:
					if key_path == "id" and typeof(value) == TYPE_INT:
						return "id = %s::bigint" % add_param.call(value)
					return "%s = %s::numeric" % [number_value, add_param.call(value)]
				TYPE_DICTIONARY, TYPE_ARRAY:
					return "%s = %s::jsonb" % [json_value, add_param.call(value)]
				_:
					return "%s = %s" % [text_value, add_param.call(str(value))]
		"iexact":
			return "lower(%s) = lower(%s)" % [text_value, add_param.call(str(value))]
		"contains":
			return "strpos(%s, %s) > 0" % [text_value, add_param.call(str(value))]
		"icontains":
			return "strpos(lower(%s), lower(%s)) > 0" % [text_value, add_param.call(str(value))]
		"startswith":
			return "starts_with(%s, %s)" % [text_value, add_param.call(str(value))]
		"istartswith":
			return "starts_with(lower(%s), lower(%s))" % [text_value, add_param.call(str(value))]
		"endswith":
			var param = add_param.call(str(value))
			return "right(%s, char_length(%s)) = %s" % [text_value, param, param]
		"iendswith":
			var param = add_param.call(str(value))
			return "lower(right(%s, char_length(%s))) = lower(%s)" % [text_value, param, param]
		"regex":
			return "%s ~ %s" % [text_value, add_param.call(str(value))]
		"iregex":
			return "%s ~* %s" % [text_value, add_param.call(str(value))]
		"gt", "gte", "lt", "lte":
			if not _is_number(value):
				_set_error({"message": "Filter '%s' needs a number, got '%s'" % [key, value]})
				return ""
			var operator = {"gt": ">", "gte": ">=", "lt": "<", "lte": "<="}[filter_type]
			return "%s %s %s::numeric" % [number_value, operator, add_param.call(value)]
		"range":
			if not (value is Array and value.size() == 2 and _is_number(value[0]) and _is_number(value[1])):
				_set_error({"message": "Filter '%s' needs [min, max] numbers, got '%s'" % [key, value]})
				return ""
			return "%s BETWEEN %s::numeric AND %s::numeric" % [number_value, add_param.call(value[0]), add_param.call(value[1])]
		"in":
			if not value is Array:
				_set_error({"message": "Filter '%s' needs an Array, got '%s'" % [key, value]})
				return ""
			return "%s IN (SELECT jsonb_array_elements(%s::jsonb))" % [json_value, add_param.call(value)]
		"isnull":
			if value:
				return "COALESCE(jsonb_typeof(%s), 'null') = 'null'" % json_value
			return "COALESCE(jsonb_typeof(%s), 'null') <> 'null'" % json_value

	_set_error({"message": "Unknown filter type '%s' in '%s'" % [filter_type, key]})
	return ""


func _is_number(value) -> bool:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value).is_valid_float()
	return false


# --- Documents ---

## Turns {"a.b": 1} into {"a": {"b": 1}}, merging with any existing nested values.
func _expand_dotted_keys(document: Dictionary) -> Dictionary:
	var expanded = {}
	for key in document:
		var value = document[key]
		if value is Dictionary:
			value = _expand_dotted_keys(value)

		var parts = str(key).split(".")
		var level = expanded
		for i in parts.size() - 1:
			if not level.get(parts[i]) is Dictionary:
				level[parts[i]] = {}
			level = level[parts[i]]

		var last = parts[parts.size() - 1]
		if value is Dictionary and level.get(last) is Dictionary:
			_merge_into(level[last], value)
		else:
			level[last] = value
	return expanded


func _merge_into(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if source[key] is Dictionary and target.get(key) is Dictionary:
			_merge_into(target[key], source[key])
		else:
			target[key] = source[key]


## JSON has no integer type, so numbers come back as floats.
## Converts them back to int wherever the collection template has an int.
func _restore_types(template: Dictionary, document: Dictionary) -> void:
	for key in document:
		if not key in template:
			continue
		var default = template[key]
		var value = document[key]
		if default is Dictionary and value is Dictionary:
			_restore_types(default, value)
		elif typeof(default) == TYPE_INT and typeof(value) == TYPE_FLOAT and value == floorf(value):
			document[key] = int(value)
