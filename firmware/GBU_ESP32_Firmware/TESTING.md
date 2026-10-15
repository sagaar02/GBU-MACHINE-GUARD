# GBU System Hardware & Integration Testing Instructions

## 1. Hardware Inspection Checklist

- [ ] Confirm DHT11 data pin is connected to **GPIO 23** with 10 kΩ pull-up resistor to 3.3V.
- [ ] Confirm SW-420 DO pin is connected to **GPIO 19**. Adjust sensitivity potentiometer on module until onboard LED toggles upon tapping.
- [ ] Confirm Water sensor analog output is connected to **GPIO 34** (ADC1 channel 6).
- [ ] Confirm Piezo Buzzer positive pin is connected to **GPIO 18**.
- [ ] Confirm Green LED is connected to **GPIO 2** with 220 Ω resistor.
- [ ] Confirm White LED is connected to **GPIO 4** with 220 Ω resistor.
- [ ] Confirm Red LED is connected to **GPIO 16** with 220 Ω resistor.

---

## 2. Bluetooth Pairing & Android Integration Setup

1. Power the ESP32 node via USB.
2. On your Android phone, open **Settings -> Bluetooth**.
3. Scan for available devices and select **`EdgeAI_Predictive_Node`**.
4. Confirm pairing (PIN is typically `1234` or `0000` if prompted, or default pairing).
5. Launch the **GBU Flutter Android app**.
6. The app will auto-connect or allow manual device selection via the **Connect** badge in the app bar.

---

## 3. Verification Test Matrix (12 Scenarios)

| # | Test Scenario | Expected Outcome | Status |
|:---:|---|---|:---:|
| 1 | **SAFE → MODERATE Transition** | Risk score 35-69%. Amber gauge highlights responsible sensor. No phone vibration. | **PASS** |
| 2 | **MODERATE → CRITICAL Transition** | Risk score >= 70%. Red gauge highlights primary cause. Red LED (GPIO 16) & Buzzer sound. | **PASS** |
| 3 | **CRITICAL → EMERGENCY_LATCHED** | Full-screen translucent Emergency Stop overlay fades in. State latches. | **PASS** |
| 4 | **Vibration Deduplication** | Repeated telemetry packets in CRITICAL state trigger phone vibration EXACTLY ONCE. | **PASS** |
| 5 | **Stale Sound Packet Protection** | If phone mic stops for >3s, ESP32 reports `SOUND DATA UNAVAILABLE` without false alarms. | **PASS** |
| 6 | **Microphone Permission Denial** | Handled gracefully with explanatory status message if user denies mic permission. | **PASS** |
| 7 | **Stop Sound Monitoring** | Toggling microphone switch OFF immediately halts sample timer and audio stream. | **PASS** |
| 8 | **Bluetooth Disconnect in Emergency** | Retains visible Emergency Overlay and displays `CONNECTION LOST — EMERGENCY LATCHED`. | **PASS** |
| 9 | **Physical Sensor Recovery** | Sensor readings returning to safe levels do NOT silently clear latched emergency. | **PASS** |
| 10 | **Reset Rejection on Active Risk** | Command `'R'` is rejected by ESP32 if risk score remains >= 70%. | **PASS** |
| 13 | **Live Rule Synchronization** | App auto-requests active rules (`config_get`) upon Bluetooth connection and displays device state. | **PASS** |
| 14 | **Transactional Rule Apply** | Modifying rules and tapping "Apply Changes" sends `config_set`, receives `config_ack`, and commits to UI. | **PASS** |
| 15 | **ESP32 NVS Persistence & Reboot** | New rules persist in ESP32 Preferences NVS across hardware reboots. | **PASS** |
| 16 | **Disconnected Guard & Validation** | Settings fields are read-only when disconnected; invalid threshold ordering blocks Apply action. | **PASS** |

---

## 4. SPP Command Fault Injection Verification

In the **Controls** tab of the Flutter application:

1. Tap **Thermal Fault ('T')**: Injects 48.5°C thermal overload state.
2. Tap **Vibration Fault ('D')**: Triggers SW-420 DO vibration alert switch (`vibration = 1`).
3. Tap **Water Leak Fault ('L')**: Injects 1200 ADC fluid seepage state.
4. Tap **Sound Fault ('S')**: Injects 0.92 simulated acoustic noise feature state.
5. Tap **Clear Faults ('C')**: Clears all injected simulated fault inputs.
6. Tap **Emergency Reset ('R')**: Safely resets latched emergency state if risk < 70%.

