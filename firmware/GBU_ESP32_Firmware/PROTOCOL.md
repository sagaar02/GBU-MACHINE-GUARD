# GBU ESP32 Bluetooth Classic SPP Protocol & Contract

## 1. Bluetooth Connection Specification

- **Bluetooth Core**: ESP32 Bluetooth Classic SPP (`BluetoothSerial.h`)
- **Target Advertised Name**: `EdgeAI_Predictive_Node`
- **Baud Rate**: 115200 (USB Serial Debugging Console)
- **Framing**: Newline-delimited UTF-8 strings (`\n`)

---

## 2. Telemetry JSON Packet Schema

The ESP32 transmits telemetry payload approximately **once per second** (1000ms):

```json
{
  "temp": 32.5,
  "hum": 65.0,
  "vibration": 1,
  "water": 1200,
  "soundLevel": 0.72,
  "risk": 85,
  "status": "CRITICAL",
  "cause": "ABNORMAL SOUND",
  "emergency": true
}
```

### Data Fields Specification

| Field Name | Type | Unit / Range | Description |
|---|---|---|---|
| `temp` | `double` | °C | DHT11 Temperature transducer reading |
| `hum` | `double` | % | DHT11 Relative Humidity sensor reading |
| `vibration` | `int` | `0` or `1` | SW-420 digital vibration DO (0 = Clear, 1 = Detected) |
| `water` | `int` | `0`..`4095` | Conductive water sensor 12-bit ADC raw reading |
| `soundLevel` | `double` | `0.0`..`1.0` | Normalized acoustic amplitude feature from phone mic |
| `risk` | `int` | `0`..`100` | Deterministic baseline machine risk score |
| `status` | `string` | `SAFE`, `MODERATE`, `CRITICAL` | Machine operational risk classification |
| `cause` | `string` | Text string | Primary contributor cause explanation |
| `emergency` | `bool` | `true` / `false` | Hardware emergency latched state flag |

---

## 3. Acoustic Sound Feature Transmission (Phone to ESP32)

The Android Flutter app calculates local RMS amplitude features from the phone microphone and transmits compact newline-delimited JSON feature packets to the ESP32:

```json
{
  "type": "sound",
  "level": 0.72,
  "peak": 0.91,
  "timestamp": 1728612400
}
```

- **Freshness Timeout**: The ESP32 enforces a 3000ms stale cutoff. If no sound packet arrives within 3 seconds, `soundDataValid` turns false and sound features are excluded from risk calculations without false alarms.

---

## 4. SPP Command Protocol (Single-Byte Characters)

The Android Flutter app transmits single-byte ASCII characters to trigger fault injection and safety operations on the ESP32:

| Command Byte | Action Name | Description |
|:---:|---|---|
| `'T'` / `'t'` | **Thermal Fault** | Injects simulated high temperature (`48.5°C`) |
| `'D'` / `'d'` | **Vibration Fault** | Injects simulated SW-420 vibration trigger (`vibration = 1`) |
| `'L'` / `'l'` | **Water Leak Fault** | Injects simulated fluid seepage (`water = 1200 ADC`) |
| `'S'` / `'s'` | **Sound Fault** | Injects simulated abnormal sound feature alert |
| `'C'` / `'c'` | **Clear Faults** | Clears all simulated faults & restores physical sensor readings |
| `'O'` / `'o'` | **Safety Override** | Silences buzzer & resets alert indicators |
| `'R'` / `'r'` | **Emergency Reset** | Requests emergency latch reset (Accepted only if risk score < 70) |

---

## 5. Live Configuration Protocol (`config_get` / `config_set` / `config_ack`)

The Android Flutter app and ESP32 exchange structured JSON messages over the SPP stream for reading and updating hardware operational rules live:

### 5.1 Configuration Request (`config_get`)
Sent by Flutter on connection/reconnection to retrieve active device parameters:
```json
{"type":"config_get","requestId":"req_1001"}
```

### 5.2 Device Configuration Response (`config_data`)
Sent by ESP32 in response to `config_get`:
```json
{
  "type":"config_data",
  "version":1,
  "rules":{
    "tempWarning":35.0,
    "tempCritical":45.0,
    "vibActiveState":1,
    "vibDebounceMs":200,
    "waterWarning":100,
    "waterCritical":1000,
    "soundWarning":0.50,
    "soundCritical":0.80,
    "riskWarning":35,
    "riskCritical":70,
    "buzzerEnabled":true
  }
}
```

### 5.3 Configuration Update (`config_set`)
Sent by Flutter when user presses "Apply Changes":
```json
{
  "type":"config_set",
  "requestId":"req_1002",
  "version":2,
  "rules":{
    "tempWarning":38.0,
    "tempCritical":50.0,
    "vibActiveState":1,
    "vibDebounceMs":250,
    "waterWarning":150,
    "waterCritical":1200,
    "soundWarning":0.55,
    "soundCritical":0.85,
    "riskWarning":40,
    "riskCritical":75,
    "buzzerEnabled":true
  }
}
```

### 5.4 Acknowledgement Response (`config_ack`)
Sent by ESP32 after validating and committing rules to Preferences NVS storage:
```json
{"type":"config_ack","requestId":"req_1002","version":2,"status":"applied"}
```
If validation fails:
```json
{"type":"config_ack","requestId":"req_1002","status":"rejected","reason":"Invalid threshold ordering"}
```

---

## 6. Physical Emergency-Stop Safety Notice

This prototype utilizes software emergency latching, red LED (GPIO 16) pulsing, and piezo buzzer (GPIO 18) warning patterns.

> **CRITICAL INDUSTRIAL SAFETY WARNING**:
> Do NOT rely solely on software, mobile Bluetooth communication, or phone apps for human personnel protection.
> Industrial machinery must be protected by physical, hardware-interlocked emergency stop switches and hardwired safety relays.


