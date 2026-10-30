GBU --- Edge AI Predictive Maintenance
A Flutter-based mobile dashboard for monitoring an ESP32
predictive-maintenance node over Bluetooth Classic (SPP). The system is
intended to display machine sensor telemetry, risk status, alerts, and
phone-side sound monitoring.
Project status: This README documents the intended architecture
and current requirements. Confirm features against the actual source
code and physical hardware before treating them as verified or
production-ready.

Contents
- Overview
- Hardware
- Architecture
- Phone microphone sound
  monitoring
- Vibration detection
- Bluetooth protocol
- Alerts and emergency behavior
- Setup
- Testing and verification
- Troubleshooting
- Safety and limitations
Overview
GBU combines an Android Flutter application with an ESP32 sensor node.

The application is intended to: - Connect to the ESP32 using Bluetooth
Classic SPP. - Display temperature, humidity, vibration, water-sensor
readings, risk level, and alerts. - Monitor sound using the phone's
built-in microphone when the user explicitly enables it. - Let the
user start and stop phone-side sound monitoring reliably. - Keep
microphone monitoring separate from ESP32 machine telemetry. - Preserve
machine monitoring and latched machine emergencies when phone microphone
monitoring is disabled.

The app must never simulate live sensor or microphone values in normal
operation. Missing, disconnected, or stale data should be shown as
unavailable.
Hardware
Expected hardware configuration:
  Component                          ESP32 connection Notes
  ESP32 DevKit /                                  --- Main controller
ESP32-WROOM-32                                      

  DHT11                                       GPIO 23 Digital data pin
temperature/humidity
sensor                                              

  SW-420 digital                              GPIO 19 Digital output;
vibration module                                    verify actual
polarity

  Water sensor                                GPIO 34 Analog input; ensure
voltage is safe for
the ESP32

  Buzzer                                      GPIO 18 Check buzzer
voltage/current
requirements

  Green LED                                    GPIO 2 GPIO 2 is a
boot-strapping pin on
common ESP32 boards

  White LED                                    GPIO 4 Status indicator

  Red LED                                     GPIO 16 Warning/critical
indicator
Phone microphone                     Phone hardware Used by the Flutter
app, not connected to
the ESP32
Hardware notes
- The SW-420 is a digital vibration-trigger module. It does not
  directly measure calibrated acceleration, vibration amplitude, or
  frequency.
- Confirm whether the SW-420 output is active HIGH or active LOW on
  the actual module. Do not assume its polarity.
- GPIO 34 is input-only and has no internal pull-up/pull-down
  capability on the ESP32. Check the sensor output circuit and voltage
  range.
- GPIO 2 can affect boot behavior on some ESP32 boards.
- Confirm the buzzer's electrical requirements before connecting it
  directly to a GPIO.
Architecture
The project has two independent data sources:
1. ESP32 machine telemetry: Temperature, humidity, vibration, and
   water-sensor data arrive over Bluetooth Classic SPP.
2. Phone microphone monitoring: The Flutter app captures audio
   locally and calculates compact sound features such as RMS, peak
   amplitude, or a smoothed relative level.
Expected Flutter areas include: - Telemetry and alert models - Bluetooth
service and newline-delimited JSON parsing - Machine controller and
risk/alert logic - Dashboard sensor cards and risk display -
Sound-monitoring controls and audio lifecycle management - Settings and
configuration synchronization, if implemented

Check the actual repository before relying on these names or assuming
every feature is implemented.
Phone microphone sound monitoring
Required behavior
Sound monitoring uses the Android phone's built-in microphone. It
does not require a separate microphone connected to the ESP32.

The app should: - Request microphone permission at runtime. - Display
the actual microphone state. - Process real microphone samples
locally. - Display a relative sound level unless a calibrated
measurement system is available. - Avoid sending raw audio to the ESP32
or a server. If the design requires Bluetooth sound messages, send only
compact calculated features. - Handle permission denial, recording
errors, app lifecycle changes, and cleanup safely. - Prevent multiple
recording sessions from running simultaneously.
Microphone OFF means sound monitoring OFF
When the user switches the microphone OFF or taps Stop, all
microphone-based monitoring must stop---not merely disappear from the
UI.

The app must: 1. Stop the actual audio recorder and release microphone
resources. 2. Stop audio-stream processing and reject late callbacks
from the stopped session. 3. Cancel microphone-related timers,
subscriptions, and pending work. 4. Stop live sound-meter updates and
microphone-based threshold checks. 5. Prevent new microphone-based
alerts while monitoring is OFF. 6. Clear the live value or display --,
and show Sound Monitoring Disabled. 7. Report an accurate OFF/error
state if permission is revoked or recording fails. 8. Start a fresh
session with fresh samples when the user enables monitoring again.

A suitable state model is:

IDLE → STARTING → RUNNING → STOPPING → IDLE

The UI should show a state such as Microphone Off, Listening,
Stopping, or Microphone Permission Required based on the real
recorder state.

Important: Turning the microphone OFF must not disable ESP32
temperature, vibration, or water monitoring. It must not automatically
clear an already-latched machine emergency.
Sound-level limitations
- RMS, peak amplitude, and normalized levels are signal features, not
  automatically calibrated decibels.
- Do not label readings as accurate dB SPL unless the phone/microphone
  system has been calibrated and validated.
- Sound thresholds and persistence should be configurable if the
  settings implementation supports them.
- Use persistence and/or hysteresis to reduce alert flicker near a
  threshold.
- Never allow stale sound values to create new alerts after monitoring
  stops.
Vibration detection
The SW-420 module connects to ESP32 GPIO 19.

Expected behavior: - Read the module's digital output. - Verify and
support the actual active-HIGH or active-LOW polarity. - Debounce
transitions and, if required, count trigger events over a configurable
time window. - Send the vibration state and any event count/rate through
the existing Bluetooth telemetry protocol. - Parse the fields
consistently in firmware, Flutter models, controllers, and UI. - Display
No vibration, Vibration detected, or Sensor unavailable as
appropriate. - Treat disconnected or stale telemetry as unavailable, not
as a confirmed zero-vibration reading.

The app cannot verify physical vibration detection from software tests
alone. Test the sensor on the actual ESP32 and confirm that its digital
output changes when the sensor is triggered.
Bluetooth protocol
Expected connection: - Bluetooth mode: Classic Bluetooth Serial Port
Profile (SPP) - Expected device name: EdgeAI_Predictive_Node -
Expected message framing: newline-delimited JSON, if retained by the
existing implementation

The firmware and Flutter app must agree on: - JSON field names and data
types - Numeric ranges and missing-value behavior - Message types for
telemetry, configuration, acknowledgements, and commands - Handling of
partial packets, multiple messages in one packet, and malformed JSON

Keep phone microphone features separate from ESP32 telemetry. A
sound-feature message must not be parsed as a machine telemetry message
accidentally.

Do not rename a field on only one side of the Bluetooth connection.
Confirm the exact schema from the current source code and firmware.
Alerts and emergency behavior
The application may use risk levels and sensor thresholds to generate
alerts. The exact thresholds must be confirmed from the current
configuration and code.

Important separation: - Stopping phone microphone monitoring stops
microphone-derived monitoring and new microphone-derived alerts. - It
must not silently clear a latched machine emergency caused by ESP32
telemetry. - An existing critical emergency should remain latched until
the established acknowledgement/reset procedure permits clearing it. -
If the buzzer is configured to sound for a critical event, enforce its
timeout in ESP32 firmware with non-blocking timing. Repeated telemetry
must not continually restart the timeout. - A UI emergency overlay is
not a physical safety interlock. Any machinery shutdown or physical
emergency-stop behavior requires appropriately designed hardware and
safety review.
Setup
Requirements
- Flutter SDK compatible with the project
- Android SDK and Android device or emulator
- Android Studio or another configured Android build environment
- ESP32 board and required sensors for hardware testing
- Arduino IDE or the firmware's documented build environment
- A physical Android phone for microphone behavior verification
Run the Flutter app
From the project directory:
cd D:\projects\gbu\gbu
flutter pub get
flutter analyze
flutter test
flutter run
To build a release APK:
flutter build apk --release
These commands are instructions, not a claim that the current source
passes them. Review the command output and resolve any errors before
distributing a build.
Android permissions
Verify that the app declares and requests the permissions required by
the exact Bluetooth and audio packages in use. Android Bluetooth
permissions vary by Android version. Microphone permission must be
requested at runtime before recording.

Do not assume permission is granted because it appears in the manifest.
Handle denied and permanently denied states in the UI.
Testing and verification
Phone microphone checklist
- [ ] First-time permission request works.
- [ ] Denied permission is handled without crashing.
- [ ] Starting monitoring captures real phone microphone samples.
- [ ] Speaking near the phone changes the relative sound level.
- [ ] Repeated Start taps do not create multiple recorder sessions.
- [ ] Stop releases the microphone and ends audio processing.
- [ ] No meter updates or new microphone-based alerts occur after
  Stop.
- [ ] Late callbacks from an old session cannot update the current UI.
- [ ] Stopping an already-stopped session is safe.
- [ ] App navigation, backgrounding, and recording errors clean up
  safely.
- [ ] Re-enabling monitoring starts a fresh session.
- [ ] Turning the microphone OFF does not stop ESP32 sensor monitoring
  or clear a latched machine emergency.
Vibration checklist
- [ ] Confirm SW-420 wiring and actual output polarity.
- [ ] Observe GPIO 19 while the sensor is still and while triggered.
- [ ] Verify debounce and event counting, if implemented.
- [ ] Confirm the ESP32 sends the expected JSON.
- [ ] Confirm Flutter parses the same field names and data types.
- [ ] Verify the dashboard changes when the physical sensor is
  triggered.
- [ ] Verify disconnected/stale telemetry displays as unavailable.
- [ ] Confirm vibration detection continues when the phone microphone
  is OFF.
Integration checklist
- [ ] Bluetooth connects to the expected device.
- [ ] Partial and malformed messages are handled safely.
- [ ] Existing commands and configuration behavior still work.
- [ ] Risk calculations and emergency latching still work.
- [ ] Run flutter analyze, flutter test, and an Android build.
- [ ] Record physical-device test results separately from automated
  test results.
Troubleshooting
Sound level keeps updating after Stop
Inspect the recorder stop/dispose flow, audio-stream subscriptions,
timers, state management, and callbacks. Ensure the UI changes to OFF
only after the recording session has stopped or been safely released.
Cancel subscriptions and invalidate callbacks from the previous session.
Sound alert stays active with microphone OFF
Ensure microphone-derived threshold checks cannot run when the
monitoring state is OFF and that stale values cannot generate new
alerts. Decide separately whether an already-triggered alert should
remain visible for acknowledgement; do not conflate this with continuing
to listen.
Vibration never changes
Check: 1. Sensor power and common ground. 2. SW-420 sensitivity
adjustment. 3. The digital output using a serial diagnostic. 4.
Active-HIGH versus active-LOW polarity. 5. GPIO 19 configuration. 6.
JSON field names and value types. 7. Bluetooth packet framing and
Flutter parsing. 8. Telemetry freshness logic and dashboard state
updates.
Vibration appears permanently active
Check polarity, debounce behavior, and whether the firmware is
transmitting a raw pin value or a derived event state. Test the actual
GPIO output instead of changing the UI to force an expected result.
Bluetooth connects but values do not update
Compare one complete line of actual ESP32 JSON with the Flutter parser's
expected schema. Verify newline framing, buffering, parsing errors, and
timestamps or stale-data rules.
Safety and limitations
- This project is a prototype monitoring system, not a certified
  industrial safety system.
- Do not use app alerts as the sole protection for hazardous
  equipment.
- Verify sensor readings and thresholds on the real hardware before
  relying on them.
- Do not describe heuristic risk scores as validated predictive
  accuracy without appropriate evaluation.
- Keep raw microphone audio local unless a separately reviewed feature
  explicitly requires otherwise and the user has consented.
- Document any unimplemented or unverified feature honestly.
Development status
Update this section after each verified implementation:
- Phone microphone Start/Stop: Not verified in this README;
  confirm on a physical Android phone.
- Sound monitoring OFF behavior: Must stop recorder, processing,
  and new microphone-based alerts.
- SW-420 vibration detection: Requires polarity, wiring, firmware,
  Bluetooth, and dashboard verification.
- Automated tests and Android build: Record actual command
  results.
- Hardware validation: Record which sensors and phone models were
  physically tested.
