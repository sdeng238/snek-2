import processing.serial.*; // talk to ESP32
import java.util.ArrayList;

Serial port;
int portIndex = 4;

// controller readings
int joystickX = 2048, joystickY = 2048, pot = 0;
boolean button, previousButton, boostReady;

// 30x25 grid of 20-px cells
int cell = 20, cols = 30, rows = 25;
int state = 0; // 0 = start screen, 1 = playing, 2 = game over
int score, elapsed, moveTime, cloudTime, lastFrame;

// current direction = dx/dy
int dx = 1, dy = 0;
// next turn = nextDx/nextDy
int nextDx = 1, nextDy = 0;
boolean turned;
float angle;
String message = "";

// first segment = head, last segment = tail
ArrayList<PVector> snake = new ArrayList<PVector>();
ArrayList<Cloud> clouds = new ArrayList<Cloud>();
PVector apple;

void setup() {
  size(660, 710);

  printArray(Serial.list());
  port = new Serial(this, Serial.list()[portIndex], 9600);
  port.clear();
  
  lastFrame = millis(); // current time
}

void draw() {
  readInputs();

  // time passed since previous frame
  int now = millis();
  int dt = now - lastFrame;
  lastFrame = now;

  // only count a new press if previously released and now pressed
  boolean pressed = button && !previousButton;
  previousButton = button;

  if (state == 0 && pressed) {
    startGame();
  } else if (state == 2 && pressed) {
    state = 0;
  } else if (state == 1) {
    play(dt);
  }

  drawGame();
}

// get latest controller readings
void readInputs() {
  while (port.available() > 0) {
    // read one complete line
    String line = port.readStringUntil('\n');
    if (line == null) break; // wait for the rest of the line

    String[] values = split(trim(line), ',');
    if (values.length != 5) continue;

    // Arduino sends x, y, button, potentiometer
    int x = Integer.parseInt(trim(values[0]));
    int y = Integer.parseInt(trim(values[1]));
    int b = Integer.parseInt(trim(values[3]));
    int p = Integer.parseInt(trim(values[4]));

    joystickX = x;
    joystickY = y;
    pot = p;
    button = b == 0; // INPUT_PULLUP gives 0 when pressed
  }
}

// start new game
void startGame() {
  // remove elements from previous round
  snake.clear();
  clouds.clear();

  // start with 4 segments starting (10, 12)
  for (int i = 0; i < 4; i++) {
    snake.add(new PVector(10 - i, 12));
  }

  // face right
  dx = nextDx = 1;
  dy = nextDy = 0;
  
  // reset score and timers
  score = elapsed = moveTime = cloudTime = 0;
  turned = boostReady = false;
  
  // change game state
  state = 1;
  newApple();
}

// draw frame during game
void play(int dt) {
  // time limit of 1 min
  elapsed += dt;
  if (elapsed >= 60000) {
    endGame("Time's up!");
    return;
  }

  // the button is ready for boosting if not already pressed
  if (!button) {
    boostReady = true;
  }

  // map the potentiometer dial's range (0 to 4095) to a full rotation (-pi to pi)
  angle = map(pot, 0, 4095, -PI, PI);

  // centered joystick = (2048, 2048)
  int x = joystickX - 2048;
  int y = joystickY - 2048;

  // haven't accepted a turn for next movement + ignore small movements near the center
  if (!turned && max(abs(x), abs(y)) > 850) {
    // use whichever axis is tilted farther for requested direction
    int tx = abs(x) > abs(y) ? (x > 0 ? 1 : -1) : 0;
    int ty = abs(x) > abs(y) ? 0 : (y > 0 ? 1 : -1);

    // don't reverse into the body or queue an unchanged direction
    if ((tx != -dx || ty != -dy) && (tx != dx || ty != dy)) {
      nextDx = tx;
      nextDy = ty;
      turned = true; // allow another turn after the next move.
    }
  }

  // add a cloud every 2.4 s
  cloudTime += dt;
  if (cloudTime >= 2400) {
    cloudTime = 0;
    newCloud();
  }

  // aiming the beam can clear a cloud
  clearClouds();
  
  // die if touched poison
  if (inPoison()) {
    endGame("You touched poison.");
    return;
  }

  // holding the button reduces the time between moves
  moveTime += dt;
  if (moveTime >= (button && boostReady ? 68 : 135)) {
    moveTime = 0;
    moveSnake();
  }
}

void moveSnake() {
  dx = nextDx;
  dy = nextDy;
  turned = false;

  // work out where the head would move next
  PVector head = snake.get(0);
  int x = (int)head.x + dx;
  int y = (int)head.y + dy;

  // die if touched edge
  if (x < 0 || x >= cols || y < 0 || y >= rows) {
    endGame("You hit the edge.");
    return;
  }

  // eat apple if head and apple share the same cell
  boolean eating = apple != null && x == apple.x && y == apple.y;

  // check if new head position collide with any body parts
  int segmentsToCheck = snake.size();

  if (!eating) {
    segmentsToCheck--; // don't check the tail that is about to move away
  }
  
  for (int i = 0; i < segmentsToCheck; i++) {
    if (snake.get(i).x == x && snake.get(i).y == y) {
      endGame("You hit your own body.");
      return;
    }
  }

  // add a head and remove the tail to move forward
  // keeping the tail when eating makes the snake grow
  snake.add(0, new PVector(x, y));
  if (!eating) {
    snake.remove(snake.size() - 1);
  }

  // the beam now follows the head's new position
  clearClouds();
  if (inPoison()) {
    endGame("You touched poison.");
    return;
  }

  if (eating) {
    score++;
    newApple();
  }
}

void endGame(String reason) {
  message = reason;
  state = 2;
}

// check whether a circular cloud overlaps a square grid cell
boolean cloudTouchesCell(Cloud c, int x, int y) {
  // find the point in the square closest to the cloud's center
  float cx = constrain(c.x, x * cell, (x + 1) * cell);
  float cy = constrain(c.y, y * cell, (y + 1) * cell);

  // each cloud has a radius of 28 pixels
  return sq(c.x - cx) + sq(c.y - cy) <= 28 * 28;
}

void newApple() {
  ArrayList<PVector> free = new ArrayList<PVector>();

  // collect cells that aren't occupied by the snake or a cloud
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      boolean blocked = false;
      for (PVector s : snake) {
        if (s.x == x && s.y == y) {
          blocked = true;
        }
      }
      for (Cloud c : clouds) {
        if (cloudTouchesCell(c, x, y)) {
          blocked = true;
        }
      }
      if (!blocked) {
        free.add(new PVector(x, y));
      }
    }
  }

  if (free.isEmpty()) {
    apple = null;
    endGame("You filled the garden!");
  } else {
    // choose one of the available cells at random
    apple = free.get((int)random(free.size()));
  }
}

void newCloud() {
  // limit to 7 clouds
  if (clouds.size() >= 7) {
    return;
  }
  PVector h = snake.get(0);

  // try a few locations, then skip this spawn if none work
  for (int i = 0; i < 40; i++) {
    Cloud c = new Cloud(
      random(28, cols * cell - 28),
      random(28, rows * cell - 28)
    );

    // don't cover the apple
    if (apple != null && cloudTouchesCell(c, (int)apple.x, (int)apple.y)) {
      continue;
    }

    // don't spawn right beside the head
    if (dist(c.x, c.y, (h.x + 0.5f) * cell, (h.y + 0.5f) * cell) < 68) {
      continue;
    }

    clouds.add(c);
    return;
  }
}

boolean inPoison() {
  PVector h = snake.get(0);
  for (Cloud c : clouds) {
    // clouds are harmless during their 1.2-second warning
    if (elapsed - c.born >= 1200 && cloudTouchesCell(c, (int)h.x, (int)h.y)) {
      return true;
    }
  }
  return false;
}

void clearClouds() {
  PVector h = snake.get(0);

  // start the beam 18 pixels ahead of the head's center
  float x = (h.x + 0.5f) * cell + cos(angle) * 18;
  float y = (h.y + 0.5f) * cell + sin(angle) * 18;

  // the beam ends 140 pixels from the head: 140 - 18 = 122
  float bx = cos(angle) * 122;
  float by = sin(angle) * 122;

  // go backward so removing a cloud doesn't skip another one
  for (int i = clouds.size() - 1; i >= 0; i--) {
    Cloud c = clouds.get(i);

    // find the closest point on the beam to this cloud
    // t = 0 is the start; t = 1 is the end
    float t = constrain(
      ((c.x - x) * bx + (c.y - y) * by) / (122 * 122), 0, 1
    );

    // cloud radius 28 + half the beam width 6 = 34.
    if (dist(c.x, c.y, x + t * bx, y + t * by) <= 34) {
      clouds.remove(i);
    }
  }
}

void drawGame() {
  // draw the title, score, and remaining time
  background(247, 249, 240);
  fill(42, 66, 38);
  textAlign(LEFT, BASELINE);
  textSize(28);
  text("Snake", 30, 38);
  textSize(18);
  text("Apples: " + score, 30, 75);
  text("Time: " + max(0, (int)ceil((60000 - elapsed) / 1000.0f))
       + "s", 230, 75);

  // draw board objects relative to the board's top-left corner
  pushMatrix();
  translate(30, 125);
  noStroke();
  fill(178, 210, 118);
  rect(0, 0, cols * cell, rows * cell);

  for (Cloud c : clouds) {
    boolean warning = elapsed - c.born < 1200;

    // flash yellow while warning; turn purple when active
    int opacity = (elapsed / 150) % 2 == 0 ? 90 : 180;
    fill(warning ? color(255, 220, 90, opacity)
                 : color(156, 94, 177));
    circle(c.x, c.y, 56);
    fill(warning ? color(100, 66, 5) : color(255));
    textAlign(CENTER, CENTER);
    text(warning ? "!" : "X", c.x, c.y);
  }

  if (apple != null) {
    fill(211, 55, 49);
    circle((apple.x + 0.5f) * cell, (apple.y + 0.5f) * cell, 15);
  }

  // convert the snake's grid positions into pixel positions
  for (int i = snake.size() - 1; i >= 0; i--) {
    PVector s = snake.get(i);
    fill(i == 0 ? color(25, 86, 48) : color(48, 122, 61));
    rect(s.x * cell + 1, s.y * cell + 1, 18, 18, 3);
  }

  if (!snake.isEmpty()) {
    PVector h = snake.get(0);
    float x = (h.x + 0.5f) * cell;
    float y = (h.y + 0.5f) * cell;

    // keep the beam drawing inside the board
    clip(0, 0, cols * cell, rows * cell);
    stroke(23, 89, 160);
    strokeWeight(12);
    line(x + cos(angle) * 18, y + sin(angle) * 18,
         x + cos(angle) * 140, y + sin(angle) * 140);
    noClip();
    noStroke();
    strokeWeight(1);
  }

  // return to window coordinates for instructions and menus
  popMatrix();
  fill(65, 83, 57);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("Joystick: steer   Button: speed up   Dial: aim beam",
       width / 2, 651);

  if (state != 1) {
    fill(255, 253, 242);
    rect(45, 270, 570, 200, 4);
    fill(37, 78, 42);
    textSize(24);
    text(state == 0 ? "Snake" : message, width / 2, 315);
    textSize(17);
    text(state == 2 ? "Apples collected: " + score
                   : "Collect apples and avoid the poison.",
         width / 2, 370);
    textSize(14);
    text(state == 2 ? "Press the button to return to the start screen"
                   : "Press the button to start",
         width / 2, 425);
  }
}

// store each cloud's position and when it appeared
class Cloud {
  float x, y;
  int born;

  Cloud(float x, float y) {
    this.x = x;
    this.y = y;
    born = elapsed;
  }
}
