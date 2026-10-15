/*
  ================================================================================
  GBU — Edge AI Predictive Maintenance ESP32 Firmware
  ================================================================================
  Target Board : ESP32-WROOM-32 / ESP32 Dev Module (Bluetooth Classic SPP)
  Device Name  : EdgeAI_Predictive_Node
  Baud Rate    : 115200 (USB Serial Debugging)
  Protocol     : Newline-delimited JSON over Bluetooth Serial (SPP)
  
  Sensor & Component Hardware Pin Mapping:
    - DHT11 Temp & Humidity Sensor : GPIO 23 (Digital I/O)
    - SW-420 Vibration Sensor DO   : GPIO 19 (Digital Input DO)
    - Conductive Water Sensor      : GPIO 34 (Analog Input ADC1_CH6)
    - Piezo Buzzer                 : GPIO 18 (Digital Output)
    - Green LED (System Normal)    : GPIO 2  (Digital Output)
    - White LED (Vibration Active) : GPIO 4  (Digital Output)
    - Red LED (Critical Condition) : GPIO 16 (Digital Output)
  ================================================================================
*/

#include "BluetoothSerial.h"
#include <DHT.h>
#include <Preferences.h>

// Verify Bluetooth Classic support in ESP32 Arduino Core
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error "Bluetooth Classic is not enabled in your ESP32 Arduino Core! Please enable Bluetooth in board settings."
#endif

// ================================================================================
// HARDWARE PIN ASSIGNMENTS & CONSTANTS
// ================================================================================
static const char* BT_DEVICE_NAME = "EdgeAI_Predictive_Node";

// GPIO Pin Definitions
#define DHT_PIN             23   // DHT11 Data Pin
#define DHT_TYPE            DHT11

#define SW420_VIB_PIN       19   // SW-420 Vibration Sensor DO Pin

#define WATER_ADC_PIN       34   // Water Sensor Analog Pin (ADC1_CH6 - Safe with Bluetooth)

#define BUZZER_PIN          18   // Active Piezo Buzzer
#define LED_GREEN_PIN       2    // Green LED (System Operational / Normal)
#define LED_WHITE_PIN       4    // White LED (Vibration Indicator)
#define LED_RED_PIN         16   // Red LED (Critical Alert Indicator)

// Scheduler Intervals (Non-blocking millis)
const unsigned long TELEMETRY_INTERVAL_MS = 1000; // JSON telemetry every 1s
const unsigned long SENSOR_READ_INTERVAL_MS = 100;  // Poll sensors every 100ms

// ================================================================================
// DYNAMIC CONFIGURATION RULES & PREFERENCES NVS PERSISTENCE
// ================================================================================
Preferences preferences;

int cfgVersion               = 1;
float cfgTempWarning        = 35.0;
float cfgTempCritical       = 45.0;

int cfgVibActiveState        = HIGH;
int cfgVibDebounceMs         = 20;
int cfgVibWarningCount       = 3;
int cfgVibCriticalCount      = 10;

int cfgWaterWarning         = 100;
int cfgWaterCritical        = 1000;

float cfgSoundWarning       = 0.50;
float cfgSoundCritical      = 0.80;
unsigned long cfgSoundStaleTimeoutMs = 3000;

int cfgRiskWarning          = 35;
int cfgRiskCritical         = 70;
bool cfgBuzzerEnabled        = true;
unsigned long cfgBuzzerDurationMs = 5000; // Capped at max 5000ms (5 seconds)

// ================================================================================
// GLOBAL OBJECTS & STATE VARIABLES
// ================================================================================
BluetoothSerial SerialBT;
DHT dht(DHT_PIN, DHT_TYPE);

// Timers
unsigned long lastTelemetryTime = 0;
unsigned long lastSensorReadTime = 0;

// Sensor Readings
float currentTemp = 24.5;
float currentHum = 45.0;
int currentVibration = 0; // 0 = Clear, 1 = Detected
int currentVibrationCount = 0; // SW-420 pulse rate (pulses/sec)
int currentWater = 0;

// Acoustic Sound Features from Phone Microphone
float latestSoundLevel = 0.0;
float latestSoundPeak = 0.0;
unsigned long lastSoundPacketTime = 0;
bool soundDataValid = false;

// SW-420 Edge & Window Pulse Tracking
int lastRawVibState = LOW;
unsigned long lastDebounceTime = 0;
int vibPulseAccumulator = 0;
unsigned long lastVibWindowTime = 0;
int lastRawVibPinState = LOW;

// Hardware Flags
bool dhtInitialized = false;

// Simulated Fault Injections
bool simFaultTemp = false;
bool simFaultVib = false;
bool simFaultWater = false;
bool simFaultSound = false;

// Safety State Machine & Emergency Buzzer Timing
bool safetyOverrideActive = false;
bool emergencyLatched = false;
unsigned long emergencyStartTime = 0;
bool wasCriticalInPreviousLoop = false;
const unsigned long HARDWARE_MAX_BUZZER_DURATION_MS = 5000;

// Risk Assessment Results
int currentRiskScore = 0;
String currentStatusStr = "SAFE";
String currentCauseStr = "Normal Operation";

// Incoming Command Buffer
String rxBuffer = "";

// ================================================================================
// FUNCTION PROTOTYPES
// ================================================================================
void setupPins();
void loadConfigFromNVS();
void saveConfigToNVS();
void readSensors();
void calculateRiskAndStatus();
void processIncomingBluetoothCommands();
void handleSingleCommand(char cmd);
void parseIncomingJsonPacket(const String& jsonStr);
void transmitTelemetryJSON();
void updateOutputs();

// ================================================================================
// INITIALIZATION SETUP
// ================================================================================
void setup() {
  // 1. USB Serial Debugging Console
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println(F("=========================================================="));
  Serial.println(F("   GBU — EDGE AI PREDICTIVE MAINTENANCE FIRMWARE         "));
  Serial.println(F("=========================================================="));
  Serial.print(F("[SYS] Target Bluetooth Device Name: "));
  Serial.println(BT_DEVICE_NAME);

  // 2. Configure Hardware GPIO Pins
  setupPins();

  // 3. Load Persistent Rules from ESP32 NVS (Preferences)
  loadConfigFromNVS();

  // 4. Initialize DHT Sensor
  dht.begin();
  float tTest = dht.readTemperature();
  if (isnan(tTest)) {
    Serial.println(F("[WARN] DHT11 sensor not responding on GPIO 23. Fallback active."));
    dhtInitialized = false;
  } else {
    Serial.println(F("[OK] DHT11 Sensor initialized on GPIO 23."));
    dhtInitialized = true;
    currentTemp = tTest;
  }

  // 5. Initialize Bluetooth Classic SPP Stack
  if (SerialBT.begin(BT_DEVICE_NAME)) {
    Serial.println(F("[OK] Bluetooth SPP stack initialized. Ready for pairing!"));
  } else {
    Serial.println(F("[ERROR] Failed to start Bluetooth Classic SPP stack!"));
  }

  Serial.println(F("[SYS] Firmware setup completed. Non-blocking main loop active."));
}

// ================================================================================
// NVS CONFIGURATION STORAGE MODULE
// ================================================================================
void loadConfigFromNVS() {
  preferences.begin("gbu_cfg", true);
  if (preferences.isKey("ver")) {
    cfgVersion = preferences.getInt("ver", 1);
    cfgTempWarning = preferences.getFloat("tWarn", 35.0);
    cfgTempCritical = preferences.getFloat("tCrit", 45.0);
    cfgVibActiveState = preferences.getInt("vPol", HIGH);
    cfgVibDebounceMs = preferences.getInt("vDeb", 20);
    cfgWaterWarning = preferences.getInt("wWarn", 100);
    cfgWaterCritical = preferences.getInt("wCrit", 1000);
    cfgSoundWarning = preferences.getFloat("sWarn", 0.50);
    cfgSoundCritical = preferences.getFloat("sCrit", 0.80);
    cfgSoundStaleTimeoutMs = preferences.getULong("sStale", 3000);
    cfgRiskWarning = preferences.getInt("rWarn", 35);
    cfgRiskCritical = preferences.getInt("rCrit", 70);
    cfgBuzzerEnabled = preferences.getBool("buzzer", true);
    cfgBuzzerDurationMs = preferences.getULong("bDur", 5000);
    if (cfgBuzzerDurationMs > 5000) cfgBuzzerDurationMs = 5000;
    Serial.print(F("[NVS] Configuration v"));
    Serial.print(cfgVersion);
    Serial.println(F(" loaded from NVS successfully."));
  } else {
    Serial.println(F("[NVS] No saved config found. Using safe default rules."));
  }
  preferences.end();
}

void saveConfigToNVS() {
  preferences.begin("gbu_cfg", false);
  preferences.putInt("ver", cfgVersion);
  preferences.putFloat("tWarn", cfgTempWarning);
  preferences.putFloat("tCrit", cfgTempCritical);
  preferences.putInt("vPol", cfgVibActiveState);
  preferences.putInt("vDeb", cfgVibDebounceMs);
  preferences.putInt("wWarn", cfgWaterWarning);
  preferences.putInt("wCrit", cfgWaterCritical);
  preferences.putFloat("sWarn", cfgSoundWarning);
  preferences.putFloat("sCrit", cfgSoundCritical);
  preferences.putULong("sStale", cfgSoundStaleTimeoutMs);
  preferences.putInt("rWarn", cfgRiskWarning);
  preferences.putInt("rCrit", cfgRiskCritical);
  preferences.putBool("buzzer", cfgBuzzerEnabled);
  preferences.putULong("bDur", cfgBuzzerDurationMs > 5000 ? 5000 : cfgBuzzerDurationMs);
  preferences.end();
  Serial.print(F("[NVS] Configuration v"));
  Serial.print(cfgVersion);
  Serial.println(F(" saved to NVS."));
}

// ================================================================================
// MAIN EXECUTION LOOP
// ================================================================================
void loop() {
  unsigned long now = millis();

  // 1. Process Incoming SPP Commands / Packets
  processIncomingBluetoothCommands();

  // 2. Poll Physical Sensors & Evaluate Safety (Every 100ms)
  if (now - lastSensorReadTime >= SENSOR_READ_INTERVAL_MS) {
    lastSensorReadTime = now;
    readSensors();
    calculateRiskAndStatus();
    updateOutputs();
  }

  // 3. Transmit JSON Telemetry Packet over Bluetooth SPP (Every 1000ms)
  if (now - lastTelemetryTime >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryTime = now;
    transmitTelemetryJSON();
  }
}

// ================================================================================
// HARDWARE GPIO CONFIGURATION
// ================================================================================
void setupPins() {
  pinMode(SW420_VIB_PIN, INPUT);
  pinMode(WATER_ADC_PIN, INPUT);
  analogReadResolution(12); // 12-bit ADC (0..4095)

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_GREEN_PIN, OUTPUT);
  pinMode(LED_WHITE_PIN, OUTPUT);
  pinMode(LED_RED_PIN, OUTPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_GREEN_PIN, HIGH); // System Powered / Normal
  digitalWrite(LED_WHITE_PIN, LOW);
  digitalWrite(LED_RED_PIN, LOW);
}

// ================================================================================
// SENSOR ACQUISITION MODULE
// ================================================================================
void readSensors() {
  // ------------------------------------------------------------------------------
  // A. Temperature & Humidity (DHT11 on GPIO 23)
  // ------------------------------------------------------------------------------
  if (simFaultTemp) {
    currentTemp = cfgTempCritical + 3.5; // Thermal Overload (> Critical Limit)
    currentHum = 35.0;
  } else if (dhtInitialized) {
    float rawT = dht.readTemperature();
    float rawH = dht.readHumidity();
    if (!isnan(rawT) && rawT >= -10.0 && rawT <= 100.0) {
      currentTemp = rawT;
    }
    if (!isnan(rawH) && rawH >= 0.0 && rawH <= 100.0) {
      currentHum = rawH;
    }
  } else {
    currentTemp = 25.0 + (sin(millis() / 5000.0) * 1.5);
    currentHum = 50.0 + (cos(millis() / 5000.0) * 2.0);
  }

  // ------------------------------------------------------------------------------
  // B. SW-420 Vibration Sensor (Digital DO on GPIO 19)
  // ------------------------------------------------------------------------------
  if (simFaultVib) {
    currentVibration = 1;
    currentVibrationCount = 15;
  } else {
    int rawVib = digitalRead(SW420_VIB_PIN);
    
    // SW-420 spring switch edge accumulator (counts pulse transitions to active polarity)
    if (rawVib == cfgVibActiveState && lastRawVibPinState != cfgVibActiveState) {
      vibPulseAccumulator++;
    }
    lastRawVibPinState = rawVib;

    // Evaluate 1-second window for vibration pulse rate (pulses/sec)
    if (millis() - lastVibWindowTime >= 1000) {
      currentVibrationCount = vibPulseAccumulator;
      vibPulseAccumulator = 0;
      lastVibWindowTime = millis();

      if (currentVibrationCount >= 1) {
        currentVibration = 1;
      } else {
        currentVibration = 0;
      }
    }
  }

  // ------------------------------------------------------------------------------
  // C. Conductive Water Sensor (Analog ADC1 on GPIO 34)
  // ------------------------------------------------------------------------------
  if (simFaultWater) {
    currentWater = cfgWaterCritical + 200; // Simulated Water Leak Fault
  } else {
    int rawAdc = analogRead(WATER_ADC_PIN);
    if (rawAdc < 10) rawAdc = 0; // Noise threshold
    currentWater = rawAdc;
  }

  // ------------------------------------------------------------------------------
  // D. Phone Sound Feature Freshness Check
  // ------------------------------------------------------------------------------
  if (!simFaultSound) {
    if (millis() - lastSoundPacketTime > cfgSoundStaleTimeoutMs) {
      soundDataValid = false;
      latestSoundLevel = 0.0;
      latestSoundPeak = 0.0;
    }
  }
}

// ================================================================================
// DETERMINISTIC RISK SCORE & LATCHED EMERGENCY STATE CALCULATOR
// ================================================================================
void calculateRiskAndStatus() {
  int riskAccumulator = 0;
  String primaryCause = "";
  int highestContrib = 0;

  // 1. Thermal Contribution (up to 45 pts)
  if (currentTemp >= cfgTempCritical) {
    riskAccumulator += 45;
    if (45 > highestContrib) {
      highestContrib = 45;
      primaryCause = "HIGH TEMPERATURE";
    }
  } else if (currentTemp >= cfgTempWarning) {
    int tempContrib = map((long)(currentTemp * 10), (long)(cfgTempWarning * 10), (long)(cfgTempCritical * 10), 15, 35);
    riskAccumulator += tempContrib;
    if (tempContrib > highestContrib) {
      highestContrib = tempContrib;
      primaryCause = "HIGH TEMPERATURE";
    }
  }

  // 2. SW-420 Vibration Contribution (40 pts)
  if (currentVibration == 1) {
    riskAccumulator += 40;
    if (40 > highestContrib) {
      highestContrib = 40;
      primaryCause = "EXCESSIVE VIBRATION";
    }
  }

  // 3. Water Leak Contribution (up to 35 pts)
  if (currentWater >= cfgWaterCritical) {
    riskAccumulator += 35;
    if (35 > highestContrib) {
      highestContrib = 35;
      primaryCause = "WATER LEAK";
    }
  } else if (currentWater >= cfgWaterWarning) {
    riskAccumulator += 15;
    if (15 > highestContrib) {
      highestContrib = 15;
      primaryCause = "WATER LEAK";
    }
  }

  // 4. Acoustic Sound Feature Contribution (up to 35 pts)
  if (simFaultSound) {
    riskAccumulator += 35;
    if (35 > highestContrib) {
      highestContrib = 35;
      primaryCause = "ABNORMAL SOUND";
    }
  } else if (soundDataValid) {
    if (latestSoundLevel >= cfgSoundCritical) {
      riskAccumulator += 35;
      if (35 > highestContrib) {
        highestContrib = 35;
        primaryCause = "ABNORMAL SOUND";
      }
    } else if (latestSoundLevel >= cfgSoundWarning) {
      riskAccumulator += 15;
      if (15 > highestContrib) {
        highestContrib = 15;
        primaryCause = "ABNORMAL SOUND";
      }
    }
  }

  // Clamp Risk Score (0..100)
  if (riskAccumulator > 100) riskAccumulator = 100;
  currentRiskScore = riskAccumulator;

  // Latch emergency state if risk >= cfgRiskCritical
  if (currentRiskScore >= cfgRiskCritical && !safetyOverrideActive) {
    emergencyLatched = true;
  }

  // Determine System Status
  if (emergencyLatched) {
    currentStatusStr = "CRITICAL";
    if (primaryCause.length() == 0) primaryCause = "EMERGENCY LATCHED";
  } else if (currentRiskScore >= cfgRiskWarning) {
    currentStatusStr = "MODERATE";
    if (primaryCause.length() == 0) primaryCause = "ELEVATED RISK";
  } else {
    currentStatusStr = "SAFE";
    primaryCause = "Normal Operation";
  }

  currentCauseStr = primaryCause;
}

// ================================================================================
// BLUETOOTH SPP COMMAND & JSON PARSER MODULE
// ================================================================================
void processIncomingBluetoothCommands() {
  while (SerialBT.available()) {
    char ch = (char)SerialBT.read();
    if (ch == '\n' || ch == '\r') {
      rxBuffer.trim();
      if (rxBuffer.length() > 0) {
        if (rxBuffer.startsWith("{") && rxBuffer.endsWith("}")) {
          parseIncomingJsonPacket(rxBuffer);
        } else if (rxBuffer.length() == 1) {
          handleSingleCommand(rxBuffer.charAt(0));
        }
        rxBuffer = "";
      }
    } else {
      if (rxBuffer.length() == 0 && (ch == 'T' || ch == 't' || ch == 'D' || ch == 'd' ||
                                     ch == 'L' || ch == 'l' || ch == 'S' || ch == 's' ||
                                     ch == 'C' || ch == 'c' || ch == 'O' || ch == 'o' ||
                                     ch == 'R' || ch == 'r')) {
        handleSingleCommand(ch);
      } else {
        rxBuffer += ch;
        if (rxBuffer.length() > 512) {
          rxBuffer = "";
        }
      }
    }
  }
}

void parseIncomingJsonPacket(const String& jsonStr) {
  // 1. Config Get Request (App requesting active rules)
  if (jsonStr.indexOf("\"type\":\"config_get\"") >= 0) {
    String reqId = "0";
    int reqIdx = jsonStr.indexOf("\"requestId\":\"");
    if (reqIdx >= 0) {
      int s = reqIdx + 13;
      int e = jsonStr.indexOf('"', s);
      if (e > s) reqId = jsonStr.substring(s, e);
    }

    String resp = "{\"type\":\"config_data\",\"requestId\":\"" + reqId + "\",\"version\":" + String(cfgVersion) + ",\"rules\":{";
    resp += "\"tempWarning\":" + String(cfgTempWarning, 1) + ",";
    resp += "\"tempCritical\":" + String(cfgTempCritical, 1) + ",";
    resp += "\"vibActiveState\":" + String(cfgVibActiveState) + ",";
    resp += "\"vibDebounceMs\":" + String(cfgVibDebounceMs) + ",";
    resp += "\"waterWarning\":" + String(cfgWaterWarning) + ",";
    resp += "\"waterCritical\":" + String(cfgWaterCritical) + ",";
    resp += "\"soundWarning\":" + String(cfgSoundWarning, 2) + ",";
    resp += "\"soundCritical\":" + String(cfgSoundCritical, 2) + ",";
    resp += "\"soundStaleTimeoutMs\":" + String(cfgSoundStaleTimeoutMs) + ",";
    resp += "\"riskWarning\":" + String(cfgRiskWarning) + ",";
    resp += "\"riskCritical\":" + String(cfgRiskCritical) + ",";
    resp += "\"buzzerEnabled\":" + String(cfgBuzzerEnabled ? "true" : "false") + ",";
    resp += "\"buzzerDurationMs\":" + String(cfgBuzzerDurationMs > 5000 ? 5000 : cfgBuzzerDurationMs);
    resp += "}}";
    SerialBT.println(resp);
    Serial.print(F("[BT TX CONFIG DATA] "));
    Serial.println(resp);
    return;
  }

  // 2. Config Set Request (App updating machine rules)
  if (jsonStr.indexOf("\"type\":\"config_set\"") >= 0) {
    String reqId = "0";
    int reqIdx = jsonStr.indexOf("\"requestId\":\"");
    if (reqIdx >= 0) {
      int s = reqIdx + 13;
      int e = jsonStr.indexOf('"', s);
      if (e > s) reqId = jsonStr.substring(s, e);
    }

    // Extract rule parameters
    float newTWarn = cfgTempWarning;
    float newTCrit = cfgTempCritical;
    int newWWarn = cfgWaterWarning;
    int newWCrit = cfgWaterCritical;
    float newSWarn = cfgSoundWarning;
    float newSCrit = cfgSoundCritical;
    int newRWarn = cfgRiskWarning;
    int newRCrit = cfgRiskCritical;
    int newVPol = cfgVibActiveState;
    int newVDeb = cfgVibDebounceMs;
    bool newBuzz = cfgBuzzerEnabled;
    unsigned long newBDur = cfgBuzzerDurationMs;

    int idx = jsonStr.indexOf("\"tempWarning\":");
    if (idx >= 0) newTWarn = jsonStr.substring(idx + 14).toFloat();
    idx = jsonStr.indexOf("\"tempCritical\":");
    if (idx >= 0) newTCrit = jsonStr.substring(idx + 15).toFloat();

    idx = jsonStr.indexOf("\"waterWarning\":");
    if (idx >= 0) newWWarn = jsonStr.substring(idx + 15).toInt();
    idx = jsonStr.indexOf("\"waterCritical\":");
    if (idx >= 0) newWCrit = jsonStr.substring(idx + 16).toInt();

    idx = jsonStr.indexOf("\"soundWarning\":");
    if (idx >= 0) newSWarn = jsonStr.substring(idx + 15).toFloat();
    idx = jsonStr.indexOf("\"soundCritical\":");
    if (idx >= 0) newSCrit = jsonStr.substring(idx + 16).toFloat();

    idx = jsonStr.indexOf("\"riskWarning\":");
    if (idx >= 0) newRWarn = jsonStr.substring(idx + 14).toInt();
    idx = jsonStr.indexOf("\"riskCritical\":");
    if (idx >= 0) newRCrit = jsonStr.substring(idx + 15).toInt();

    idx = jsonStr.indexOf("\"vibActiveState\":");
    if (idx >= 0) newVPol = jsonStr.substring(idx + 17).toInt();
    idx = jsonStr.indexOf("\"vibDebounceMs\":");
    if (idx >= 0) newVDeb = jsonStr.substring(idx + 16).toInt();

    idx = jsonStr.indexOf("\"buzzerEnabled\":");
    if (idx >= 0) newBuzz = (jsonStr.substring(idx + 16, idx + 20).indexOf("true") >= 0);
    idx = jsonStr.indexOf("\"buzzerDurationMs\":");
    if (idx >= 0) newBDur = jsonStr.substring(idx + 19).toInt();
    if (newBDur > 5000) newBDur = 5000;

    // Perform safety validation
    if (newTCrit <= newTWarn || newWCrit <= newWWarn || newSCrit <= newSWarn || newRCrit <= newRWarn) {
      String errResp = "{\"type\":\"config_ack\",\"requestId\":\"" + reqId + "\",\"status\":\"rejected\",\"reason\":\"Invalid threshold ordering (Critical must exceed Warning)\"}";
      SerialBT.println(errResp);
      Serial.print(F("[BT TX CONFIG REJECTED] "));
      Serial.println(errResp);
      return;
    }

    // Update active rules
    cfgTempWarning = newTWarn;
    cfgTempCritical = newTCrit;
    cfgWaterWarning = newWWarn;
    cfgWaterCritical = newWCrit;
    cfgSoundWarning = newSWarn;
    cfgSoundCritical = newSCrit;
    cfgRiskWarning = newRWarn;
    cfgRiskCritical = newRCrit;
    cfgVibActiveState = newVPol;
    cfgVibDebounceMs = newVDeb;
    cfgBuzzerEnabled = newBuzz;
    cfgBuzzerDurationMs = (newBDur > 5000) ? 5000 : newBDur;
    cfgVersion++;

    // Persist to NVS
    saveConfigToNVS();

    String ackResp = "{\"type\":\"config_ack\",\"requestId\":\"" + reqId + "\",\"version\":" + String(cfgVersion) + ",\"status\":\"applied\"}";
    SerialBT.println(ackResp);
    Serial.print(F("[BT TX CONFIG ACK] "));
    Serial.println(ackResp);
    return;
  }

  // 3. Sound Feature Packet
  if (jsonStr.indexOf("\"type\":\"sound\"") >= 0 || jsonStr.indexOf("\"sound\"") >= 0) {
    int levelIdx = jsonStr.indexOf("\"level\":");
    if (levelIdx >= 0) {
      int valStart = levelIdx + 8;
      int valEnd = jsonStr.indexOf(',', valStart);
      if (valEnd < 0) valEnd = jsonStr.indexOf('}', valStart);
      if (valEnd > valStart) {
        latestSoundLevel = jsonStr.substring(valStart, valEnd).toFloat();
      }
    }

    int peakIdx = jsonStr.indexOf("\"peak\":");
    if (peakIdx >= 0) {
      int valStart = peakIdx + 7;
      int valEnd = jsonStr.indexOf(',', valStart);
      if (valEnd < 0) valEnd = jsonStr.indexOf('}', valStart);
      if (valEnd > valStart) {
        latestSoundPeak = jsonStr.substring(valStart, valEnd).toFloat();
      }
    }

    lastSoundPacketTime = millis();
    soundDataValid = true;
  }
}

void handleSingleCommand(char cmd) {
  switch (cmd) {
    case 'T':
    case 't':
      simFaultTemp = true;
      Serial.println(F("[CMD] 'T' -> Thermal Fault Injected."));
      break;

    case 'D':
    case 'd':
      simFaultVib = true;
      Serial.println(F("[CMD] 'D' -> SW-420 Vibration Fault Injected."));
      break;

    case 'L':
    case 'l':
      simFaultWater = true;
      Serial.println(F("[CMD] 'L' -> Water Leak Fault Injected."));
      break;

    case 'S':
    case 's':
      simFaultSound = true;
      Serial.println(F("[CMD] 'S' -> Simulated Acoustic Sound Fault Injected."));
      break;

    case 'C':
    case 'c':
      simFaultTemp = false;
      simFaultVib = false;
      simFaultWater = false;
      simFaultSound = false;
      safetyOverrideActive = false;
      Serial.println(F("[CMD] 'C' -> All Simulated Faults Cleared."));
      break;

    case 'O':
    case 'o':
      safetyOverrideActive = true;
      emergencyLatched = false;
      wasCriticalInPreviousLoop = false;
      Serial.println(F("[CMD] 'O' -> Safety Override Activated."));
      break;

    case 'R':
    case 'r':
      readSensors();
      simFaultTemp = false;
      simFaultVib = false;
      simFaultWater = false;
      simFaultSound = false;
      calculateRiskAndStatus();

      if (currentRiskScore < cfgRiskCritical) {
        emergencyLatched = false;
        safetyOverrideActive = false;
        wasCriticalInPreviousLoop = false;
        Serial.println(F("[CMD SUCCESS] 'R' -> Emergency state safely reset. System normal."));
      } else {
        Serial.print(F("[CMD REJECTED] 'R' -> Cannot reset emergency! Critical conditions persist (Risk: "));
        Serial.print(currentRiskScore);
        Serial.println(F(")."));
      }
      break;

    case '\r':
    case '\n':
    case ' ':
      break;

    default:
      Serial.print(F("[WARN] Unrecognized command byte ignored: '"));
      Serial.print(cmd);
      Serial.println(F("'"));
      break;
  }
}

// ================================================================================
// TELEMETRY TRANSMISSION MODULE (Newline-Delimited JSON)
// ================================================================================
void transmitTelemetryJSON() {
  String jsonPayload = "{";
  jsonPayload += "\"temp\":" + String(currentTemp, 1) + ",";
  jsonPayload += "\"hum\":" + String(currentHum, 1) + ",";
  jsonPayload += "\"vibration\":" + String(currentVibration) + ",";
  jsonPayload += "\"vibrationCount\":" + String(currentVibrationCount) + ",";
  jsonPayload += "\"water\":" + String(currentWater) + ",";
  jsonPayload += "\"soundLevel\":" + String(latestSoundLevel, 2) + ",";
  jsonPayload += "\"risk\":" + String(currentRiskScore) + ",";
  jsonPayload += "\"status\":\"" + currentStatusStr + "\",";
  jsonPayload += "\"cause\":\"" + currentCauseStr + "\",";
  jsonPayload += "\"emergency\":" + String(emergencyLatched ? "true" : "false");
  jsonPayload += "}";

  SerialBT.println(jsonPayload);
  Serial.print(F("[BT TX] "));
  Serial.println(jsonPayload);
}

// ================================================================================
// HARDWARE OUTPUT INDICATOR & BUZZER CONTROLLER
// ================================================================================
void updateOutputs() {
  bool isCritical = emergencyLatched || (currentRiskScore >= cfgRiskCritical);

  if (isCritical && !wasCriticalInPreviousLoop) {
    emergencyStartTime = millis();
    wasCriticalInPreviousLoop = true;
  } else if (!isCritical) {
    wasCriticalInPreviousLoop = false;
  }

  // 1. Green LED (GPIO 2): Normal / System active indicator
  digitalWrite(LED_GREEN_PIN, (!isCritical || safetyOverrideActive) ? HIGH : LOW);

  // 2. White LED (GPIO 4): SW-420 Vibration indicator
  digitalWrite(LED_WHITE_PIN, (currentVibration == 1) ? HIGH : LOW);

  // 3. Red LED (GPIO 16) & Buzzer (GPIO 18): Critical Condition indicator
  if (isCritical && !safetyOverrideActive) {
    digitalWrite(LED_RED_PIN, HIGH);
    
    // Non-blocking intermittent buzzer tone: active ONLY for maximum 5,000ms (5 seconds) per emergency event
    unsigned long elapsedBuzzerMs = millis() - emergencyStartTime;
    unsigned long maxAllowedDuration = (cfgBuzzerDurationMs > 5000) ? 5000 : cfgBuzzerDurationMs;
    if (cfgBuzzerEnabled && (elapsedBuzzerMs < maxAllowedDuration)) {
      digitalWrite(BUZZER_PIN, ((millis() / 200) % 2 == 0) ? HIGH : LOW);
    } else {
      digitalWrite(BUZZER_PIN, LOW); // Automatically shut down buzzer after 5 seconds
    }
  } else {
    digitalWrite(LED_RED_PIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
  }
}


