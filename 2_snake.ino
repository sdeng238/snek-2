int xyzPins[] = {39, 32, 33};   // x, y, z(switch) pins
int potPin = 36; // potentiometer
int butPin = 2; // button

int prevButVal = HIGH; // previous button reading (LOW=pressed, HIGH=released)
int stableButVal = HIGH; // button reading accepted after unchanged for 25 ms
unsigned long lastChanged = 0; // time (ms) when button reading last changed
unsigned long lastSent = 0; // time (ms) when ESP32 last sent sensor readings

void setup() {
  Serial.begin(9600);

  pinMode(xyzPins[2], INPUT_PULLUP);
  pinMode(butPin, INPUT_PULLUP); 
}
void loop() {
  // joystick reading
  int xVal = analogRead(xyzPins[0]);
  int yVal = analogRead(xyzPins[1]);
  int zVal = digitalRead(xyzPins[2]);

  // potentiometer reading
  int pVal = analogRead(potPin);

  // button reading
  int curButVal = digitalRead(butPin); // button reading right now
  unsigned long now = millis(); // current time (ms) since ESP32 started

  // detect and record button reading change
  if (curButVal != prevButVal) {
    lastChanged = now;
    prevButVal = curButVal;
  }

  // update button reading after held for 25 ms
  if (now - lastChanged >= 25) {
    stableButVal = curButVal;
  }

  // send all readings every 30 ms
  if (now - lastSent >= 30) {
    lastSent = now;

    Serial.printf("%d,%d,%d,%d,%d\n", xVal, yVal, zVal, stableButVal, pVal);
  }
}