# ONIKS PR-21 Protocol (M31)

Baud rate 9600 8N1. All multi-byte addresses are big-endian.

## Entering programming mode

1. `"CD18RAM"` → `0x06`
2. `0x02` → 8-byte identifier
3. `0x06` → `0x06`

The `CD18RAM` key was found in the .NET strings of `ПР-21.exe`. The radio ignores
the words `PROGRAM` and `TCOGRAM`.

## Reading a block

`'R'` + address (2 bytes BE) + size (1) → `'W'` + address + size + data

## Writing a block

`'W'` + address (2 bytes BE) + size (1) + data → `0x06`

- only aligned blocks of 13 bytes are accepted;
- the radio rejects a single byte.

## Exit

`'E'`. Without it the radio stays in programming mode: the green LED blinks,
transmit and beep do not work, and a repeated entry does not respond.

## Practical notes

- A power cycle is required after writing.
- With the plugs inserted the radio does not transmit and does not beep — this is
  programming mode, not a fault.
- A write failure at the end of memory (0x03F6) rolls back the whole session.
