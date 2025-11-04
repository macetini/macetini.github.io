import managers.InputManager;
import flash.display.Sprite;
import flash.events.Event;
import items.GameItem;
import items.Hero;
import items.Platform;
import managers.CollisionManager;
import managers.DifficultyManager;
import managers.HUDManager;
import managers.HeroManager;
import managers.PlatformManager;
import managers.SpawnManager;
import spawn.Boost;
import spawn.Fly;
import spawn.SpawnItem;

/**
	Main class is the entry point of the Doodle Jump game.
	 
	Responsibilities:
	- Initializes display layers for platforms, spawns, hero, and HUD.
	- Creates and manages game managers for platforms, spawns, hero, HUD, collision, and difficulty.
	- Handles the main game loop, including updating game state, spawning items, collision detection, and HUD updates.

	Layers:
	- platformsLayer: Sprite container for platform objects.
	- spawnsLayer: Sprite container for spawnable items (e.g., boosts, flies).
	- heroLayer: Sprite container for the hero character.
	- hudLayer: Sprite container for HUD elements.

	Managers:
	- platformManager: Handles platform creation, recycling, and positioning.
	- spawnManager: Manages spawnable items, their creation, recycling, and positioning.
	- heroManager: Controls hero creation, movement, and state.
	- inputManager: Handles user input and updates hero movement.
	- hudManager: Manages HUD display and updates.
	- collisionManager: Detects and handles collisions between game objects.
	- difficultyManager: Adjusts game difficulty and tracks player progress.

	TODO - Implement state manager to handle game state transitions and persist data between levels.

	@version 1.0
	@date 2023-10-01
	@author Marko Cettina
**/
class Main extends GameItem {
	var platformsLayer:Sprite;
	var spawnsLayer:Sprite;
	var heroLayer:Sprite;
	var hudLayer:Sprite;

	var platformManager:PlatformManager;
	var spawnManager:SpawnManager;
	var heroManager:HeroManager;

	var inputManager:InputManager;
	var hudManager:HUDManager;

	var collisionManager:CollisionManager;
	var difficultyManager:DifficultyManager;

	/**
		Constructor for Main.
		Initializes the base GameItem.
	**/
	public function new() {
		super();
	}

	/**
		Called when the Main object is added to the stage.
		Initializes layers and managers, then adds platforms and hero.
		@param event Event triggered when added to stage.
	**/
	override public function addedToStage(event:Event) {
		super.addedToStage(event);

		createAndAddLayers();
		createManagers();
		addPlatforms();
		addHero();
	}

	/**
		Creates and adds display layers for platforms, spawns, hero, and HUD.
	**/
	function createAndAddLayers() {
		platformsLayer = addNewLayer();
		spawnsLayer = addNewLayer();
		heroLayer = addNewLayer();
		hudLayer = addNewLayer();
	}

	/**
		Helper to create a new Sprite layer and add it to the display list.
		@return The newly created Sprite layer.
	**/
	function addNewLayer():Sprite {
		var newLayer:Sprite = new Sprite();
		this.addChild(newLayer);

		return newLayer;
	}

	/**
		Instantiates all game managers and assigns them to their respective layers.
	**/
	function createManagers() {
		platformManager = new PlatformManager(platformsLayer);
		spawnManager = new SpawnManager(spawnsLayer);
		heroManager = new HeroManager(heroLayer);

		inputManager = new InputManager(this.stage);
		hudManager = new HUDManager(hudLayer);

		collisionManager = new CollisionManager();
		difficultyManager = new DifficultyManager();
	}

	/**
		Adds initial platforms to the game using PlatformManager.
	**/
	function addPlatforms() {
		platformManager.addPlatforms();
	}

	/**
		Adds the hero character to the game using HeroManager.
	**/
	function addHero() {
		heroManager.addHero();
	}

	/**
		Main game loop, called every frame.
		Handles recycling, spawning, collision, movement, HUD, and platform visibility.
		@param deltaTime Time elapsed since last frame.
	**/
	override public function update(deltaTime:Float) {
		super.update(deltaTime);

		recycleExpiredItems();

		generateSpawn(deltaTime);

		checkCollision();

		updateHorizontalChange();

		updateInput();

		updateHud();

		addSoonVisiblePlatforms();
	}

	/**
		Removes or recycles expired platforms and spawn items.
	**/
	function recycleExpiredItems() {
		platformManager.recycleExpiredPlatforms();
		spawnManager.recycleExpiredSpawn();
	}

	/**
		Handles logic for spawning new items based on game state and timeouts.
		@param deltaTime Time elapsed since last frame.
	**/
	function generateSpawn(deltaTime:Float) {
		spawnManager.updateTimeOut(deltaTime);

		var newSpawn:SpawnItem = spawnManager.getNewSpawnItem();

		if (newSpawn != null) {
			if (Std.is(newSpawn, Boost)) {
				var boostablePlatform:Platform = platformManager.returnLastBoostablePlatform();
				spawnManager.addBoostSpawn(newSpawn, boostablePlatform);
				return;
			}

			if (Std.is(newSpawn, Fly)) {
				spawnManager.addSpawnItem(newSpawn);
				return;
			}
		}
	}

	/**
		Checks for collisions between the hero and other objects (spawns, boosts, platforms).
	**/
	function checkCollision() {
		var liveSpawnItems:Array<SpawnItem> = spawnManager.getLiveSpawn();
		var hero:Hero = heroManager.hero;

		var isColliding:Bool = collisionManager.checkCollidingWithSpawn(hero, liveSpawnItems);

		if (isColliding) {
			return;
		}

		if (heroManager.horizontalChange <= 0) {
			isColliding = collisionManager.checkCollidingWithBoost(hero, liveSpawnItems);
			if (isColliding) {
				return;
			}

			var visiblePlatforms:List<Platform> = platformManager.getVisiblePlatforms();
			isColliding = collisionManager.checkCollidingWithPlatform(hero, visiblePlatforms);

			if (isColliding) {
				return;
			}
		}
	}

	/**
		Updates horizontal movement and related game state, including platform and spawn positions and HUD height.
	**/
	function updateHorizontalChange() {
		var newHorizontalChange:Float = heroManager.updateHorizontalChange();

		if (newHorizontalChange > 0) {
			platformManager.updatePlatformsHorizontalPosition(newHorizontalChange);
			spawnManager.updateSpawnHorizontalPosition(newHorizontalChange);

			var newHeight:Float = difficultyManager.increaseHeight(newHorizontalChange);

			hudManager.updateHeight(newHeight);
		}
	}

	/**
		Updates input manager to handle user input.
	**/
	function updateInput() {
		inputManager.update();
	}

	/**
		Updates HUD elements based on game state, hides initial text when movement starts.
	**/
	function updateHud() {
		var horizontalChange:Float = heroManager.horizontalChange;

		if (horizontalChange != 0) {
			hudManager.hideInitText();
		}
	}

	/**
		Adds platforms that are about to become visible.
	**/
	function addSoonVisiblePlatforms() {
		platformManager.addSoonVisiblePlatforms();
	}
}