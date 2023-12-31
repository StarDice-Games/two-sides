extends Node2D

var simpleVar : int = 3
var array : Array = [1, 2, 3]
var scorep1 : int = 0;
var scorep2 : int = 0;

var activePlayer = 0; #Change with an enum to be player left = 0 or right=0

var players : Array[CharacterBody2D] = [null, null]
var goals : Array[Node2D] = [null, null]

@export_category("Menus")
@export var useMenu = true
@export var showSplash = true
@export var scenes : Array[LevelResourceBase]
@export var splashScreen : PackedScene
@export var mainMenuScene : PackedScene
@export var pauseMenuScene : PackedScene
@export var mainScene : PackedScene
@export var selectLevelScene : PackedScene
@export var creditsScene : PackedScene
@export var levelTransitionScene : PackedScene
#@export var endLevel : PackedScene
@export var endCredits : PackedScene

@export_category("Audio")
@export var musicMuted = false
@export var sfxMuted = false
@export var levelStartSound : AudioStream
@export var tranferSound : AudioStream
@export var levelCompleteSound : AudioStream
@export var levelSelectionSound : AudioStream

@export var menuMusic : AudioStream
@export var inGameMusicBig : AudioStream
@export var inGameMusicSmall : AudioStream

@export var menuButtonPress : AudioStream
@export var menuButtonSelect : AudioStream
@export var resumeSound : AudioStream

@onready var bgMenuMusic : AudioStreamPlayer = $BackgroundMusic1
@onready var bgInGameMusic : AudioStreamPlayer = $SmallMusic #Small
@onready var bgInGameMusic2 : AudioStreamPlayer = $BigMusic #Big
@onready var audioAnimator : AnimationPlayer = $AnimationPlayer


var timerCallback : Callable
var nodeInstance = null
var next_scene = 1

enum GameState {
	MAIN_MENU,
	PAUSE,
	LEVEL_SELECT,
	IN_GAME,
	LEVEL_COMPLETE,
	START_LEVEL,
	SPLASH_SCREEN,
	CREDITS,
}

enum Scaling {
	INCREASE,
	DECREASE
}

var currentGameState = GameState.SPLASH_SCREEN

var completedLevels = {}
var curretLevel = ""

func playSelectButton():
	if not sfxMuted:
		AudioManager.play(menuButtonSelect)

func isLevelComplete(key):
	if completedLevels.has(key):
		return completedLevels.get(key) == true
	return false

# Called when the node enters the scene tree for the first time.
func _ready():	
	if scenes.size() > 0:
		curretLevel = scenes[0].name
		next_scene %= scenes.size() #adapt the next_scene based on the total scenes
	print("Global ready")
	
	#testing not sure if it's ok
	if pauseMenuScene != null:		
		nodeInstance = pauseMenuScene.instantiate()
	else:
		printerr("Error missing pause scene")
		
	bgMenuMusic.stream = menuMusic
	bgMenuMusic.play()
	
	bgInGameMusic.stream = inGameMusicBig #Bgi
	bgInGameMusic2.stream = inGameMusicSmall #Small
	
	
	pass # Replace with function body.


func openMainMenu():
	if mainMenuScene.can_instantiate():
		var mainMenuInstance = mainMenuScene.instantiate()
		get_tree().root.add_child(mainMenuInstance)
		mainMenuInstance.connect("exit_pressed", _on_main_menu_exit_pressed)
		mainMenuInstance.connect("new_game_pressed", _on_main_menu_new_game_pressed)
		mainMenuInstance.connect("select_level_ressed", _on_main_menu_select_level_pressed)
		mainMenuInstance.connect("open_credits", _on_main_menu_credits)
	
		currentGameState = GameState.MAIN_MENU
	
func closeMainMenu():
	var node = get_tree().root.get_node("MainMenu")
	if node != null:
		get_tree().root.remove_child(node)

func openSplash():
	if splashScreen.can_instantiate():
		var splashInstance = splashScreen.instantiate()
		get_tree().root.add_child(splashInstance)
		splashInstance.connect("end_splash", _on_splash_end)
		
func closeSplash():
	var node = get_tree().root.get_node("SplashScreen")
	if node != null:
		get_tree().root.remove_child(node)
	
func _on_splash_end():
	closeSplash()
	if useMenu:
		openMainMenu()
	else:
		currentGameState = GameState.IN_GAME

func setPlayer(number, player : CharacterBody2D):
	players[number] = player
	#also connect the died event
	players[number].connect("died", onPlayerDeath)
	
func setGoal(number, goal : Node):
	goals[number] = goal
	
func getPlayer(index):
	return players[index]

func changeActivePlayer():
	match activePlayer:
			0 : 
				players[0].stopAnimation()
				activePlayer = 1
				
#				bgInGameMusic.volume_db = 0
#				bgInGameMusic2.volume_db = 0
				if not musicMuted: 
					audioAnimator.play("FadeToBig")
			1 : 
				players[1].stopAnimation()
				activePlayer = 0
				if not musicMuted:
					audioAnimator.play("FadeToSmall")
#				bgInGameMusic.volume_db = 0
#				bgInGameMusic2.volume_db = -80
				
func setActivePlayer(number):
	activePlayer = number

func goalIsAchieved(goal):
	if goal == null :
		return false
		
	return goal.achieved 

func transferPickable(starting, receiver, scaling : Scaling):
	#do not transfer if the other player has an item
	if receiver == null or receiver.pickedItem != null:
		return
	
	AudioManager.play(tranferSound)
#	the picket item is changed and transfered
#	now the picked item need to call this on the parent node
	var toTransfer : Node2D = starting.pickedItem
#	var parent = toTransfer.get_parent()
	if toTransfer != null:
		if scaling == Scaling.INCREASE: #toRightSide
			toTransfer.setSide(0)
		elif scaling == Scaling.DECREASE: #toLeftSide
			toTransfer.setSide(1)
			
		#KEVIN TEST SWIPE ANIMATION	
		if toTransfer != null:
			$Explosion_Left.frame = 0
			$Explosion_Right.frame = 0
			
			$Explosion_Left.position.x = receiver.position.x
			if scaling == Scaling.INCREASE: #toRightSide
				$Explosion_Left.position.y = receiver.position.y-50
			else:
				$Explosion_Left.position.y = receiver.position.y-100
				
			$Explosion_Right.position.x = starting.position.x
			if scaling == Scaling.DECREASE: #toRightSide
				$Explosion_Right.position.y = starting.position.y-50
			else:
				$Explosion_Right.position.y = starting.position.y-100

			$Explosion_Left.play()
			$Explosion_Right.play()
		
		receiver.pickupItem(toTransfer)
		starting.dropItem()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	match currentGameState:
		GameState.MAIN_MENU:
			processMainMenu(delta)
			pass
		GameState.PAUSE:
			processPause(delta)
			pass
		GameState.LEVEL_SELECT:
			pass
		GameState.IN_GAME:
			processGame(delta)
			pass
		GameState.SPLASH_SCREEN:
			processSplash()
			pass
	
	if musicMuted:
		bgMenuMusic.volume_db = -80
		bgInGameMusic.volume_db = -80
		bgInGameMusic2.volume_db = -80
	else:
		bgMenuMusic.volume_db = 0
		match activePlayer:
			0 : 
				bgInGameMusic2.volume_db = -80
				bgInGameMusic.volume_db = 0
			1 : 
				bgInGameMusic2.volume_db = 0
				bgInGameMusic.volume_db = -80

func processSplash():
	if get_tree().root.get_node("SplashScreen") == null:
		if showSplash:
			openSplash()
		else :
			if useMenu:
				openMainMenu()
			else:
				currentGameState = GameState.IN_GAME

func processGame(delta):
#	if Input.is_action_just_pressed("ChangePlayer") :
#		for player in players:
#			if player == null:
#				continue
#			player.velocity = Vector2.ZERO
#		changeActivePlayer()
	
	if Input.is_action_just_pressed("ChangePlayerLeft") :
		setActivePlayer(0)
	
	if Input.is_action_just_pressed("ChangePlayerRight") :
		setActivePlayer(1)
	
	if Input.is_action_just_pressed("SwapPickable") :
		match activePlayer: #TODO move this in a function, to remove duplicate code
			0 :
				if not players[0] == null:
					var startingPlayer = players[0]
					var receivingPlayer = players[1]
					
					transferPickable(startingPlayer, receivingPlayer, Scaling.INCREASE)
			1 :
				if not players[1] == null:
					var startingPlayer = players[1]
					var receivingPlayer = players[0]
					
					transferPickable(startingPlayer, receivingPlayer, Scaling.DECREASE)
		if players[activePlayer] != null:
			players[activePlayer].velocity = Vector2.ZERO
		changeActivePlayer()
	
	#Check if the level is complete
	var levelComplete = goals.all(goalIsAchieved)
	
	if levelComplete:
		print("Level is complete !!!", scenes.size())
		currentGameState = GameState.LEVEL_COMPLETE
		
		for player in players:
			player.manageWaitLeft(false)
			player.manageWaitRight(false)
		
		if sfxMuted:
			loadNextLevel()
		else:
			playSoundAndWait(levelCompleteSound)
			timerCallback = loadNextLevel
#		#TODO animation

	#TODO remove this
	if Input.is_action_just_pressed("ChangeLevelDebug"):
		get_tree().change_scene_to_packed(scenes[next_scene].scene)

	if Input.is_action_just_pressed("ResetLevel"):
		get_tree().reload_current_scene()
	pass
	
	if Input.is_action_just_pressed("Pause"):
		#Add the packed scene to the root, so its on top and stop the game
		get_tree().root.add_child(nodeInstance)
		currentGameState = GameState.PAUSE
		nodeInstance.connect("on_resume_pressed", resumeGame)
		nodeInstance.connect("on_restart_pressed", restartLevel)
		nodeInstance.connect("on_exit_pressed", exitGame)
		bgInGameMusic.stream_paused = true
		bgInGameMusic2.stream_paused = true
		
	

func loadNextLevel():
	if scenes[next_scene] != null:
			completedLevels[curretLevel] = true
			curretLevel = scenes[next_scene].name
			get_tree().change_scene_to_packed(scenes[next_scene].scene)
			next_scene += 1
			next_scene %= scenes.size()
			
			setActivePlayer(0)
			
			openLevelTransition(GameState.IN_GAME)

func processMainMenu(delta):
	if get_tree().root.get_node("MainMenu") == null:
		openMainMenu()

func processPause(delta):
	if Input.is_action_just_pressed("Pause"):
		resumeGame()
	pass

func processLevelSelect(delta):
	pass

func toggleNode(node, state):
	if state:
		node.show()
		node.process_mode = PROCESS_MODE_INHERIT
	else:
		node.hide()
		node.process_mode = PROCESS_MODE_DISABLED

func onPlayerDeath():
	print("Player Died")
	
	if curretLevel == "level_end":
		get_tree().change_scene_to_packed(endCredits)
		return
	get_tree().reload_current_scene()

#func restartFromTheMenu():
#	backToMainMenu()


func _on_main_menu_exit_pressed():
	print("Quit the game")
	get_tree().quit()
	pass # Replace with function body.

func _on_main_menu_new_game_pressed():
	print("Start the game")
	startGame()
	pass

func startGame():
	
	#change the status
	activePlayer = 0
	bgMenuMusic.stop()
		
	currentGameState = GameState.START_LEVEL
	
	if not sfxMuted:
		AudioManager.play(levelStartSound)
		$Timer.start(1)
		timerCallback = startLevelAfterJingle
	else:
		startLevelAfterJingle()

func startLevelAfterJingle():
	closeMainMenu()
	
	bgInGameMusic.play()
	bgInGameMusic2.play()
	
	if scenes.size() > 0:
		curretLevel = scenes.front().name
		get_tree().change_scene_to_packed(scenes.front().scene)
		
	openLevelTransition(GameState.IN_GAME)

func openLevelTransition(stateAfterTransition : GameState):
	if levelTransitionScene == null:
		levelTransitionEnded(stateAfterTransition)
		return
		
	if levelTransitionScene.can_instantiate():
		var levelTransitionInstance = levelTransitionScene.instantiate()
		get_tree().root.add_child(levelTransitionInstance)
		levelTransitionInstance.connect("fadeOut_completed", levelTransitionEnded.bind(stateAfterTransition))	
	pass

func levelTransitionEnded(stateAfterTransition : GameState):
	var node = get_tree().root.get_node("LevelTransition")
	if node != null:
		get_tree().root.remove_child(node)
		
	currentGameState = stateAfterTransition
	pass

func _on_main_menu_select_level_pressed():
	print("Select levels")
	AudioManager.play(menuButtonPress)
	if scenes.size() > 0:
		closeMainMenu()
		currentGameState = GameState.LEVEL_SELECT
		var levelSelectInstance = selectLevelScene.instantiate()
		get_tree().root.add_child(levelSelectInstance)
		levelSelectInstance.setItems(scenes)
		levelSelectInstance.connect("on_level_selected", loadSelectedLevel)
		levelSelectInstance.connect("on_back", backToMainMenu)
		

func resumeGame():
	print("Resume the current game")
	AudioManager.play(resumeSound)
	currentGameState = GameState.IN_GAME
	bgInGameMusic.stream_paused = false
	bgInGameMusic2.stream_paused = false
	
	var pauseNode = get_tree().root.get_node("PauseMenu")
	if pauseNode != null:
		get_tree().root.remove_child(pauseNode)

func restartLevel():
	print("restart the current game")
	AudioManager.play(menuButtonPress)
	currentGameState = GameState.IN_GAME
	
	#TODO reset the status of the player
	activePlayer = 0
	
	var pauseNode = get_tree().root.get_node("PauseMenu")
	if pauseNode != null:
		get_tree().root.remove_child(pauseNode)
		
	get_tree().reload_current_scene()

func exitGame():
	print("back to the main menu")
	AudioManager.play(menuButtonPress)
	currentGameState = GameState.MAIN_MENU
	bgMenuMusic.play()
	bgInGameMusic.stop()
	bgInGameMusic2.stop()
	
	var pauseNode = get_tree().root.get_node("PauseMenu")
	if pauseNode != null:
		get_tree().root.remove_child(pauseNode)
		
	openMainMenu()
	
	#load the main scene ? or add the main menu as before ?
	if mainScene != null:
		get_tree().change_scene_to_packed(mainScene)
	else:
		push_error("Main scene missing in Global")

func loadSelectedLevel(res : LevelResourceBase):
	print("Load level index")
	if res != null:
#		AudioManager.play(levelStartSound)
		currentGameState = GameState.START_LEVEL
		
		if not sfxMuted:
			playSoundAndWait(levelStartSound)
			timerCallback = startAfterLevelSelection.bind(res)
		else:
			startAfterLevelSelection(res)

func startAfterLevelSelection(res : LevelResourceBase):
	activePlayer = 0
	bgMenuMusic.stop()
	bgInGameMusic.play()
	bgInGameMusic2.play()
	
	var sceneToLoad = res.scene
	var selectLevelNode = get_tree().root.get_node("SelectLevel")
	if selectLevelNode != null:
		get_tree().root.remove_child(selectLevelNode)
	
	if sceneToLoad != null:
		curretLevel = res.name
		var currentLevel = scenes.find(res)
		
		next_scene = currentLevel + 1
		next_scene %= scenes.size()
		
		get_tree().change_scene_to_packed(sceneToLoad)
	
	openLevelTransition(GameState.IN_GAME)
	
#	currentGameState = GameState.IN_GAME
	pass

func playSoundAndWait(sound: AudioStream):
	if sound == null:
		return
	AudioManager.play(sound)
	$Timer.start(sound.get_length())

func backToMainMenu():
	print("back to the main menu")
	AudioManager.play(menuButtonPress)
	currentGameState = GameState.MAIN_MENU
	
	var selectLevelNode = get_tree().root.get_node("SelectLevel")
	if selectLevelNode != null:
		get_tree().root.remove_child(selectLevelNode)
		
	openMainMenu()
	
	#load the main scene ? or add the main menu as before ?
	if mainScene != null:
		get_tree().change_scene_to_packed(mainScene)
	else:
		push_error("Main scene missing in Global")

func nop():
	pass

func _on_timer_timeout():
	timerCallback.call()
	timerCallback = nop
	pass # Replace with function body.

func onMenuButtonPress():
	AudioManager.play(menuButtonPress)

func _on_main_menu_credits():
	closeMainMenu()
	currentGameState = GameState.CREDITS
	var creditsInstance = creditsScene.instantiate()
	get_tree().root.add_child(creditsInstance)
	creditsInstance.connect("close_credits", closeCredits)

func closeCredits():
	print("back to the main menu")
	AudioManager.play(menuButtonPress)
	currentGameState = GameState.MAIN_MENU
	
	var creditsNode = get_tree().root.get_node("Credits")
	if creditsNode != null:
		get_tree().root.remove_child(creditsNode)
		
	openMainMenu()
	
	#load the main scene ? or add the main menu as before ?
	if mainScene != null:
		get_tree().change_scene_to_packed(mainScene)
	else:
		push_error("Main scene missing in Global")

func playLevelSelectionSound():
	if not sfxMuted:
		AudioManager.play(levelSelectionSound)
