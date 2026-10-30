# GBU — Edge AI Predictive Maintenance

> A Flutter companion app that turns an ESP32 sensor node and your phone's microphone into a pocket-sized machine-health dashboard.

![Flutter](https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter&logoColor=white)
![ESP32](https://img.shields.io/badge/MCU-ESP32-E7352C?logo=espressif&logoColor=white)
![Bluetooth](https://img.shields.io/badge/Link-Bluetooth%20Classic%20SPP-0082FC?logo=bluetooth&logoColor=white)
![Status](https://img.shields.io/badge/status-prototype-orange)

> **Project status:** This README describes the intended design and current requirements. Check every feature against the actual source code and physical hardware before calling it verified or production-ready.

---

## Table of Contents

- [Why GBU](#why-gbu)
- [Key Features](#key-features)
- [Hardware](#hardware)
- [System Architecture](#system-architecture)
- [Phone Microphone Sound Monitoring](#phone-microphone-sound-monitoring)
- [Vibration Detection](#vibration-detection)
- [Bluetooth Protocol](#bluetooth-protocol)
- [Alerts and Emergency Behavior](#alerts-and-emergency-behavior)
- [Getting Started](#getting-started)
- [Testing and Verification](#testing-and-verification)
- [Troubleshooting](#troubleshooting)
- [Safety and Limitations](#safety-and-limitations)
- [Development Status](#development-status)

---

## Why GBU

Machines rarely fail without warning. They run hotter, shake more, get louder, or leak first. GBU gathers those early signals in one place: an ESP32 node reads the physical sensors, the phone listens to the sound, and the app brings both together into a single live view with a clear risk status.

## Key Features

- **Wireless link** to the ESP32 over Bluetooth Classic (SPP).
- **Live machine telemetry:** temperature, humidity, vibration, and water-sensor readings.
- **Risk level and alerts** derived from sensor data.
- **Opt-in sound monitoring** using the phone's built-in microphone, processed entirely on-device.
- **Independent data paths:** turning the microphone off never interferes with ESP32 monitoring.
- **Honest data display:** the app never fabricates live values. Missing, disconnected, or stale data is shown as *unavailable*.

---

## Hardware

| Component | ESP32 Pin | Notes |
|---|---|---|
| ESP32 DevKit / ESP32-WROOM-32 | — | Main controller |
| DHT11 | GPIO 23 | Digital temperature and humidity sensor |
| SW-420 vibration module | GPIO 19 | Digital output; verify actual polarity |
| Water sensor | GPIO 34 | Analog input; keep voltage within ESP32 limits |
| Buzzer | GPIO 18 | Check voltage and current requirements |
| Green LED | GPIO 2 | Boot-strapping pin on many ESP32 boards |
| White LED | GPIO 4 | Status indicator |
| Red LED | GPIO 16 | Warning / critical indicator |
| Phone microphone | Phone hardware | Used by the Flutter app, **not** wired to the ESP32 |

### Hardware notes

- The **SW-420** is a digital vibration-trigger module. It does not measure calibrated acceleration, amplitude, or frequency.
- Confirm whether your SW-420 is **active HIGH or active LOW**. Never assume.
- **GPIO 34** is input-only and has no internal pull-up or pull-down. Check the sensor's output circuit and voltage range.
- **GPIO 2** can influence boot behavior on some boards.
- Confirm the **buzzer's** electrical needs before driving it straight from a GPIO.

---

## System Architecture

GBU relies on two independent data sources:

```
┌──────────────────────┐   Bluetooth SPP    ┌──────────────────────────┐
│  ESP32 Sensor Node   │ ─────────────────► │                          │
│  DHT11 · SW-420 ·    │  newline-delimited │      Flutter App         │
│  Water · Buzzer/LEDs │       JSON         │  Dashboard · Risk ·      │
└──────────────────────┘                    │  Alerts · Sound Meter    │
                                            │                          │
┌──────────────────────┐   local capture    │                          │
│  Phone Microphone    │ ─────────────────► │                          │
└──────────────────────┘  (features only)   └──────────────────────────┘
```

1. **ESP32 machine telemetry** — temperature, humidity, vibration, and water data arrive over Bluetooth Classic SPP.
2. **Phone microphone monitoring** — the app captures audio locally and computes compact features such as RMS, peak amplitude, or a smoothed relative level.

**Expected Flutter areas:**

- Telemetry and alert models
- Bluetooth service with newline-delimited JSON parsing
- Machine controller with risk and alert logic
- Dashboard sensor cards and risk display
- Sound-monitoring controls and audio lifecycle management
- Settings and configuration sync (if implemented)

> Check the actual repository before relying on these names or assuming every feature exists.

---

## Phone Microphone Sound Monitoring

Sound monitoring uses the Android phone's built-in microphone. No separate microphone on the ESP32 is needed.

### Required behavior

The app should:

- Request microphone permission at runtime.
- Display the true microphone state.
- Process real samples locally.
- Show a **relative** sound level unless a calibrated measurement system exists.
- Never send raw audio to the ESP32 or a server. If Bluetooth sound messages are needed, send only compact calculated features.
- Handle permission denial, recording errors, app lifecycle changes, and cleanup safely.
- Prevent more than one recording session from running at once.

### Microphone OFF means monitoring OFF

When the user switches the microphone off or taps **Stop**, everything microphone-related must actually stop, not just vanish from the screen:

1. Stop the real audio recorder and release microphone resources.
2. Stop audio-stream processing and reject late callbacks from the stopped session.
3. Cancel microphone-related timers, subscriptions, and pending work.
4. Stop live sound-meter updates and microphone-based threshold checks.
5. Block new microphone-based alerts while monitoring is OFF.
6. Clear the live value (show `--`) and display **Sound Monitoring Disabled**.
7. Report an accurate OFF or error state if permission is revoked or recording fails.
8. Begin a fresh session with fresh samples when monitoring is re-enabled.

**Suggested state model:**

```
IDLE → STARTING → RUNNING → STOPPING → IDLE
```

The UI should reflect the real recorder state, for example *Microphone Off*, *Listening*, *Stopping*, or *Microphone Permission Required*.

> **Important:** Turning the microphone OFF must not disable ESP32 temperature, vibration, or water monitoring, and must not automatically clear an already-latched machine emergency.

### Sound-level limitations

- RMS, peak amplitude, and normalized levels are signal features, **not** calibrated decibels.
- Do not label readings as accurate dB SPL unless the phone and microphone have been calibrated and validated.
- Make sound thresholds and persistence configurable where the settings implementation allows.
- Use persistence and/or hysteresis to prevent alert flicker near a threshold.
- Stale sound values must never create new alerts after monitoring stops.

---

## Vibration Detection

The SW-420 module connects to **ESP32 GPIO 19**.

Expected behavior:

- Read the module's digital output.
- Verify and support the real active-HIGH or active-LOW polarity.
- Debounce transitions and, if required, count trigger events over a configurable time window.
- Send the vibration state (and any event count or rate) through the existing Bluetooth telemetry protocol.
- Parse fields consistently across firmware, Flutter models, controllers, and UI.
- Display **No vibration**, **Vibration detected**, or **Sensor unavailable** as appropriate.
- Treat disconnected or stale telemetry as *unavailable*, never as a confirmed zero reading.

> Software tests alone cannot prove physical vibration detection. Test on the real ESP32 and confirm the digital output changes when the sensor is triggered.

---

## Bluetooth Protocol

| Item | Value |
|---|---|
| Mode | Bluetooth Classic, Serial Port Profile (SPP) |
| Expected device name | `EdgeAI_Predictive_Node` |
| Message framing | Newline-delimited JSON (if retained by the existing implementation) |

The firmware and the Flutter app must agree on:

- JSON field names and data types
- Numeric ranges and missing-value behavior
- Message types for telemetry, configuration, acknowledgements, and commands
- Handling of partial packets, multiple messages in one packet, and malformed JSON

Rules to follow:

- Keep phone microphone features separate from ESP32 telemetry. A sound-feature message must never be mistaken for a machine telemetry message.
- Never rename a field on only one side of the connection.
- Confirm the exact schema from the current source code and firmware.

---

## Alerts and Emergency Behavior

The app may use risk levels and sensor thresholds to raise alerts. Confirm exact thresholds in the current configuration and code.

Key separation rules:

- Stopping phone microphone monitoring stops microphone-derived monitoring and new microphone-derived alerts.
- It must **not** silently clear a latched machine emergency caused by ESP32 telemetry.
- A critical emergency stays latched until the established acknowledgement or reset procedure allows clearing it.
- If the buzzer sounds for a critical event, enforce its timeout in ESP32 firmware using non-blocking timing. Repeated telemetry must not keep restarting the timeout.
- A UI emergency overlay is **not** a physical safety interlock. Any machinery shutdown or emergency-stop behavior needs properly designed hardware and a safety review.

---

## Getting Started

### Prerequisites

- Flutter SDK compatible with the project
- Android SDK plus an Android device or emulator
- Android Studio (or another configured Android build environment)
- ESP32 board and the required sensors for hardware testing
- Arduino IDE or the firmware's documented build environment
- A **physical** Android phone for verifying microphone behavior

### Run the app

```bash
cd D:\projects\gbu\gbu
flutter pub get
flutter analyze
flutter test
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

> These commands are instructions, not a claim that the current source passes them. Review the output and fix any errors before distributing a build.

### Android permissions

- Declare and request the permissions required by the exact Bluetooth and audio packages in use. Bluetooth permissions differ across Android versions.
- Request microphone permission at runtime before recording.
- Do not assume a permission is granted just because it is in the manifest. Handle *denied* and *permanently denied* states in the UI.

---

## Testing and Verification

### Phone microphone checklist

- [ ] First-time permission request works
- [ ] Denied permission is handled without crashing
- [ ] Starting monitoring captures real microphone samples
- [ ] Speaking near the phone changes the relative sound level
- [ ] Repeated Start taps do not create multiple recorder sessions
- [ ] Stop releases the microphone and ends audio processing
- [ ] No meter updates or new microphone-based alerts occur after Stop
- [ ] Late callbacks from an old session cannot update the current UI
- [ ] Stopping an already-stopped session is safe
- [ ] Navigation, backgrounding, and recording errors clean up safely
- [ ] Re-enabling monitoring starts a fresh session
- [ ] Microphone OFF does not stop ESP32 sensor monitoring or clear a latched emergency

### Vibration checklist

- [ ] Confirm SW-420 wiring and actual output polarity
- [ ] Observe GPIO 19 while the sensor is still and while triggered
- [ ] Verify debounce and event counting (if implemented)
- [ ] Confirm the ESP32 sends the expected JSON
- [ ] Confirm Flutter parses the same field names and data types
- [ ] Verify the dashboard changes when the sensor is physically triggered
- [ ] Verify disconnected or stale telemetry shows as unavailable
- [ ] Confirm vibration detection continues while the microphone is OFF

### Integration checklist

- [ ] Bluetooth connects to the expected device
- [ ] Partial and malformed messages are handled safely
- [ ] Existing commands and configuration behavior still work
- [ ] Risk calculations and emergency latching still work
- [ ] `flutter analyze`, `flutter test`, and an Android build all run
- [ ] Physical-device results are recorded separately from automated results

---

## Troubleshooting

<details>
<summary><b>Sound level keeps updating after Stop</b></summary>

Inspect the recorder stop/dispose flow, audio-stream subscriptions, timers, state management, and callbacks. Switch the UI to OFF only after the session has stopped or been safely released. Cancel subscriptions and invalidate callbacks from the previous session.
</details>

<details>
<summary><b>Sound alert stays active with microphone OFF</b></summary>

Make sure microphone-derived threshold checks cannot run while monitoring is OFF and that stale values cannot trigger new alerts. Decide separately whether an already-triggered alert stays visible for acknowledgement; that is different from continuing to listen.
</details>

<details>
<summary><b>Vibration never changes</b></summary>

1. Check sensor power and common ground.
2. Adjust the SW-420 sensitivity.
3. Read the digital output with a serial diagnostic.
4. Check active-HIGH vs active-LOW polarity.
5. Confirm GPIO 19 configuration.
6. Check JSON field names and value types.
7. Check Bluetooth packet framing and Flutter parsing.
8. Review telemetry freshness logic and dashboard state updates.
</details>

<details>
<summary><b>Vibration appears permanently active</b></summary>

Check polarity, debounce behavior, and whether the firmware sends a raw pin value or a derived event state. Test the real GPIO output instead of changing the UI to force an expected result.
</details>

<details>
<summary><b>Bluetooth connects but values do not update</b></summary>

Compare one complete line of actual ESP32 JSON with the schema the Flutter parser expects. Verify newline framing, buffering, parse errors, and timestamp or stale-data rules.
</details>

---

## Safety and Limitations

- GBU is a **prototype monitoring system**, not a certified industrial safety system.
- Never rely on app alerts as the only protection for hazardous equipment.
- Verify sensor readings and thresholds on real hardware before trusting them.
- Do not present heuristic risk scores as validated predictive accuracy without proper evaluation.
- Keep raw microphone audio local unless a separately reviewed feature requires otherwise and the user has consented.
- Document any unimplemented or unverified feature honestly.

---

## Development Status

Update this section after each verified implementation.

| Area | Status |
|---|---|
| Phone microphone Start/Stop | Not verified — confirm on a physical Android phone |
| Sound monitoring OFF behavior | Must stop recorder, processing, and new microphone-based alerts |
| SW-420 vibration detection | Needs polarity, wiring, firmware, Bluetooth, and dashboard verification |
| Automated tests and Android build | Record actual command results |
| Hardware validation | Record which sensors and phone models were physically tested |

---

## License

Add your license here (for example, MIT) and include a `LICENSE` file in the repository.
