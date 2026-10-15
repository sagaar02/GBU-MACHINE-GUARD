# GBU ESP32 Firmware Specification

## 1. Overview

This directory contains the ESP32 firmware for the **GBU — Offline Edge AI Predictive Maintenance** node.

The firmware runs on an ESP32 microcontroller without requiring Wi-Fi or cloud infrastructure. It continuously reads physical sensors, evaluates machine health risk, controls visual and audible indicators, and streams real-time JSON telemetry to the Android Flutter application over Bluetooth Classic SPP (`BluetoothSerial.h`).

---

## 2. Hardware Pin Assignments

| Component | GPIO | Type |
|---|---:|---|
| DHT11 Data | 23 | Digital I/O |
| SW-420 Vibration DO | 19 | Digital Input |
| Water Sensor Analog | 34 | Analog Input (ADC1_CH6) |
| Piezo Buzzer | 18 | Digital Output |
| Green LED | 2 | Digital Output (Normal / System) |
| White LED | 4 | Digital Output (Vibration Active) |
| Red LED | 16 | Digital Output (Critical Alert) |

---

## 3. Upload & Flashing Instructions

1. Open Arduino IDE or PlatformIO.
2. Select Board: **ESP32 Dev Module**.
3. Install required libraries:
   - `DHT sensor library` by Adafruit
   - `Adafruit Unified Sensor`
4. Connect ESP32 via USB cable.
5. Select the COM port and click **Upload**.
6. Open Serial Monitor at **115200 baud** to view initialization logs and debug output.
