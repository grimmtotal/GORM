extends Node

var _collection_templates = {}

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
	
	print(query)
	print(database.execute(query))



func DeleteCollection(collection):
	var query = """
		DROP TABLE IF EXISTS public.%s;
	""" % collection
	database.execute(query)

func Create(collection, document={}, generate_defaults=true):
	var json_document = str(document)
	
	var query = "INSERT INTO public.%s (data) VALUES ('%s') RETURNING id;" % [collection, json_document]
	var result = database.execute(query)
	
	print(result)
	print([document])


func Read(collection, filter={}, generate_defaults=true):
	pass

func Update(collection, changed_values, filter={}, generate_defaults=true):
	pass

func Delete(collection, filter={}):
	pass

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	pass

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	pass

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
			if not data in default_data:
				if data == "_id":
					continue
				
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
			print("NOT_IN_A_TRANSACTION_BLOCK")
		database.TransactionStatus.IN_A_TRANSACTION_BLOCK:
			print("IN_A_TRANSACTION_BLOCK")
		database.TransactionStatus.IN_A_FAILED_TRANSACTION_BLOCK:
			print("IN_A_FAILED_TRANSACTION_BLOCK")
	
	# The datas variable contains an array of PostgreSQLQueryResult object.
	for data in datas:
		#Specifies the number of fields in a row (can be zero).
		print(data.number_of_fields_in_a_row)
		
		# This is usually a single word that identifies which SQL command was completed.
		# note: the "BEGIN" and "COMMIT" commands return empty values
		print(data.command_tag)
		
		print(data.row_description)
		
		print(data.data_row)
		
		prints("Notice:", data.notice)
	
	if not error_object.is_empty():
		prints("Error:", error_object)
	
	database.close()


func _authentication_error(error_object: Dictionary) -> void:
	prints("Error connection to database:", error_object["message"])


func _connection_close(clean_closure := true) -> void:
	prints("DB CLOSE,", "Clean closure:", clean_closure)
