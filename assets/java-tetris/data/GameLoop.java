package game.logic;

import java.awt.Point;
import java.util.Arrays;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import game.data.GridData;
import game.data.MovingPieceData;
import game.gui.GameFrame;
import game.logic.timer.PullDelay;
import game.meta.Colors;
import game.meta.Config;
import game.meta.Tetrominoes;
import game.util.MathUtil;

/**
 * Main game loop for the Tetris game. Handles game state updates, input
 * processing, collision detection, and rendering.
 */
public class GameLoop {
	/** Scheduler for running the game loop at fixed intervals. */
	private static final ScheduledExecutorService GameLoopScheduler = Executors.newSingleThreadScheduledExecutor();
	
	/** The main game window and rendering frame. */
	private GameFrame gameFrame;
	/** Handles keyboard input. */
	private Input input;
	/** Manages timing for piece dropping. */
	private PullDelay pullDelay;
	/** Handles collision detection for pieces. */
	private Collision collision;

	/**
	 * Constructor for GameLoop. Initializes the game frame, input handling, pull
	 * delay, and collision detection.
	 */
	public GameLoop() {
		gameFrame = new GameFrame();

		input = new Input(Config.X_DELAY_TIME, Config.R_DELAY_TIME);
		gameFrame.addKeyListener(input);

		pullDelay = new PullDelay(Config.PULL_TIMEOUT, Config.PULL_STRONGER_TIMEOUT);
		pullDelay.start();

		collision = new Collision();
	}

	/**
	 * Creates a new random moving piece with random shape and color.
	 *
	 * @return a new MovingPieceData instance
	 */
	private MovingPieceData getNewMovingPiece() {
		MovingPieceData newPiece = new MovingPieceData();

		int randIndex = MathUtil.getRand(Tetrominoes.getShapes().length);
		newPiece.setShapes(Tetrominoes.getShapes()[randIndex]);

		int colorIndex = MathUtil.getRand(Colors.getColors().length);
		newPiece.setColor(colorIndex);

		newPiece.setPosition(Config.getInitPosition());

		return newPiece;
	}

	/**
	 * Combines the current moving piece with the grid data to produce a new grid
	 * state.
	 *
	 * @param piece the moving piece
	 * @param data  the current grid data
	 * @return a new 2D array representing the combined grid state
	 */
	private int[][] addMovingPieceToData(MovingPieceData piece, int[][] data) {
		Point currentPosition = piece.getPosition();
		int[][] currentShape = piece.getShape();

		int[][] combinedData = new int[Config.ROWS][Config.COLUMNS];
		for (int i = 0; i < data.length; i++) {
			combinedData[i] = Arrays.copyOf(data[i], data[i].length);
		}

		for (int i = 0; i < currentShape.length; i++) {
			for (int j = 0; j < currentShape[i].length; j++) {
				if (currentShape[i][j] != 0) {
					combinedData[currentPosition.y + i][currentPosition.x + j] = currentShape[i][j];
				}
			}
		}
		return combinedData;
	}

	/**
	 * Checks and processes horizontal movement input for the current piece.
	 *
	 * @param newPiece the piece to move
	 * @param data     the current grid data
	 * @return true if a horizontal collision occurred, false otherwise
	 */
	private boolean checkHorizontalMovement(MovingPieceData newPiece, int[][] data) {
		int xChange = input.getXInput();
		if (xChange != 0 && !input.xDelayActive()) {
			input.xDelayStart();
			newPiece.getPosition().x += xChange;
			return collision.checkHorizontalCollision(newPiece, data);
		}
		return false;
	}

	/**
	 * Checks and processes vertical movement input for the current piece.
	 *
	 * @param newPiece the piece to move
	 * @param data     the current grid data
	 * @return true if a vertical collision occurred, false otherwise
	 */
	private boolean checkVerticalMovement(MovingPieceData newPiece, int[][] data) {
		if (input.getYInput()) {
			if (!pullDelay.isSpeedUpActive()) {
				pullDelay.speedUp();
			}
		} else {
			if (pullDelay.isSpeedUpActive()) {
				pullDelay.slowDown();
			}
		}

		return collision.checkVerticalCollision(newPiece, data);
	}

	/**
	 * Updates the grid data based on the current piece's movement, rotation, and
	 * collisions.
	 *
	 * @param gridData the grid data to update
	 */
	private void updateGridData(GridData gridData) {
		int[][] data = gridData.getData();

		MovingPieceData currentPiece = gridData.getCurrentPiece();
		MovingPieceData newPiece = new MovingPieceData(currentPiece);
		if (pullDelay.isPullReady()) {
			if (!pullDelay.isRunning()) {
				pullDelay.start();
			}
			newPiece.moveDown();
		}

		if (input.getRotate() && !input.rDelayActive()) {
			input.rDelayStart();
			newPiece.rotate();

			boolean rotationCollides = collision.collidesWithFloor(newPiece) || collision.collidesWithWall(newPiece)
					|| collision.collidesWithGridData(newPiece, data);

			if (rotationCollides) {
				newPiece = new MovingPieceData(currentPiece);
			}
		}

		boolean collidesHorizontally = checkHorizontalMovement(newPiece, data);
		if (collidesHorizontally) {
			return;
		}

		boolean collidesVertically = checkVerticalMovement(newPiece, data);

		if (collidesVertically && collision.collidesWithCeil(newPiece)) {
			gridData.setGameOver();
		}

		gridData.setDirty(true);
		if (currentPiece.getPosition().y != 0 && currentPiece.isIdentical(newPiece)) {
			gridData.setDirty(false);
			return;
		}

		if (!collidesVertically) {
			currentPiece = newPiece;
			gridData.setCurrentPiece(currentPiece);

			int[][] combinedData = addMovingPieceToData(currentPiece, data);
			gridData.setCombinedData(combinedData);
		} else {
			int[][] combinedData = addMovingPieceToData(currentPiece, data);
			gridData.setCombinedData(combinedData);

			currentPiece = getNewMovingPiece();
			gridData.setCurrentPiece(currentPiece);

			gridData.setData(combinedData);
			return;
		}

		gridData.setData(data);
	}

	/**
	 * Removes all full rows from the grid data and shifts remaining rows down.
	 *
	 * @param gridData the grid data to modify
	 */
	private void removeFullRows(GridData gridData) {
		int[][] data = gridData.getData();
		int[][] cleanData = new int[Config.ROWS][Config.COLUMNS];

		int k = Config.ROWS - 1;
		for (int i = Config.ROWS - 1; i >= 0; i--) {
			boolean fullRow = true;
			for (int j = Config.COLUMNS - 1; j >= 0; j--) {
				int cellData = data[i][j];
				if (cellData == 0) {
					fullRow = false;
					break;
				}
			}
			if (!fullRow) {
				cleanData[k--] = Arrays.copyOf(data[i], Config.COLUMNS);
			}
		}
		gridData.setData(cleanData);
	}

	/**
	 * Renders the grid data to the game frame if the data is marked as dirty.
	 *
	 * @param gridData the grid data to render
	 */
	private void renderGridData(GridData gridData) {
		if (gridData.isDirty()) {
			gameFrame.dataProvider(gridData.getCombinedData());
		}
	}

	/**
	 * Starts and runs the main game loop. Handles piece generation, input, updates,
	 * and rendering.
	 */
	public void run() {
		GridData gridData = new GridData();
		initNewGridData(gridData);

		GameLoopScheduler.scheduleAtFixedRate(() -> {
			removeFullRows(gridData);
			updateGridData(gridData);
			renderGridData(gridData);

			if (gridData.isGameOver()) {
				initNewGridData(gridData);
			}
		}, 0, Config.RENDER_TIMEOUT, TimeUnit.MILLISECONDS);
	}

	/**
	 * Initializes a new grid data instance for a new game.
	 *
	 * @param gridData the grid data to initialize
	 */
	private void initNewGridData(GridData gridData) {
		gridData.initNewData();

		MovingPieceData newMovingPiece = getNewMovingPiece();
		gridData.setCurrentPiece(newMovingPiece);
	}
}