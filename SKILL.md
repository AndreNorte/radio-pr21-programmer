---
name: radio-pr21-programmer
description: >
  Programming ONIKS PR-21 and compatible handheld radios (M31 platform, CD18RAM entry key,
  Kenwood 2-pin cable on a CH340 chip) from macOS, Windows and Linux. Use this skill whenever
  the task involves reading or writing channels on such a radio, squelch, DCS/CTCSS tones,
  power, VOX, TOT, side keys, cloning one radio into another, backing up or restoring settings,
  or when the user says "radio", "walkie-talkie", "flash the radio", "program the radio",
  "radio does not respond", "CD18RAM", "M31", "PR-21", "Kenwood cable", "CH340", "PMR446" or
  "LPD". Apply it even when the user only asks to "set up the channels" without naming a model.
---

# Programming ONIKS PR-21 radios (M31 platform)

This skill documents a protocol that was verified on real hardware, the radio's memory map, and
the order of operations that keeps the radio recoverable.

**Tested on: ONIKS PR-21** — 16 channels, 400–480 MHz, 0.5 / 2 W, no display, M31 platform,
CH340 cable (Kenwood 2-pin), on macOS 15.8.3 (Intel), 2026-11-14. On this unit the channel table
matched the vendor CPS 16 of 16, every settings value matched the CPS display, and a channel write
was confirmed by read-back and then restored byte for byte. Other models (ONIKS PR-20/25/27/28/61
and other brands) are covered by analogy only, without guarantees — see
`references/compatible-models.md`.

## The one safety rule

**Image first, changes second.** Every write starts with reading the whole memory and saving the
image. Rollback means writing that image back. Never touch the service area
(`0x00D0`–`0x00FF`) "just in case": calibration lives there, and a stray write can leave the
radio unusable. The channel area (`0x0000`–`0x00CF`) is the safe zone.

## Workflow

1. **Find the port.** macOS: `/dev/cu.wchusbserial*` or `/dev/cu.usbserial*`. Windows: a `COM*`
   port described as CH340. Linux: `/dev/ttyUSB*`.
2. **Read the radio and save the image.** Read twice and compare: two identical images mean a
   stable link. The image is your rollback point.
3. **Decode.** 16 channels of 13 bytes starting at `0x0000`; settings are a 13-byte block at
   `0x00D0`. Field layout: `references/memory-map.md`.
4. **Edit and write.** Only 13-byte aligned blocks. After writing, read the memory back and
   compare byte by byte.
5. **Exit and power-cycle the radio.** The exit command is mandatory, otherwise the radio stays
   in programming mode.

Working script: `scripts/pr21.py` (Python 3 + pyserial). Commands: `read`, `settings`, `set`,
`write`, `backup`, `squelch`, `poke`. It doubles as the reference implementation — port it to
another language from this script.

```
python3 -m pip install pyserial
python3 scripts/pr21.py read --out radio.img          # image + channel table
python3 scripts/pr21.py settings                      # show settings
python3 scripts/pr21.py settings --squelch 6          # change settings
python3 scripts/pr21.py set radio.img 6 --tone-rx D411N
python3 scripts/pr21.py write radio.img               # automatic backup + verification
```

## Protocol in brief

9600 8N1. Entry: `0x02` + `"CD18RAM"` → `0x06`; then `0x02` → 8-byte identifier → `0x06`.
Read: `'R'` + address (2 bytes, high byte first) + size (1) → `'W'` + address + size + data.
Write: `'W'` + address + size + data → `0x06`. Exit: `'E'`.

The key is exactly `CD18RAM`. The words `PROGRAM`, `TCOGRAM` and `PWPG970` from other radio
families are ignored by this hardware — do not waste time on them.

## Five traps that cost hours

1. **Waiting for bytes that never come.** Request a block and read more than the radio sends,
   and every iteration blocks until timeout: reading 16 channels turns into two minutes. Read
   exactly `4 + size` bytes and use 13-byte blocks — 20 requests instead of 128.
2. **Unaligned writes.** The radio rejects a single byte. Write 13-byte blocks at addresses that
   are multiples of 13.
3. **Writing past the working area.** An attempt to write outside it (for example at `0x03F6`)
   rolls back the whole session: nothing is stored, even though every block answered `0x06`.
4. **Cable still plugged into the radio.** While the plugs are inserted the radio is in
   programming mode: it does not transmit, does not beep, and the LED blinks green. That is not a
   fault. After work: exit command and a power cycle.
5. **The frame offset inside the vendor CPS.** In its code, settings "columns" are counted from
   the start of a 17-byte frame (`W` header + address + 13 data bytes), so a column number is 4
   greater than the offset within the block. Account for the shift when comparing against the CPS.

## Settings map

Block `0x00D0`, 13 bytes:

| Offset | Field | Values |
|---|---|---|
| 0 | flags | bit0 beep, bit1 battery save, bits2-3 voice (0 none, 1 Chinese, 2 English), bits4-5 spec mode, bit6 scan mode (0 Carrier, 1 Time), bit7 service |
| 1 | squelch | 0–9, where 0 is open |
| 2 | TOT | 0 = off, 1–10 = 30–300 s |
| 3 | VOX | 0 = off, 1–9 |
| 4 | VOX delay | 0–5 = 0.5–3.0 s |
| 7 | side key 1 | 0 OFF, 1 Transient monitoring, 2 Scan, 3 Voice control, 4 High/Low Power |
| 8 | side key 2 | same |

## Presets and the legal frame

Ready-made terrain sets: `assets/presets.json` and `references/presets.md`. Power is not dogma:
the user changes it freely, and the software only shows an unobtrusive warning when the selected
power exceeds the norm.

Russian regulations worth knowing before advising on power: PMR446 — EIRP at most 0.5 W, eight
channels at 446.00625 + 0.0125·n (GKRCh decision No. 05-10-02-001); LPD — 433.075–434.79 MHz,
EIRP about 20 mW (GKRCh decision No. 07-20-03-001). The PR-21 does 0.5 W on low and 2 W on high,
so on PMR the high setting exceeds the norm, and on LPD even the low setting is far above it.
Do not forbid — warn and explain.

## What to read when

- `references/protocol.md` — the protocol in full, including transfer details.
- `references/memory-map.md` — memory layout: channels, flags, settings, what is confirmed.
- `references/presets.md` — terrain presets with the evidence base and GKRCh references.
- `references/compatible-models.md` — which models may work and how to check.
- `references/troubleshooting.md` — what to do when the radio does not answer, the link drops,
  or a write does not stick.

## Do not

- Write to the service area without an explicit request and a clear understanding of the risk.
- Try to read or write beyond 256 bytes: addresses mirror there instead of holding new data.
- Promise compatibility with Baofeng, TYT, Retevis, Quansheng or DMR radios — they use other
  protocols.
- Write without an image backup, even when "only one channel" changes.

---

Русская версия: `SKILL.ru.md`. Русские справочники: `references/ru/`.
