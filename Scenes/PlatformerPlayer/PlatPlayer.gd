extends CharacterBody2D
class_name PlatPlayer

@export var GROUND_SPEED = 300.0
@export var AIR_SPEED = 300.0
@export var GROUND_FRICTION = 300.0


@export var JUMP_VELOCITY = -400.0
@export var push_force = 100
@export var side = 0
@export var directionOffsetZ = 75.0

var collindingNode : Node2D = null
var pickedItem : PickupComponent = null

var isHittingDivider = false
var lastDirection = 1
var jumpAnimationEnd = false

@onready var animationRed : AnimationPlayer = $Player_rosso/AnimationPlayerRosso

@onready var handsWithObjects : Sprite2D = $Player_rosso/BracciaRossoSu
@onready var handLeft : Sprite2D = $Player_rosso/BracciaRossoSx
@onready var handRight : Sprite2D = $Player_rosso/BraccioRossoDx

@onready var animationBlue : AnimationPlayer = $Player_blu/AnimationPlayerBlu

@onready var handsWithObjectsBlue : Sprite2D = $Player_blu/BracciaBluSu
@onready var handLeftBlue : Sprite2D = $Player_blu/BracciaBluSx
@onready var handRightBlue : Sprite2D = $Player_blu/BracciaBluDx

signal died

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	Global.setPlayer(side, self)
	
	animateIdle()
		
	jumpAnimationEnd = true
	
	holdObjectAnimation(false)

func animateIdle():
	match side:
		0:
			animationRed.play("Idle")
			animationRed.connect("animation_finished", _on_anim_finish)
		1:
			animationBlue.play("Idle")
			animationBlue.connect("animation_finished", _on_anim_finish)

func holdObjectAnimation(active):
	var handsUp = handsWithObjects
	var sx = handLeft
	var dx = handRight
	
	match side:
		0:
			handsUp = handsWithObjects
			sx = handLeft
			dx = handRight
		1:
			handsUp = handsWithObjectsBlue
			sx = handLeftBlue
			dx = handRightBlue
	
	if active:
		handsUp.show()
		sx.hide()
		dx.hide()
	else:
		handsUp.hide()
		sx.show()
		dx.show()

func _on_anim_finish(animation):
	match animation:
		"Jump":
			jumpAnimationEnd = true

func getActiveAnimationPlayer():
	match side:
		0:
			return animationRed
		1:
			return animationBlue

func _physics_process(delta):
	if Global.currentGameState != Global.GameState.IN_GAME:
		return
		
	if pickedItem != null:
		var pickupMarker : Marker2D = $PickupPosition
		match side:
			0:
				pickupMarker = $PickupPosition
			1:
				pickupMarker = $PickupPositionBlue
		
		pickedItem.setPosition(position + (pickupMarker.position) * scale)
		pickedItem.setScale(lastDirection < 0)
		
	#Animation code
	if pickedItem != null:
		holdObjectAnimation(true)
	else:
		holdObjectAnimation(false)
				
	var moveSpeed = GROUND_SPEED
	
	if not is_on_floor():
			moveSpeed = AIR_SPEED
			velocity.y += gravity * delta
#	$PointLight2D.enabled = false
			
	if Global.activePlayer == side:

#		$PointLight2D.enabled = true
		# Handle Jump.
		if Input.is_action_just_pressed("Jump") and is_on_floor():
			getActiveAnimationPlayer().play("Jump")
			jumpAnimationEnd = false
			velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		# Todo change controls
		var direction = Input.get_axis("MoveLeft", "MoveRight")
		if direction:
			velocity.x = direction * moveSpeed
			lastDirection = direction
			
			if jumpAnimationEnd == true:
				getActiveAnimationPlayer().play("Walk")
		else:
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION)
			if jumpAnimationEnd == true:
				getActiveAnimationPlayer().play("Idle")
		
		match side:
			0:
#				scale.x = scale.y * sign(lastDirection)
				$Player_rosso.scale.x = $Player_rosso.scale.y * sign(lastDirection)
				$Area2D/Red.position.x = sign(lastDirection) * directionOffsetZ
			1:
#				scale.x = scale.y * sign(lastDirection) * -1
				$Player_blu.scale.x = $Player_blu.scale.y * sign(lastDirection) * -1
				$Area2D/Blue.position.x = sign(lastDirection) * directionOffsetZ
		
		for index in get_slide_collision_count():
			var collision = get_slide_collision(index)
			if collision.get_collider() is RigidBody2D:
				collision.get_collider().apply_central_impulse(-collision.get_normal() * push_force)
		
		#Pick up and drop items
		if Input.is_action_just_pressed("Pickup") :
			if pickedItem != null :
				
				if isHittingDivider:
					return
				
				#drop the item
				var parent = pickedItem.get_parent()
				if parent is RigidBody2D:
					parent.linear_velocity = Vector2.ZERO
					parent.angular_velocity = 0
				
				var itemScale = pickedItem.scale
				
				var colliderHand = $Area2D/Red
				match side:
					0:
						colliderHand = $Area2D/Red
					1:
						colliderHand = $Area2D/Blue
				
				colliderHand.position.x = sign(lastDirection) * directionOffsetZ
				
				var newPos = position + (colliderHand.position * scale)
				pickedItem.setPosition(newPos)
				pickedItem.held = false
				#pickedItem.setCollisions(true)
				
				pickedItem = null
				collindingNode = null
				
			if collindingNode != null && pickedItem == null:
				pickupItem(collindingNode)
			
				
	if move_and_slide():
		var collision = get_last_slide_collision()
		var collider = collision.get_collider()
		if collider.has_node("DeathComponent"):
			print("Death ", collision.get_collider().name)
			died.emit()
		

func pickupItem(item):
	pickedItem = item
	pickedItem.held = true
	pickedItem.setCollisions(false)
	
	var parent = item.get_parent()
	if parent is RigidBody2D:
		parent.linear_velocity = Vector2.ZERO
		parent.angular_velocity = 0
		parent.rotation_degrees = 0

func dropItem(): #TODO change this to transferItem or something
	pickedItem = null
	collindingNode = null

func _on_area_2d_area_entered(area):
	print("Area Entered %s" % area.name)
	var rootNode = area.get_parent()
	if rootNode != null :
		for group in rootNode.get_groups():
			print("root node %s" % rootNode.name)
			match group:
				"Pickable":
					#now the pickable need to get the father
					if area is PickupComponent:
						collindingNode = area
						collindingNode.highlight()
					return
				"Dividers":
					print("Hitting devider")
					isHittingDivider = true
					return
				_ :
					collindingNode = null
	pass # Replace with function body.


func _on_area_2d_area_exited(area):
	print("Area Exit %s" % area.name)
	var rootNode = area.get_parent()
	if rootNode != null :
		for group in rootNode.get_groups():
			print("root node %s" % rootNode.name)
			match group:
				"Dividers":
					print("Exit divider")
					isHittingDivider = false
				_ :
					collindingNode = null
	pass # Replace with function body.


func _on_area_2d_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	print("PatPLayer _on_area_2d_body_shape_entered %s" % body.name)
	pass # Replace with function body.
