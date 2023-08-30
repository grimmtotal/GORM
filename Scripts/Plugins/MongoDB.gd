extends Node

var api_key = "5YaRinCTMwbOhOiTAsYSYsJEmDZ3qFCuarWlNdueSa7ns7oeWI2VufwfIzQMqpAA"
var _plugin
var _config = {
	"api_key":"key",
	"base_url":"https://us-west-2.aws.data.mongodb-api.com/app/data-ksjef/endpoint/data/v1/",
	"dataSource":"data-source",
	"database":"database",
}



func _ready():
	var client = HTTPRequest.new()
	add_child(client)
	client.request_completed.connect(self._http_request_completed)
	var headers = PackedStringArray(["apiKey: " + api_key, "Accept: application/json", "Content-Type: application/ejson"])
	var body = {
			"dataSource": "CoasterWorld",
			"database": "CoasterWorld",
			"collection": "Addresses",
			"filter": {
			"address": "127.0.0.1"
			}
	}
	var headers_2 = PackedStringArray(["dataSource: mongodb-atlas", "database: CoasterWorld", "collection: Users", "filter: {'filter':{'address': '127.0.0.1'}}"])
	body = JSON.new().stringify(body)
	var response = client.request(
		"https://us-west-2.aws.data.mongodb-api.com/app/data-ksjef/endpoint/data/v1/action/findOne",
		headers,
		HTTPClient.METHOD_POST,
		body
		)
	
	print(response)

func _http_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	print(response)


func Configure(plugin:Node, config={}, collection_templates={}):
	_plugin = self
	_config = config
	

func CreateCollection(collection):
	print_debug("'CreateCollection' is currently unsupported by MongoDB Atlas, please manage your Collections here: https://cloud.mongodb.com/")

func DeleteCollection(collection):
	print_debug("'DeleteCollection' is currently unsupported by MongoDB Atlas, please manage your Collections here: https://cloud.mongodb.com/")

func Create(collection, document, generate_defaults=true):
	return _plugin.Create(collection, document, generate_defaults)

func Read(collection, filter={}, generate_defaults=true):
	return _plugin.Read(collection, filter, generate_defaults)

func Update(collection, changed_values, filter={}, generate_defaults=true):
	return _plugin.Update(collection, changed_values, filter, generate_defaults)

func Delete(collection, filter={}):
	return _plugin.Delete(collection, filter)

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	return _plugin.FindOrCreate(collection, document, filter, generate_defaults)

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	return _plugin.UpdateOrCreate(collection, document, filter, generate_defaults)


func GenerateHeaders():
	return PackedStringArray(["apiKey: " + api_key, "Accept: application/json", "Content-Type: application/ejson"])

func GenerateBody(collection, filter={}):
	return {
		"dataSource": _config.dataSource,
		"database": _config.database,
		"collection": collection,
		"filter": filter
	}
