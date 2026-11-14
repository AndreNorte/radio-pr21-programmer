# Channel presets: what is allowed, at what power, and why

Reference notes for the program. Every statement is marked as either a **regulation**
(a document with a number) or **engineering practice, not a regulation**.

## 1. Regulatory framework (Russian Federation)

### PMR446 — band 446.0–446.1 MHz

GKRCh decision No. 05-10-02-001 of 28.11.2005 (rev. 16.10.2015), appendix "Requirements for the
technical characteristics of portable radio stations" — [text](https://base.garant.ru/77698597/53f89421bbdaf741eb2d1ecc4ddb4c33/):

| Parameter | Value per the decision |
|---|---|
| EIRP, not more than | **0.5 W** |
| Maximum deviation | 2.5 kHz |
| Emission class | 12K5F3E (narrowband FM) |
| Channel spacing | 12.5 kHz |
| Frequency values | 446.00625 + 0.0125·n, **n = 0…7 — 8 channels in total** |
| Antenna | integrated |

Practical conclusion: in Russia this band permits **eight** channels
(446.00625 / 446.01875 / 446.03125 / 446.04375 / 446.05625 / 446.06875 / 446.08125 /
446.09375 MHz) and **half power**. The European 16-channel grid
(446.0–446.2 MHz) is not covered by the decision in the Russian Federation.

### LPD — band 433.075–434.79 MHz

GKRCh decision No. 07-20-03-001 of 07.05.2007 (rev. 27.09.2023), appendix 1
"Non-specialised devices" — [text](https://meganorm.ru/mega_doc/dop_norm_update_01032025/gost_r_71779-2024_natsionalnyy_standart_rossiyskoy/0/reshenie_gkrch_pri_mininformsvyazi_rossii_ot_07_05_2007_N.html):

| Parameter | Value per the decision |
|---|---|
| Band | 433.075–434.79 MHz |
| EIRP, not more than | **−17 dBW, that is about 20 mW** |
| Condition | "use by low-power radio stations is permitted" |
| Validity of the decision | until 01.05.2027 |

### What this means for the ONIKS PR-21

The radio's data sheet: 0.5 / 2 W (Low / High). It follows directly that:

- **PMR446:** Low (0.5 W) fits within the regulation, **High (2 W) is a fourfold excess**
  (6 dB). The regulation does not permit operating on High in this band.
- **LPD:** even Low (0.5 W) is 25 times above the permitted ~20 mW. This radio physically
  cannot operate within the LPD regulation; channels 9–15 from the factory firmware are
  outside the regulation.

Power is **not imposed** by the program: a preset sets a value that is reasonable for its own
conditions, but it can be changed in one click. If 2 W (High) is selected on a PMR446 channel,
the interface shows an **unobtrusive note**: "2 W — above the PMR446 regulation (0.5 W)".
This is a warning, not a prohibition: the decision remains with the owner.

## 2. Physics: why terrain matters more than power

Raising power from 0.5 to 2 W gives +6 dB. That is roughly a twofold gain in
range over open terrain — but it is cancelled by a single tree or a fold in the terrain,
which cost tens of dB in loss. Hence the rule: **antenna height and position first,
then power, and only then squelch**.

Reference points (engineering practice, not a regulation):

| Condition | What happens at 446 MHz | Typical range at 0.5 W |
|---|---|---|
| Open terrain, mutual line of sight | almost free-space propagation | 2–5 km, more on ridges |
| Hills, broken ground | diffraction over ridges, 10–30 dB loss per obstacle | 1–3 km if there is at least partial line of sight |
| Forest | absorption in canopy and trunks, about 0.2–0.5 dB/m in foliage | 300–800 m |
| Road, cars | multipath, interference from vehicles | 0.5–2 km, strongly dependent on antenna height |
| Foothills near power lines | impulsive noise and harmonics | limited by noise, not by range |

Sources on propagation: ITU-R P.833 (attenuation in vegetation),
ITU-R P.526 (diffraction), ITU-R P.1546 (point-to-area terrestrial propagation).
The numbers in the table are an engineering estimate based on these models and on practice,
**not quotations from regulations**.

## 3. Presets

All presets use the eight Russian PMR446 channels; power is chosen according to conditions (see the table) and can be changed freely.
They differ in channel (to avoid crowding the air), DCS code, squelch and scan.

| Preset | Channel | Frequency, MHz | Tone | Power | Squelch | Scan | When to use |
|---|---|---|---|---|---|---|---|
| **Mountains, open line** | 1 | 446.00625 | D074N | High | 4 | off | ridge, valley in line of sight: range matters more than saving |
| **Hills, broken ground** | 6 | 446.06875 | D411N | High | 6 | off | your working channel: ridges, partial line of sight |
| **Forest, foothills near power lines** | 8 | 446.09375 | D631N | High | 7 | off | canopy and interference: headroom in both power and squelch |
| **Road, highway** | 3 | 446.03125 | D155N | Low | 5 | on | traffic nearby, communication at 0.5–2 km |
| **Camp, power-saving** | 2 | 446.01875 | D114N | Low | 5 | off | close range, saving the battery |
| **LPD, short range** | 9 | 434.50000 | D047N | Low | 5 | off | 200–500 m; outside the LPD regulation for EIRP |

### Why these squelch settings

- Open terrain: the noise floor is low, so squelch 4 keeps the radio from "muting" on a weak signal.
- In mountains and forest, High power gives +6 dB — a gain in range, but no substitute for
  antenna height; the regulation warning stays visible while High is selected.
- Hills: 6 is a compromise between range and false openings.
- Forest and power lines: 7 — otherwise the radio opens on impulsive noise; you have heard that in practice.
- Road: 5 plus scan, to catch other road users.

### Why DCS and not CTCSS

The DCS codes (D074N and so on) are already programmed in the radio and verified in a pair. CTCSS works the same way,
but there is no need to change a scheme without reason: both ends must match, and in your case DCS matches.
A preset changes only what is needed and does not break communication with the second radio.

### A limitation to keep in mind

The bandwidth setting (Wide/Narrow) has not yet been found in this radio's protocol — the bit is unconfirmed.
Therefore "narrow band" is not yet set in the presets: channels remain Wide.
This is the next item in the mapping work (see `docs/plan.md`, stage 1).

## 4. Sources

1. GKRCh decision No. 05-10-02-001 of 28.11.2005 (rev. 16.10.2015), appendix: EIRP ≤ 0.5 W,
   deviation 2.5 kHz, 12.5 kHz spacing, 8 channels at 446.00625 + 0.0125n, integrated antenna.
   https://base.garant.ru/77698597/
2. GKRCh decision No. 07-20-03-001 of 07.05.2007 (rev. 27.09.2023), appendix 1:
   433.075–434.79 MHz, EIRP ≤ −17 dBW (≈20 mW), low-power radio stations; valid until 01.05.2027.
   https://meganorm.ru/mega_doc/dop_norm_update_01032025/gost_r_71779-2024_natsionalnyy_standart_rossiyskoy/0/reshenie_gkrch_pri_mininformsvyazi_rossii_ot_07_05_2007_N.html
3. ITU-R P.833 — attenuation of radio waves in vegetation.
4. ITU-R P.526 — propagation by diffraction.
5. ITU-R P.1546 — prediction methods for point-to-area terrestrial propagation.
6. ONIKS PR-21 radio description: 400–480 MHz range, 0.5 / 2 W power.
   https://oniks-radio.ru/catalog/racii/portativnye_radiostancii/racii_oniks/oniks-pr-21

All external statements were verified on 14.11.2026. A legal assessment of radio use is
outside the scope of this reference: the regulations are cited here as a basis for choosing
settings, not as a legal opinion.
