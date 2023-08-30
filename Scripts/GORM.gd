extends Node


var _config = {}
@onready var _plugin = $MongoDBAtlas

func Configure(plugin:Node, config={}, collection_templates={}):
	_plugin = plugin
	_config = config
	
	plugin.Configure(config, collection_templates)

func CreateCollection(collection):
	_plugin.CreateCollection(collection)
	
func DeleteCollection(collection):
	return _plugin.DeleteCollection(collection)

func Create(collection, document, generate_defaults=true):
	return _plugin.Create(collection, document, generate_defaults)

func Read(collection, filter={}, generate_defaults=true):
	if _plugin == $MongoDBAtlas:
		return await _plugin.Read(collection, filter, generate_defaults)
	
	return _plugin.Read(collection, filter, generate_defaults)

func Update(collection, changed_values, filter={}, generate_defaults=true):
	return _plugin.Update(collection, changed_values, filter, generate_defaults)

func Delete(collection, filter={}):
	return _plugin.Delete(collection, filter)

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	return _plugin.FindOrCreate(collection, document, filter, generate_defaults)

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	return _plugin.UpdateOrCreate(collection, document, filter, generate_defaults)



