# GBU ESP32 Hardware Pin Mapping & Wiring Specification

## 1. Confirmed Hardware Pin Matrix

| Component | ESP32 GPIO Pin | Signal Type | Operating Voltage | Resistors / Wiring Notes |
|---|---:|---|---|---|
| **DHT11 Data** | **GPIO 23** | Digital I/O | 3.3V | Requires 10 kΩ pull-up resistor to 3.3V |
| **SW-420 Vibration DO** | **GPIO 19** | Digital Input (DO) | 3.3V | Digital vibration switch output module |
| **Water Sensor Analog** | **GPIO 34** | Analog Input (ADC1_CH6) | 0 - 3.3V | **ADC1 channel** (Safe with Bluetooth active!) |
| **Piezo Buzzer** | **GPIO 18** | Digital Output | 3.3V | Active piezo buzzer for audible alert pattern |
| **Green LED** | **GPIO 2** | Digital Output | 3.3V | System operational / SAFE status indicator (220Ω resistor) |
| **White LED** | **GPIO 4** | Digital Output | 3.3V | SW-420 Vibration indicator LED (220Ω resistor) |
| **Red LED** | **GPIO 16** | Digital Output | 3.3V | Emergency CRITICAL condition LED (220Ω resistor) |

---

## 2. Hardware Precautions & Electrical Guidelines

1. **SW-420 Vibration Polarity**:
   - The onboard LM393 comparator outputs `LOW` when quiet/stable and `HIGH` when vibration disturbs the internal spring contact switch.
   - Micro-controller logic is configured as `SW420_ACTIVE_STATE HIGH`.

2. **Water Sensor ADC Voltage Limits**:
   - Connect water sensor power pin to 3.3V (NOT 5V) to ensure analog output never exceeds the ESP32 ADC maximum input voltage of 3.3V.
   - GPIO 34 is on ADC1, which works reliably while Bluetooth Classic SPP is active.

3. **Current Limiting Resistors**:
   - Insert 220 Ω to 330 Ω current-limiting resistors in series with all indicator LEDs (Green on GPIO 2, White on GPIO 4, Red on GPIO 16).

4. **Bootstrapping Pin Safety**:
   - GPIO 2 is a strapping pin (must not be pulled strongly HIGH during power-on/flashing). Connecting an LED with a series 220 Ω resistor to GND is safe and does not interfere with ESP32 bootstrapping.

5. **Common Ground (`GND`)**:
   - Connect all sensor grounds, LED cathode grounds, and power supply ground lines to a common ESP32 `GND` bus.
