extends Area2D
class_name ButtonComponent

@export var receivers : Array[Node2D]
@export var senderComp : SenderComponent

var active = false;

# Called when the node enters the scene tree for the first time.
func _ready():
	if senderComp != null:
		for node in receivers:
			var receiverComp = node.get_node("ReceiverComponent")
			if receiverComp != null:
				print("%s - Register receiver %s" % name, receiverComp.name)
				senderComp.addReceiver(receiverComp)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if active:
		$Sprite2D.modulate = Color.GREEN_YELLOW
	pass

func _on_area_entered(area):
	print("%s _on_area_entered:" % name)
#	senderComp.activate()
	pass # Replace with function body.

func _on_body_entered(body):
	print("%s _on_body_entered:" % name)
	if active == false:
		active = true
		senderComp.activate()
	pass # Replace with function body.

#func _on_body_exited(body):
#	print("%s _on_body_exited:" % name)
#	numOfObject -= 1
#	if numOfObject <= 0:
#		senderComp.present(false)
#	pass # Replace with function body.

#func _on_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
#	print("%s _on_body_shape_entered:" % name)
#	pass # Replace with function body.
