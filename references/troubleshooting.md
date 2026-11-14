# If the Radio Does Not Respond

Diagnostics proceeds from simple to complex. Do not try protocol variants until you have checked the physical layer.

## 1. Does the port exist at all?

- macOS: `ls /dev/cu.usb* /dev/cu.wch*`. If empty, the cable is not recognized. The CH340
  driver on macOS 15 is built in (`AppleUSBCHCOM`), nothing needs to be installed. If you did install
  the WCH driver, the port may be named `/dev/cu.wchusbserial*` — that is normal.
- Windows: Device Manager → "Ports (COM and LPT)". No device — no CH340 driver.
- Linux: `ls /dev/ttyUSB*`, the user must be in the `dialout` group.

## 2. Is the cable in the radio, is the radio on?

While the plugs are inserted, the radio is in programming mode: **it does not transmit, does not beep, the LED blinks
green**. If the user complains that "the radio stopped working", first ask whether the cable is unplugged,
and request a power cycle.

## 3. No response to `CD18RAM`

Check in order:

1. Baud rate 9600, 8N1 — the radio will not understand anything else.
2. `0x02` is sent, then the string `CD18RAM`, and only then the response is read.
3. The port is not busy with another process (a browser with WebUSB, an old copy of the program).
4. Repeat the entry 5–6 times: after a failed write the radio may remain in an intermediate
   state. Before retrying, send `'E'`.
5. If there is still silence after that — unplug the plugs, turn the radio off, turn it on again, insert
   the plugs, retry.

## 4. Reading works, but very slowly

Classic case: you requested 8 bytes but read 20 — the driver waits for nonexistent bytes until timeout.
Read exactly `4 + size`, in blocks of 13 bytes.

## 5. The write "succeeded", but nothing changed

Verify by reading. Possible causes:

- the write used an unaligned block (the radio accepts only 13 bytes from an address that is a multiple of 13);
- the tail of memory was touched (around `0x03F6`) — in this case the session is rolled back entirely;
- the exit `'E'` was not sent and no power cycle was done, so the settings were not applied.

## 6. The radio responds, but the values are absurd

Check against the memory map: frequencies are in units of 10 Hz, the tone is `0x8000 | code` for DCS, `0xFFFF` for
a disabled tone. The most common mistake is reading a tone as decimal CTCSS when it is an
octal DCS code.

## 7. The user is afraid of "bricking" the radio

That is reasonable, and it must be respected. What to say, factually: the working channel area is separated from
the service area, we have an image for rollback, and the protocol does not touch the bootloader. The danger
comes only from writing to the service area and from losing the backup copy, therefore: image before
writing, verification after, rollback with one command.

## 8. What will not help

- Trying baud rates 2400…115200: only 9600 works.
- Trying "magic" words `PROGRAM`, `TCOGRAM`, `PWPG970` and ASCII keys: this platform has
  only one key — `CD18RAM`.
- Installing the WCH driver "just in case": the built-in one is enough.
- Shorting the plugs to test a loopback: the cable pinout is unknown, the test will prove nothing.
