# RotorDash

> Full-screen EdgeTX telemetry dashboard widget for Rotorflight helicopters.
> Designed and tested on the RadioMaster TX15 with ELRS.

---

## Credits

Based on [Rotorflight Telemetry Widget](https://github.com/liuhm2019-crypto/RotorflightTelemeteringScript) by **liuhm2019-crypto**.
Original work is credited and appreciated. All RotorDash releases carry this attribution.

Developed by **Marco Cabral**.

---

## Overview

RotorDash is a Lua widget for EdgeTX that displays real-time Rotorflight telemetry in full-screen App Mode — no transmitter UI clutter. A single TX model is used for all helicopters.

Three screens are selectable via a SOURCE switch on your transmitter: pre-flight checks, in-flight monitoring, and post-flight review.

---

## Requirements

| Item | Detail |
|---|---|
| Transmitter | RadioMaster TX15 (tested) — any EdgeTX color screen TX should work |
| Firmware | EdgeTX 2.9 or later |
| Flight controller | Rotorflight with MSP telemetry enabled |
| Link | ExpressLRS (ELRS) |

---

## Features

### Top Bar (always visible)
- **HOLD** — shows ON/OFF state of your hold switch
- **PID** — active PID profile (color coded: 1=blue, 2=orange, 3=yellow)
- **RTE** — active rate profile (same color coding)
- **GOV** — governor state when armed (OFF / IDLE / SPOOLUP / ACTIVE / etc.)
- **ARM** — shows DISARMED when not armed
- **RQLY** — link quality as a 5-block signal bar (red → green)
- **TX** — transmitter battery voltage with low/warn color thresholds

### Screen 1 — Ground
Pre-flight and ground checks.
- RPM (headspeed)
- Flight timer
- Battery voltage, cell voltage, battery percentage
- BEC voltage, current draw, capacity used
- Model image (loads `ModelName.png` from the widget folder, falls back to `default.png`)
- Model name
- Clock

### Screen 2 — Flight
Clean in-flight view with the essential numbers large and readable.
- Animated battery indicator with warning blink when cell voltage drops below threshold
- RPM (large)
- Flight timer (large)

### Screen 3 — Post-flight *(coming soon)*
Post-flight review screen. Planned for flight summary data.

### Battery Warning
- Triggers when cell voltage drops below **4.15V**
- Battery indicator blinks red as a visual alert
- Warning is suppressed once the helicopter is armed (no false alerts on the bench)

---

## Installation

1. Copy the `RotorDash` folder to your TX SD card:
```
SD Card
└── WIDGETS
    └── RotorDash
        └── main.lua
```

2. (Optional) Add a model image named after your model:
```
WIDGETS/RotorDash/MyHeli.png
```
Falls back to `default.png` if no model image is found.

3. On the TX:
   - Long-press the main screen → **Add Widget** → select **RotorDash**
   - Set it to full-screen / App Mode
   - Assign widget options:
     - **HoldSwitch** — your hold switch
     - **ScreenSwitch** — a 3-position switch or slider to change screens

---

## Screen Switch

The ScreenSwitch SOURCE controls which screen is shown:

| Switch position | Screen |
|---|---|
| Low (≤ -50) | Screen 1 — Ground |
| Mid (= 0) | Screen 2 — Flight |
| High (≥ +50) | Screen 3 — Post-flight |

---

## Telemetry Sensors

RotorDash reads the following Rotorflight MSP telemetry sensors:

| Sensor | Description |
|---|---|
| `ARM` | Arm status |
| `Bat%` | Battery percentage |
| `Capa` | Capacity used (mAh) |
| `Curr` | Current draw (A) |
| `Gov` | Governor state |
| `Hspd` | Headspeed (RPM) |
| `PID#` | Active PID profile |
| `RTE#` | Active rate profile |
| `RQly` | Link quality |
| `Vbat` | Battery voltage |
| `Vbec` | BEC voltage |
| `Vcel` | Cell voltage |

---

## Changelog

### v0.1.0
- Initial public release
- Top bar: HOLD, PID, RTE, GOV/ARM, RQLY, TX voltage
- Screen 1: ground checks with model image, battery data, RPM, timer, clock
- Screen 2: flight view with animated battery, large RPM and timer
- Screen 3: placeholder (post-flight, coming soon)
- Battery warning with blink and arm-suppression logic
- Current peak tracking

---

## License

MIT — see [LICENSE](LICENSE).
Original widget by liuhm2019-crypto retains its own license.
