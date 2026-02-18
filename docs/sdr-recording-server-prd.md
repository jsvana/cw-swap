# SDR Recording Server — Product Requirements Document

**Date:** 2026-02-18
**Status:** Draft
**Author:** CW Swap Team

## Problem Statement

Today's ham radio operators have limited options for capturing, reviewing, and analyzing RF activity. WebSDRs exist but offer no recording infrastructure, no transcription, and no integration with tools operators already use. CW Swap's iOS app has signal-processing algorithms (price extraction, listing parsing) that demonstrate what structured data extraction from ham radio sources looks like — but they're limited to the device.

A server-side SDR recording platform removes all those constraints: always-on capture, multi-receiver correlation, persistent archives, and compute-heavy processing (ML classification, auto-transcription) that would drain a phone battery in minutes.

## Vision

An always-on SDR recording server that captures, decodes, transcribes, and indexes ham radio activity — making the RF spectrum searchable and streamable.

---

## Core Features

### 1. SDR Hardware Management

**Configure and manage multiple SDR receivers from a unified interface.**

- **Hardware abstraction layer** — unified API across SDR backends:
  - RTL-SDR (via `rtl_sdr` / `SoapySDR`)
  - SDRplay RSP series (via `SoapySDR`)
  - Airspy HF+ / Mini
  - KiwiSDR (network SDR, WebSocket API)
  - Remote WebSDRs (scrape/stream audio)
  - FlexRadio SmartSDR (via SmartSDR API / DAX)
  - Elad FDM-S3 or similar high-end DDC receivers
- **Per-SDR configuration:**
  - Center frequency, sample rate, bandwidth
  - Gain settings (AGC or manual)
  - Antenna port selection
  - Duty cycle / scheduling (e.g., only record 40m at night)
  - Geographic location (for propagation correlation)
  - Label / name for identification
- **Health monitoring:**
  - Signal quality metrics (noise floor, ADC clipping)
  - USB/network connection status
  - Automatic reconnection on dropout
  - Disk usage warnings

### 2. Recording Engine

**Continuous or scheduled RF capture with structured storage.**

- **Recording modes:**
  - Continuous (24/7 band capture)
  - Scheduled (e.g., 20m from 1800-0200 UTC)
  - Triggered (start recording on signal detection above threshold)
  - Event-driven (contest weekends, DXpedition alerts)
- **Storage format:**
  - Raw IQ (for full-fidelity replay and reprocessing)
  - Demodulated audio (WAV/FLAC per-channel)
  - Compressed IQ (SigMF format with metadata)
- **Segmentation:**
  - Automatic chunking by time interval (configurable: 1min, 5min, 15min, 1hr)
  - Signal-boundary detection (split on silence / carrier drop)
  - Per-QSO isolation when decoder is active

### 3. Time Alignment

**Synchronize recordings across multiple SDRs and sessions.**

- GPS-disciplined timestamps (via `gpsd` or NTP with PPS)
- NTP sync with sub-millisecond accuracy when GPS unavailable
- All recordings tagged with UTC timestamp + source SDR ID
- Cross-receiver alignment for comparing the same signal from different locations / antennas
- Drift compensation for SDRs with poor oscillator stability
- Playback engine that can sync multiple recordings to the same timeline

### 4. Signal Processing & Decoding

**Bring CW Swap's extraction approach to RF signals.**

- **CW decoder:**
  - Adaptive speed tracking (5-50 WPM)
  - Multi-signal separation (multiple CW signals in passband)
  - Farnsworth spacing handling
  - Prosign recognition
  - Confidence scoring per character
- **Digital mode decoders:**
  - FT8 / FT4 (via `wsjtx` integration or native implementation)
  - RTTY (45.45 baud, 170 Hz shift standard + variants)
  - PSK31 / PSK63
  - JS8Call
  - Winlink RMS packet detection
- **Voice processing:**
  - SSB demodulation with passband tuning
  - AM / FM demodulation
  - Voice Activity Detection (VAD) to skip dead air
  - Speaker diarization (distinguish different operators in a QSO)
- **Signal classification:**
  - Auto-detect mode (CW, SSB, AM, FM, FT8, RTTY, etc.) from spectral characteristics
  - ML model trained on labeled ham radio signals
  - Unknown signal flagging for manual review

### 5. Auto-Transcription

**Convert decoded signals to searchable text.**

- **CW transcription:**
  - Real-time Morse-to-text with WPM annotation
  - Callsign extraction and validation against FCC/ITU databases
  - RST report extraction
  - QSO structured data extraction (callsigns, RST, QTH, name, frequency)
- **Voice transcription:**
  - Whisper-based speech-to-text on demodulated SSB/FM audio
  - Ham radio vocabulary fine-tuning (callsigns, Q-codes, phonetic alphabet)
  - Callsign spotting from voice (e.g., "CQ CQ CQ de Whiskey One Alpha Bravo Charlie")
- **Digital mode transcription:**
  - FT8/FT4 message decode → structured QSO records
  - RTTY/PSK text capture
  - JS8Call message threading
- **Transcription storage:**
  - Full text with timestamps linked to audio segments
  - Structured QSO records (callsign, frequency, mode, time, RST, exchange)
  - Full-text search index (Meilisearch or Tantivy)

### 6. Carrier Wave App Streaming

**Live stream decoded activity to the CW Swap / Carrier Wave iOS app.**

- **WebSocket streaming:**
  - Live audio stream (Opus-encoded, selectable bandwidth)
  - Real-time decoded text overlay
  - Waterfall/spectrogram data for visual display
  - Band activity heatmap
- **Stream types:**
  - Single-frequency monitor (tune to one signal)
  - Band overview (compressed wideband view)
  - Decoded feed (text-only stream of all decoded QSOs)
  - Alert stream (push notifications for matched criteria)
- **App integration:**
  - Stream discovery (browse available server streams)
  - Multi-server support (connect to multiple recording servers)
  - Offline mode (buffer + store streams for later review)
  - Share interesting captures with other users

### 7. RBN-Driven SDR Tasking

**Automatically tune SDRs based on Reverse Beacon Network spots.**

- **RBN telnet feed integration:**
  - Real-time spot ingestion from RBN nodes
  - Filter by band, mode, SNR, spotted callsign, spotter location
- **Auto-tasking rules:**
  - "When RBN spots a new DXCC entity on 20m CW, tune SDR-2 to that frequency and record for 10 minutes"
  - "Track the loudest signal on each open band"
  - "Follow a specific DXpedition callsign across bands"
  - "Record any signal above 30 dB SNR on 40m"
- **DX Cluster integration:**
  - Ingest DX cluster spots alongside RBN
  - Cross-reference spots with recordings ("was I actually hearing that DX?")
  - Spot validation — confirm RBN/cluster spots with local reception
- **Propagation-aware scheduling:**
  - Use VOACAP / IRI models to predict band openings
  - Pre-position SDRs on bands predicted to open
  - Seasonal/solar cycle profiles

---

## Extended Features

### 8. Band Condition Monitoring & Analytics

- Continuous noise floor measurement per band
- Band-open / band-closed detection
- Propagation mode classification (F2, Es, ground wave) from signal characteristics
- Historical band condition database (queryable: "How was 10m on 2026-01-15?")
- Solar flux / K-index / A-index correlation with observed conditions
- Automated band condition reports (daily/hourly summaries)

### 9. Contest Recording & Replay

- Full-band IQ capture during contest weekends
- Post-contest replay with synchronized clock
- Rate meter overlay (QSOs/hour from decoded signals)
- Multiplier tracking from decoded exchanges
- Log cross-reference (compare your log against what was actually on the air)
- Spectrum timelapse generation (compressed waterfall video of entire contest)

### 10. Skimmer-as-a-Service

- Continuous CW/RTTY/FT8 decoding across multiple bands simultaneously
- Publish spots to RBN (become an RBN node)
- Private spot feed for personal use
- Historical spot database with search
- Frequency/callsign activity graphs over time

### 11. Multi-Site Correlation

- Federate multiple recording servers across geographic locations
- Compare signal reports from different QTHs simultaneously
- True diversity reception (combine signals from multiple sites)
- Propagation path visualization on map
- Collaborative recording (multiple operators contribute SDRs to a shared pool)

### 12. Alert System

- **Trigger types:**
  - Callsign spotted (specific call or prefix, e.g., "any 3Y*")
  - Band opening detected (specific band + direction)
  - New DXCC entity heard
  - Contest starting
  - Signal anomaly (unusual signal type detected)
  - Silence alert (expected signal disappeared — monitor goes quiet)
- **Delivery:**
  - Push notification to Carrier Wave app
  - Email digest
  - Webhook (integrate with Discord, Slack, Home Assistant)
  - SMS via Twilio (for critical alerts)

### 13. Archive & Search

- Retain recordings based on configurable policies (keep all CW forever, voice for 30 days, raw IQ for 7 days)
- Full-text search across all transcriptions
- Filter by: date range, frequency, mode, callsign, SNR, duration
- "Find all QSOs involving W1AW on 20m CW in January 2026"
- Shareable permalinks to specific recordings
- ADIF export of decoded QSOs for logging software (Log4OM, DXKeeper, Cloudlog)

### 14. Logging Integration

- Export decoded QSOs as ADIF records
- Direct integration with Cloudlog, Log4OM, DXKeeper, N1MM+
- QSO confirmation cross-reference (check against LoTW, QRZ, eQSL)
- DXCC / WAS / VUCC progress tracking from decoded signals
- "You've heard 237 DXCC entities this month but only logged 180"

---

## Architecture

### System Overview

```
                                    ┌─────────────────┐
                                    │  Carrier Wave    │
                                    │  iOS App         │
                                    └────────┬─────────┘
                                             │ WebSocket / REST
                                             │
┌──────────┐   ┌──────────┐        ┌────────┴──────────┐
│ RTL-SDR  │   │ KiwiSDR  │  ...   │   API Gateway     │
│ (local)  │   │ (remote) │        │   (axum / tower)  │
└────┬─────┘   └────┬─────┘        └────────┬──────────┘
     │              │                       │
     └──────┬───────┘               ┌───────┴────────┐
            │                       │                │
     ┌──────┴───────┐        ┌─────┴─────┐   ┌─────┴──────┐
     │ SDR Manager  │        │ Recording │   │ Search /   │
     │ (SoapySDR)   │        │ Archive   │   │ Query API  │
     └──────┬───────┘        │ (S3/disk) │   └─────┬──────┘
            │                └───────────┘         │
     ┌──────┴───────┐                        ┌────┴───────┐
     │ DSP Pipeline │                        │ Tantivy /  │
     │ (IQ → audio) │                        │ Meilisearch│
     └──────┬───────┘                        └────────────┘
            │
     ┌──────┴──────────────────────┐
     │        Decoder Farm         │
     ├─────────┬─────────┬─────────┤
     │ CW      │ FT8     │ Voice   │
     │ Decoder │ Decoder │ (Whisper)│
     └─────────┴─────────┴─────────┘
            │
     ┌──────┴───────┐
     │ Transcription│──→ Search Index
     │ + QSO Extract│──→ ADIF Export
     └──────┬───────┘──→ Alert Engine
            │
     ┌──────┴───────┐
     │ RBN / DX     │
     │ Cluster Feed │
     └──────────────┘
```

### Tech Stack (proposed)

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Core server | Rust (tokio + axum) | Existing backend familiarity, performance for DSP |
| SDR interface | SoapySDR (C/Rust bindings) | Broadest hardware support |
| DSP | Rust (`rustfft`, custom filters) | Low-latency, zero-copy processing |
| CW decoder | Rust (port from iOS algorithms) | Direct code reuse path |
| FT8/FT4 | `wsjtx` subprocess or `ft8_lib` | Battle-tested decoding |
| Voice transcription | Whisper.cpp (local) or Whisper API | Best-in-class speech-to-text |
| Storage | Local disk + optional S3 | IQ files are large, need tiered storage |
| Metadata DB | SQLite (single node) / Postgres (multi) | Structured QSO/recording metadata |
| Search index | Tantivy (Rust) or Meilisearch | Full-text search over transcriptions |
| Streaming | WebSocket (tokio-tungstenite) | Low-latency live audio + data |
| Config | TOML files + REST API | File-based for headless, API for app control |
| RBN feed | Telnet client (tokio) | Standard RBN interface |
| Alerts | Push (APNs), webhooks, email (lettre) | Multi-channel notification |

### Storage Estimates

| Data Type | Rate | Daily (per SDR) | Monthly |
|-----------|------|-----------------|---------|
| Raw IQ (2 MS/s, 8-bit) | ~4 MB/s | ~346 GB | ~10 TB |
| Raw IQ (250 kS/s, 16-bit) | ~1 MB/s | ~86 GB | ~2.6 TB |
| Demodulated audio (48kHz mono FLAC) | ~100 KB/s | ~8.6 GB | ~260 GB |
| Transcription text | negligible | ~10 MB | ~300 MB |

IQ storage is the bottleneck. Tiered retention is essential: keep full IQ for days, audio for weeks/months, text forever.

---

## Configuration Example

```toml
[server]
name = "k1abc-sdr-server"
location = "FN42ig"  # Maidenhead grid
gps_device = "/dev/ttyACM0"  # optional, for precise timing

[[sdr]]
id = "rtlsdr-1"
driver = "rtlsdr"
device_index = 0
label = "40m Dipole"
antenna = "dipole-40m"

[[sdr]]
id = "kiwisdr-vk"
driver = "kiwisdr"
url = "http://vk4rza.proxy.kiwisdr.com:8073"
label = "VK4 KiwiSDR"

[[recording]]
sdr = "rtlsdr-1"
frequency = 7_030_000  # 40m CW
bandwidth = 2_400
mode = "cw"
schedule = "00:00-06:00 UTC"  # nighttime propagation
decoders = ["cw"]
retention_days = 30

[[recording]]
sdr = "rtlsdr-1"
frequency = 14_074_000  # 20m FT8
bandwidth = 3_000
mode = "usb"
schedule = "always"
decoders = ["ft8"]
retention_days = 90

[[rbn_task]]
trigger = "new_dxcc"
band = "20m"
mode = "cw"
min_snr = 15
sdr = "rtlsdr-1"
action = "record"
duration_minutes = 10
alert = true

[[alert]]
name = "Bouvet Island"
type = "callsign_prefix"
prefix = "3Y"
notify = ["push", "email"]
```

---

## API Surface (sketch)

```
GET    /api/v1/sdrs                          # list configured SDRs
POST   /api/v1/sdrs                          # add SDR
GET    /api/v1/sdrs/:id/status               # health, signal metrics

GET    /api/v1/recordings                    # list recordings (filtered)
GET    /api/v1/recordings/:id                # recording metadata
GET    /api/v1/recordings/:id/audio          # stream audio (range support)
GET    /api/v1/recordings/:id/iq             # download raw IQ
GET    /api/v1/recordings/:id/transcript     # decoded text

GET    /api/v1/qsos                          # search decoded QSOs
GET    /api/v1/qsos/export?format=adif       # ADIF export

GET    /api/v1/bands                         # current band conditions
GET    /api/v1/bands/:band/history           # historical conditions

WS     /api/v1/stream/:sdr_id               # live audio + decode stream
WS     /api/v1/stream/decoded               # all decoded text (firehose)
WS     /api/v1/stream/alerts                # alert feed

GET    /api/v1/spots                         # RBN/cluster spots
GET    /api/v1/spots/matched                 # spots matched to recordings

POST   /api/v1/tasks                         # create RBN-driven task rule
GET    /api/v1/tasks                         # list task rules

GET    /api/v1/search?q=...                  # full-text transcription search
```

---

## Deployment Models

### Single Station (Home Operator)
- Raspberry Pi 5 or mini PC
- 1-2 RTL-SDRs
- External USB drive for storage
- Runs as systemd service
- Accessible via Tailscale for remote monitoring

### Club Station
- Dedicated server (8+ cores, 32GB RAM for Whisper)
- Multiple SDRs covering HF + VHF/UHF
- NAS or S3-compatible storage
- Multi-user access with API keys
- Dashboard on always-on monitor in shack

### Distributed Network
- Multiple single-station nodes reporting to a coordinator
- Shared search index across sites
- Cross-site signal comparison
- Aggregated band condition reports

---

## Open Questions

1. **IQ vs. audio-only recording?** Full IQ enables reprocessing with better decoders later, but storage costs are 10-40x higher. Offer both, default to audio-only with IQ opt-in?
2. **Licensing for WSJT-X integration?** WSJT-X is GPL — need to evaluate whether subprocess invocation vs. library linking affects licensing of the server.
3. **KiwiSDR ToS?** Some public KiwiSDRs prohibit automated/continuous use. Need per-SDR policy configuration and rate limiting.
4. **Whisper model size vs. hardware?** `whisper-large-v3` needs a decent GPU. `whisper-tiny` runs on CPU but accuracy on ham radio audio (noise, QRM, accents) may be poor. Need to benchmark with actual SSB recordings.
5. **Privacy considerations?** Recording and transcribing voice QSOs at scale raises questions. Ham radio is legally public, but bulk surveillance of conversations could be controversial. Consider opt-out mechanisms or callsign anonymization options.
6. **Monetization model?** Open source core with hosted/managed service? Hardware bundles? Or purely open source community project?
7. **FCC Part 97 compliance?** Automated retransmission (streaming to app users) — need to verify this doesn't constitute rebroadcasting under Part 97 rules. Likely fine since it's internet retransmission, not RF, but worth confirming.

---

## Milestones

### M0: Foundation
- SDR hardware abstraction (RTL-SDR + KiwiSDR)
- Basic recording engine (continuous capture to FLAC)
- GPS/NTP time-stamping
- TOML configuration
- REST API skeleton

### M1: Decoding
- CW decoder (port from iOS)
- FT8 decoder (wsjtx integration)
- Transcription storage + basic search
- Per-recording metadata

### M2: Streaming & App Integration
- WebSocket audio streaming
- Carrier Wave app connection
- Live decode overlay
- Stream discovery API

### M3: Intelligence
- RBN feed integration
- Auto-tasking engine
- Alert system (push + webhook)
- Band condition monitoring

### M4: Scale
- Multi-SDR coordination
- Multi-site federation
- ML signal classification
- Voice transcription (Whisper)
- Full-text search index
- Contest recording mode

### M5: Community
- Public API for third-party integrations
- ADIF export + logging software integration
- Shared recording archives
- Collaborative spot validation
