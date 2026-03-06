# SnoreLess - App Review Notes

## App Information
- **App Name**: SnoreLess
- **Bundle ID**: com.nicenoodle.snoreless
- **Developer**: Sangmyun Jeon (nicenoodle)
- **Contact**: jimmyjeon420@gmail.com

---

## 1. Microphone Usage (NSMicrophoneUsageDescription)

**Purpose**: The app uses the Apple Watch microphone to measure ambient sound levels (decibels) in real time to detect snoring events during sleep.

**How it works**:
- The audio stream is processed on-device in real time to calculate dB levels.
- Audio data is analyzed and immediately discarded after dB measurement.
- No audio is transmitted to any external server.
- Optional short recordings (5-10 seconds) of snoring events can be saved locally on the device for the user's own reference. This feature is opt-in and clearly disclosed to the user.

**Privacy**: All audio processing happens 100% on-device. No audio data leaves the user's iPhone or Apple Watch.

---

## 2. Background Audio (UIBackgroundModes: audio)

**Purpose**: The app requires background audio capability to continuously monitor snoring during sleep sessions, which typically last 6-8 hours.

**Why it's necessary**:
- Snoring monitoring must remain active while the user sleeps, even when the screen is off.
- The Apple Watch maintains an active audio session to detect snoring sounds in real time.
- When snoring is detected, the app delivers haptic feedback to encourage the user to change sleeping position.
- Without background audio, the app cannot fulfill its core function of real-time snoring detection during sleep.

**Battery consideration**: The app uses optimized audio processing with low sampling rates sufficient for snoring detection, minimizing battery impact.

---

## 3. HealthKit Usage (NSHealthShareUsageDescription / NSHealthUpdateUsageDescription)

**Purpose**: The app integrates with HealthKit to read and write sleep analysis data.

**Data read**:
- Sleep analysis data (to correlate sleep stages with snoring events)

**Data written**:
- Sleep analysis records (snoring-interrupted sleep segments)

**Why it's necessary**: Correlating snoring events with sleep stages allows the app to provide meaningful insights (e.g., snoring is more frequent during deep sleep vs. light sleep) and power the Smart Alarm feature that wakes users during light sleep phases.

---

## 4. How to Test the App

### Basic Flow
1. Install the app on iPhone and paired Apple Watch.
2. Open the iPhone app and grant microphone and HealthKit permissions.
3. Open the Watch app and tap "Start Sleep Monitoring."
4. To simulate snoring: play a snoring sound from a speaker near the Apple Watch (YouTube "snoring sound effect" works well, volume at ~60-70 dB).
5. The Watch should detect the sound and deliver haptic feedback within 5-10 seconds.
6. Stop the snoring sound. The app should log the event as "resolved after haptic."
7. Tap "Stop Monitoring" on the Watch or iPhone.
8. Check the Morning Report on the iPhone app for the recorded session.

### 3-Stage Escalation Test
1. Start monitoring and play continuous snoring sound.
2. Stage 1: Watch delivers gentle haptic (after ~5 seconds of snoring detection).
3. Keep playing the sound. Stage 2: Watch delivers strong haptic (after ~15 more seconds).
4. Keep playing the sound. Stage 3: iPhone vibrates (after ~30 more seconds).
5. Stop the sound at any stage to verify the app correctly logs which stage resolved the snoring.

### Smart Alarm Test
1. Start a sleep monitoring session.
2. Set a Smart Alarm wake-up window (e.g., 30-minute window before desired wake time).
3. The alarm will trigger during detected light sleep within the window.
4. For testing, the alarm can be set with a short window (e.g., 5 minutes from now).

### Partner Sharing Test
1. Record at least one sleep session with snoring events.
2. Go to the Morning Report and tap "Share with Partner."
3. A share sheet appears with a summary card that can be sent via iMessage, AirDrop, etc.

### Demo Account
No account or login is required. The app works entirely offline with on-device data.

---

## 5. Additional Notes

- The app does NOT require an internet connection to function.
- No user accounts, no sign-up, no login.
- No ads, no analytics SDKs, no third-party tracking.
- No in-app purchases in this version.
- Privacy policy URL: https://jimmyjeon420-png.github.io/snoreless/privacy-policy.html
