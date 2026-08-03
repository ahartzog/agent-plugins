---
domain: program
type: reference
description: "Ground segment architecture overview for the golden-fixture demo program — stable facts, not status."
decay: slow
confidence: high
last_updated: 2026-06-01
---

# Ground Segment Overview

The demo program's ground segment consists of three subsystems: the mission planning console,
the telemetry & command (T&C) front end, and the ground-to-space RF link. This file is the
one-hop local target for golden case 1 — it lives directly under `knowledge/` and requires no
external fetch to answer questions about it.

## Subsystems

- **Mission Planning Console** — schedules contacts, builds command loads.
- **T&C Front End** — decodes downlink telemetry, encodes uplink commands.
- **RF Link** — S-band uplink, X-band downlink, one ground station (PROJ-123 site).

[learned: 2026-06-01]
