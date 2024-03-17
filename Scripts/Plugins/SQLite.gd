extends Node

var db : SQLite = null
var db_name := "res://data/gorm"

const verbosity_level : int = SQLite.VERBOSE

var collection_templates = {}
var _config = {}

func _ready():
	db = SQLite.new()
	db.path = db_name
	db.verbosity_level = verbosity_level
	
	var flat_dict = flatten_dict( {
	"test": {
		"nested1": 4,
		"nested2": 8,
		"deep_nested": {
			"nested": 0,
			"other":{"even_deeper": 90, "other": 100}
			}
	},
	"not_nested": 9
	})
	
	

func Configure(config={}, collection_templates={}):
	_config = config
	collection_templates = collection_templates

func CreateCollection(collection):
	db.open_db()
	var table_dict : Dictionary = Dictionary()
	table_dict["id"] = {"data_type":"int", "primary_key": true, "not_null": true}
	table_dict["document_id"] = {"data_type":"int", "not_null": true}
	table_dict["key"] = {"data_type":"text"}
	table_dict["value"] = {"data_type":"text"}
	table_dict["value_type"] = {"data_type":"int"}
	
	if not db.query_with_bindings("SELECT * FROM ? LIMIT 1;", [collection]):
		db.create_table(collection, table_dict)
		db.query("CREATE INDEX IF NOT EXISTS index_on_document_id ON %s (document_id);" % collection)
	
	db.close_db()

func DeleteCollection(collection):
	db.open_db()
	db.drop_table(collection)
	db.close_db()

func Create(collection, document={}, generate_defaults=true):
	var flattened_documern : Dictionary = flatten_dict(document)

func Read(collection, filter={}, generate_defaults=true):
	pass

func Update(collection, changed_values, filter={}, generate_defaults=true):
	pass

func Delete(collection, filter={}):
	pass

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
