# Compatible models: what can theoretically work with the program

> **Warning.** **Only the ONIKS PR-21** has been tested on real hardware. Everything else in
> this list is an assumption based on documentation, specifications and design. Writing to
> another model is done **at your own risk**: settings may be lost, and in the worst
> case the radio may end up in a non-working state. Before any write, take an image and check
> that reading worked at all.

## Which features make a radio a match

The program works with a specific protocol, not with "any radio". Compatibility
is determined by four features:

1. **Kenwood 2-pin headset connector** (3.5 mm + 2.5 mm) — programming goes through it.
2. **M31-family firmware**: in the manufacturer's CPS the model name looks like
   `[M31_Analog_Redio]`, and entry into programming mode is the magic string `CD18RAM`.
3. **16 channels**, 400–480 MHz range (the CPS allows 400–520).
4. **13-byte channel record**: RX/TX 4 bytes each, two tones 2 bytes each, one flags byte.

If the radio has its own Windows CPS, the family can be checked like this: unpack
`Setup.exe` and search the executable for the string `CD18RAM`. If it is there, the protocol is the same.

## Model list

| Model | Range | Channels | Power | Programming | Status |
|---|---|---|---|---|---|
| **ONIKS PR-21** | 400–480 MHz | 16 | 0.5 / 2 W | via the headset connector | **verified** on this device |
| ONIKS PR-20 | 400–480 MHz | 16 | 0.5 / 2 W | "via a PC" | probably compatible |
| ONIKS PR-25 | 400–480 MHz | 16 | 5 W | "via a PC", wireless settings cloning | probably compatible |
| ONIKS PR-27 | 400–480 MHz | 16 | 10 W | "via a PC" | probably compatible |
| ONIKS PR-28 | 400–480 MHz | 16 | 10 W, IP67 | "via a PC" | probably compatible |
| ONIKS PR-61 | 400–480 MHz | 16 | per the brand's description | with the same programmer | probably compatible |

Basis for the "probably" rows: the same brand, the same Kenwood headset connector and the same
programmer — the manufacturer explicitly lists the ONIKS PROG P-1 for "PR-21, PR-25, PR-61 and
others with a KENWOOD-type headset connector". The overall specification line (16 channels,
400–480 MHz, 12.5/25 kHz spacing, PC programming) also matches.

**Not tested on real hardware.** Matching specifications do not guarantee an identical memory
map: on models with different power and different firmware, the service bytes and calibration
may be located differently.

## Other brands

Radios of third-party brands on the same M31 platform should theoretically work the same way — but only
if their CPS uses the same `CD18RAM` magic string and the same block format. This must be checked
before the first write:

1. Read the radio with our program in read-only mode (`read`), without writing.
2. Compare the resulting image with the expected one: 16 blocks of 13 bytes, frequencies in units of 10 Hz,
   tones in the format `0x8000 | code`.
3. Make sure the read repeats consistently (two runs produce the same image).
4. Only then write, and only after a backup.

## What is not on the list, and why

- **Baofeng, TYT, Retevis, Quansheng** — different protocols (`PROGRAM`, `PWPG970`,
  proprietary frames); our program does not support them. An attempt to write is pointless and
  potentially dangerous.
- **Digital (DMR) radios** — a different codeword format and a different CPS.
- **Models with a display and menu** in the same line have not been tested: they may have more
  settings, and the program neither touches the extra bytes of the service area nor verifies them.

## How to check your model safely

```
# 1. Read only, twice, and compare
./build/pr21cli read --out a.img
./build/pr21cli read --out b.img
cmp a.img b.img && echo "read is stable"

# 2. If the image makes sense (16 frequencies, tones), you can consider writing
./build/pr21cli show a.img
```

Writing to a model that is not on the "verified" list is entirely at your own risk. Neither the
manufacturer nor the program gives any guarantee: the protocol was recovered by reverse-engineering
the PR-21 CPS.
