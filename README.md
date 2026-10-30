# Snek 2
An ESP32-controlled Snake game built with Processing, featuring speed boosts, randomly spawning poisonous clouds, and a "lightsaber" to clear them. 

## Controls
- **Joystick:** Steer the snake.
- **Button:** Start the game; hold during play to boost.
- **Potentiometer:** Rotate the lightsaber to clear poison clouds.
- **After game over:** Press the button to return to the start screen.

## Project GIF
<img width="800" height="450" alt="snake gif (1)" src="https://github.com/user-attachments/assets/dd42909d-e5f6-4976-85aa-109514964606" />

## Recreation
To recreate this project, you need a circuitry kit, a LilyGo TTGO T-display ESP32, and a USB cable that supports data transfer and connects the ESP32 to your computer.

### Circuitry Setup
You will need a circuitry kit including a breadboard, a button, a rotary potentiometer, a joystick, and a few wires. Connect your components and your ESP32 according to the following diagram:
<img width="1866" height="1041" alt="emb_snek_circuit_diagram_bb" src="https://github.com/user-attachments/assets/07e734b7-3d35-4c1c-a2f4-c47d42c6d0fc" />

### Arduino Setup
1. Download and install the [Arduino IDE](https://www.arduino.cc/en/software).
2. Follow the [Arduino-ESP32 installation guide](https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html) to add ESP32 board support.
3. Clone this repository and open `snek_2.ino` in Arduino IDE.
4. Connect the TTGO T-Display and select:
   - **Board:** ESP32 Dev Module
   - **Upload Speed:** 115200
   - **Flash Size:** 4 MB
   - **PSRAM:** Disabled
   - **Port:** The port connected to the board
5. Compile and upload the sketch.

> **Note:** If the board does not appear under **Tools → Port**, install the appropriate USB driver linked in the [TTGO T-Display repository](https://github.com/Xinyuan-LilyGO/TTGO-T-Display).

### Processing Setup
1. Download and install [Processing](https://processing.org/download).
2. Open `snek_2.pde` in Processing and select **Java** mode.
3. Keep the ESP32 connected after uploading the Arduino sketch. Close Arduino’s **Serial Monitor** and **Serial Plotter** so Processing can access the serial port.
4. Click **Run**. The available serial ports will appear in the Processing console.
5. Find the ESP32’s port, matching the port selected in Arduino IDE. Update `portIndex` near the top of the Processing sketch to its corresponding index. On macOS, select the `/dev/cu.*` entry associated with the ESP32.
6. Stop and rerun the sketch. Press the physical button to start playing.

> **Note:** Both sketches use 9600 baud for serial communication. This is separate from the Arduino upload speed of 115200.
