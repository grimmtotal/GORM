extends Node

var _response = {}
var collection_templates = {}

var client = HTTPRequest.new()

var _config = {
	"api_key":"key",
	"base_url":"https://us-west-2.aws.data.mongodb-api.com/app/data-ksjef/endpoint/data/v1/",
	"data_source":"data-source",
	"database":"database",
}


func _ready():
	add_child(client)
	client.request_completed.connect(self._http_request_completed)

func Configure(config={}, collection_templates={}):
	_config = config
	collection_templates = collection_templates
	

func CreateCollection(collection):
	print_debug("'CreateCollection' is currently unsupported by MongoDB Atlas, please manage your Collections here: https://cloud.mongodb.com/")

func DeleteCollection(collection):
	print_debug("'DeleteCollection' is currently unsupported by MongoDB Atlas, please manage your Collections here: https://cloud.mongodb.com/")

func Create(collection, document, generate_defaults=true):
	var body = GenerateBody(collection)
	body = JSON.parse_string(body)
	body.erase("filter")
	
	
	if generate_defaults and collection in collection_templates:
		var collection_defaults = collection_templates[collection]
		body["document"] = MatchDefault(collection_defaults, body["document"])
	else:
		body["document"] = document
	
	body = JSON.stringify(body)
	
	var headers = GenerateHeaders()
	
	var response = client.request(_config.base_url + "/action/insertOne", headers, HTTPClient.METHOD_POST, body)
	
	body = JSON.parse_string(body)
	await client.request_completed
	
	if response != OK:
		print_debug(_response)
		return _response
	
	body["document"]["_id"] = _response["insertedId"]
	var created_documents = [body["document"]]
	
	return created_documents

func Read(collection, filter={}, generate_defaults=true):
	var body = GenerateBody(collection, filter)
	var headers = GenerateHeaders()
	
	var response = client.request(_config.base_url + "/action/find", headers, HTTPClient.METHOD_POST, body)
	
	await client.request_completed
	
	if response != OK:
		print_debug(_response)
		return _response
	
	var documents = _response.documents
	
	if generate_defaults and collection in collection_templates:
		for document in len(documents):
			var collection_defaults = collection_templates[collection]
			documents[document] = MatchDefault(collection_defaults, documents[document])
	
	return _response.documents

func Update(collection, changed_values, filter={}, generate_defaults=true):
	pass

func Delete(collection, filter={}):
	pass

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	pass

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	pass


func GenerateHeaders():
	return PackedStringArray(["apiKey: " + _config.api_key, "Accept: application/json", "Content-Type: application/ejson"])

func GenerateBody(collection, filter={}):
	return JSON.new().stringify({
		"dataSource": _config.data_source,
		"database": _config.database,
		"collection": collection,
		"filter": filter
	})

func _http_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	_response = json.get_data()
	

func merge_dicts(dict1, dict2):
	var result = dict1.duplicate()
	for key in dict2:
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(dict2[key]) == TYPE_DICTIONARY:
			result[key] = merge_dicts(result[key], dict2[key])
		else:
			result[key] = dict2[key]
	return result

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
