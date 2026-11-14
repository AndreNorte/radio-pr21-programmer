# PR-21 Memory Map

Memory is 256 bytes. Addresses ≥ 0x0100 mirror 0x0000 (verified by dump).

## Channels: 0x0000–0x00CF, 16 records of 13 bytes

| Offset | Field |
|---|---|
| 0..3 | RX, 4 bytes LE, units of 10 Hz (44600625 = 446.00625 MHz) |
| 4..7 | TX, same |
| 8..9 | RX tone, 2 bytes LE |
| 10..11 | TX tone, 2 bytes LE |
| 12 | flags |

Tone: `0x8000 | code` — DCS (code in octal: D074N = 0o74 = 0x803C),
otherwise CTCSS in tenths of a hertz, `0xFFFF` — disabled.

Channel flags (confirmed by comparison with CPS):

| Bit | Meaning |
|---|---|
| 0x01 | Busy Lock off |
| 0x08 | High power (0 — low) |
| 0x10 | Scan Add off |
| 0x20 | Scrambler off |
| 0x40 | Compander off |

The bandwidth bit (Wide/Narrow) has not been found yet.

## Settings: 0x00D0–0x00FF, 13-byte block

The layout was recovered from the decompiled CPS (`docs/cps-analysis.md`) and checked
against its screen: all values matched.

| Offset | What | Values |
|---|---|---|
| 0 | flags | bit0 beep, bit1 battery save, bits2-3 voice (0 none, 1 Chinese, 2 English), bits4-5 spec (0 Spec 1, 1 Spec 2), bit6 scan (0 Carrier, 1 Time), bit7 service |
| 1 | squelch | 0..9 (0 — open) |
| 2 | TOT | 0 = OFF, 1..10 = 30..300 s in 30 s steps |
| 3 | VOX | 0 = OFF, 1..9 |
| 4 | VOX delay | 0..5 = 0.5..3.0 s |
| 7 | side button 1 | 0 OFF, 1 Transient monitoring, 2 Scan, 3 Voice control, 4 High/Low Power |
| 8 | side button 2 | same |
| 5, 6, 9..12 | service | this CPS model does not use them |

Verified on the device: reading the settings gives values matching the CPS screen
(squelch 5, beep on, battery save on, English, Carrier, TOT 60, VOX 5, delay 1.5,
side buttons Scan and Voice control); writing `--squelch 6` and reverting with `--squelch 5`
passed with byte-by-byte verification.

Not found: the Narrow bandwidth bit in the channel flag.
