#!/usr/bin/env python3
"""pr21 — программирование радиостанции ОНИКС ПР-21 (платформа M31) с macOS.

Протокол вскрыт на живом устройстве 14.11.2026:
  вход     "CD18RAM"  -> 0x06;  0x02 -> 8 байт идентификатора;  0x06 -> 0x06
  чтение   "R" + addr(2 байта BE) + size(1)      -> "W" + addr + size + data
  запись   "W" + addr(2 байта BE) + size(1) + data -> 0x06
  выход    "E"   (без него рация остаётся в режиме программирования)

Память 1024 байта, канал — 13 байт с адреса 0x0000:
  RX(4 LE, единицы 10 Гц) | TX(4 LE, единицы 10 Гц) | тон RX(2 LE) | тон TX(2 LE) | флаги(1)
Тон: 0x8000|код — DCS (код в восьмеричном виде: D074N = 0o74 = 60 = 0x803C),
     иначе CTCSS в десятых долях герца, 0xFFFF — выключен.

Команды:
  pr21 read  [--port P] [--out IMG] [--csv CSV]      прочитать рацию
  pr21 show  IMG                                    показать таблицу из образа
  pr21 set   IMG CH [--rx 446.00625] [--tx ...] [--tone-rx D074N] [--tone-tx OFF]
                     [--power high|low] [--busylock on|off] [--scrambler on|off]
                     [--compander on|off] [--scan-add on|off] [--flags 0x8A]
  pr21 write IMG [--yes]                            записать образ в рацию
  pr21 backup [--port P]                            снять резервную копию
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import os
import struct
import sys
from dataclasses import dataclass, field

try:
    import serial
except ImportError:
    sys.exit("нужен pyserial: ./venv312/bin/pip install pyserial")

BAUD = 9600
MAGIC = b"CD18RAM"
EXIT_CMD = b"E"
MEM_SIZE = 0x0400
CH_ADDR = 0x0000
CH_SIZE = 13
CH_COUNT = 16
DCS_FLAG = 0x8000
TONE_OFF = 0xFFFF

# Биты байта флагов. Значения выведены сравнением с таблицей штатного CPS;
# биты ширины полосы и часть служебных пока не подтверждены — меняйте осознанно.
FLAG_BITS = {
    "busylock": (0x01, True),    # 1 = Busy Lock OFF
    "power": (0x08, False),      # 1 = High, 0 = Low
    "scan_add": (0x10, True),    # 1 = Scan Add OFF
    "scrambler": (0x20, True),   # 1 = Scrambler OFF
    "compander": (0x40, True),   # 1 = Compander OFF
}


# ---------------------------------------------------------------- протокол ---
def find_port() -> str:
    """Ищет кабель: macOS — /dev/cu.*, Windows — COM* через pyserial."""
    ports = sorted(glob.glob("/dev/cu.wchusbserial*")) + sorted(glob.glob("/dev/cu.usbserial*"))
    if ports:
        return ports[0]
    try:
        from serial.tools import list_ports
        candidates = [p.device for p in list_ports.comports()
                      if any(k in (p.description or "").upper() for k in ("CH340", "CH34", "USB-SERIAL", "USB SERIAL"))
                      or (p.device or "").upper().startswith("COM")]
        if candidates:
            return sorted(candidates)[0]
    except Exception:
        pass
    sys.exit("кабель не найден: на macOS ждём /dev/cu.usbserial*, на Windows — COM-порт с CH340")


class Radio:
    def __init__(self, port: str | None = None):
        self.port = port or find_port()
        self.ser = serial.Serial(self.port, BAUD, timeout=0.8)
        self.ident = self._enter()

    def _enter(self) -> bytes:
        for _ in range(6):
            self.ser.reset_input_buffer()
            self.ser.write(MAGIC)
            self.ser.flush()
            if self.ser.read(1) == b"\x06":
                self.ser.write(b"\x02")
                self.ser.flush()
                ident = self.ser.read(8)
                self.ser.write(b"\x06")
                self.ser.flush()
                self.ser.read(1)
                return ident
            self.ser.write(EXIT_CMD)
            self.ser.flush()
        raise SystemExit("рация не отвечает на вход (CD18RAM) — включена ли она и вставлен ли кабель?")

    def read_mem(self) -> bytearray:
        """Читает память блоками по 13 байт (как CPS): 20 запросов вместо 128."""
        mem = bytearray(MEM_SIZE)
        addr = 0
        while addr < MEM_SIZE:
            blk = min(CH_SIZE, MEM_SIZE - addr)
            self.ser.reset_input_buffer()
            self.ser.write(b"R" + struct.pack(">H", addr) + bytes([blk]))
            self.ser.flush()
            resp = self.ser.read(4 + blk)
            if not resp or resp[0:1] != b"W" or resp[1:3] != struct.pack(">H", addr):
                raise SystemExit(f"сбой чтения на {addr:04x}: {resp.hex(' ') or 'пусто'}")
            mem[addr:addr + blk] = resp[4:4 + blk]
            addr += blk
        return mem

    def write_block(self, addr: int, data: bytes) -> None:
        self.ser.reset_input_buffer()
        self.ser.write(b"W" + struct.pack(">H", addr) + bytes([len(data)]) + data)
        self.ser.flush()
        ack = self.ser.read(1)
        if ack != b"\x06":
            raise SystemExit(f"блок {addr:04x} не подтверждён: {ack.hex(' ') or 'нет ответа'}")

    def write_mem(self, mem: bytes, full: bool = False) -> None:
        """Пишет блоки каналов. Служебную область (за младшими CH_COUNT*CH_SIZE байтами)
        не трогает, пока явно не попросят full=True: там калибровка и настройки,
        и именно её случайная запись может сделать рацию нерабочей."""
        end = MEM_SIZE if full else CH_COUNT * CH_SIZE
        for addr in range(0, end, CH_SIZE):
            self.write_block(addr, mem[addr:addr + CH_SIZE])

    def close(self) -> None:
        try:
            self.ser.write(EXIT_CMD)
            self.ser.flush()
        finally:
            self.ser.close()


# ------------------------------------------------------------------ каналы ---
def decode_tone(raw: int) -> str:
    if raw in (0, TONE_OFF) or raw == 0x0000:
        return "OFF"
    if raw & DCS_FLAG:
        return f"D{oct(raw & 0x7FFF)[2:].zfill(3)}N"
    return f"{raw / 10.0:.1f}"


def encode_tone(text: str) -> int:
    t = text.strip().upper()
    if t in ("OFF", "-", "0", "НЕТ"):
        return TONE_OFF
    if t.startswith("D"):                      # D074N / DCS074
        digits = "".join(c for c in t[1:] if c.isdigit())
        if not digits:
            raise ValueError(f"не разобрал DCS-код: {text}")
        return DCS_FLAG | int(digits, 8)
    return int(round(float(t.replace(",", ".")) * 10))


def decode_freq(raw: int) -> float | None:
    if raw in (0, 0xFFFFFFFF):
        return None
    return raw / 100000.0


def encode_freq(mhz: float) -> int:
    return int(round(mhz * 100000))


def flag_get(flag: int, name: str) -> str:
    bit, inverted = FLAG_BITS[name]
    on = not bool(flag & bit) if inverted else bool(flag & bit)
    return "on" if on else "off"


def flag_set(flag: int, name: str, value: str) -> int:
    bit, inverted = FLAG_BITS[name]
    want = value.strip().lower() in ("on", "1", "да", "yes", "true", "вкл", "high")
    if inverted:
        want = not want
    return (flag | bit) if want else (flag & ~bit)


@dataclass
class Channel:
    rx: float | None = None
    tx: float | None = None
    tone_rx: str = "OFF"
    tone_tx: str = "OFF"
    flags: int = 0x00

    @classmethod
    def from_bytes(cls, raw: bytes) -> "Channel":
        rx, tx, trx, ttx, flag = struct.unpack("<IIHHB", raw)
        return cls(decode_freq(rx), decode_freq(tx), decode_tone(trx), decode_tone(ttx), flag)

    def to_bytes(self) -> bytes:
        rx = encode_freq(self.rx) if self.rx else 0xFFFFFFFF
        tx = encode_freq(self.tx) if self.tx else 0xFFFFFFFF
        return struct.pack("<IIHHB", rx, tx, encode_tone(self.tone_rx),
                           encode_tone(self.tone_tx), self.flags)

    def describe_power(self) -> str:
        return "High" if flag_get(self.flags, "power") == "on" else "Low"

    def describe_busylock(self) -> str:
        return "ON" if flag_get(self.flags, "busylock") == "on" else "OFF"


def parse_image(mem: bytes) -> list[Channel]:
    return [Channel.from_bytes(mem[CH_ADDR + i * CH_SIZE:CH_ADDR + (i + 1) * CH_SIZE])
            for i in range(CH_COUNT)]


def print_table(channels: list[Channel], start: int = 1) -> None:
    print(f"{'CH':>2}  {'RX, МГц':>11}  {'TX, МГц':>11}  {'тон RX':>8}  {'тон TX':>8}  "
          f"{'мощн':>5}  {'Busy':>4}  флаги")
    print("-" * 84)
    for i, ch in enumerate(channels, start):
        rx = f"{ch.rx:.5f}" if ch.rx else "—"
        tx = f"{ch.tx:.5f}" if ch.tx else "—"
        print(f"{i:>2}  {rx:>11}  {tx:>11}  {ch.tone_rx:>8}  {ch.tone_tx:>8}  "
              f"{ch.describe_power():>5}  {ch.describe_busylock():>4}  0x{ch.flags:02x}")


def export_csv(channels: list[Channel], path: str) -> None:
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Канал", "RX, МГц", "TX, МГц", "Тон RX", "Тон TX", "Мощность", "Busy Lock", "Флаги"])
        for i, ch in enumerate(channels, 1):
            w.writerow([
                i,
                f"{ch.rx:.5f}".replace(".", ",") if ch.rx else "",
                f"{ch.tx:.5f}".replace(".", ",") if ch.tx else "",
                ch.tone_rx, ch.tone_tx, ch.describe_power(), ch.describe_busylock(),
                f"0x{ch.flags:02X}",
            ])


# -------------------------------------------------------------------- CLI ----
def cmd_read(args) -> int:
    radio = Radio(args.port)
    try:
        print(f"порт {radio.port}, идентификатор {radio.ident.hex(' ')}")
        mem = radio.read_mem()
    finally:
        radio.close()
    out = args.out or "pr21_dump.img"
    open(out, "wb").write(mem)
    channels = parse_image(mem)
    print_table(channels)
    if args.csv:
        export_csv(channels, args.csv)
        print(f"таблица: {args.csv}")
    print(f"образ: {out} ({len(mem)} байт)")
    return 0


def cmd_show(args) -> int:
    mem = open(args.image, "rb").read()
    if len(mem) < MEM_SIZE:
        sys.exit(f"образ меньше {MEM_SIZE} байт")
    print_table(parse_image(mem))
    print()
    print_settings(decode_settings(mem))
    return 0


def cmd_set(args) -> int:
    mem = bytearray(open(args.image, "rb").read())
    if len(mem) < MEM_SIZE:
        sys.exit(f"образ меньше {MEM_SIZE} байт")
    idx = args.channel - 1
    if not 0 <= idx < CH_COUNT:
        sys.exit(f"канал должен быть 1..{CH_COUNT}")
    ch = Channel.from_bytes(mem[CH_ADDR + idx * CH_SIZE:CH_ADDR + (idx + 1) * CH_SIZE])
    if args.rx is not None:
        ch.rx = args.rx
    if args.tx is not None:
        ch.tx = args.tx
    if args.rx is None and args.tx is not None and ch.rx is None:
        ch.rx = args.tx
    if args.tone_rx is not None:
        ch.tone_rx = args.tone_rx
    if args.tone_tx is not None:
        ch.tone_tx = args.tone_tx
    for name in ("power", "busylock", "scrambler", "compander", "scan_add"):
        value = getattr(args, name)
        if value is not None:
            ch.flags = flag_set(ch.flags, name, value)
    if args.flags is not None:
        ch.flags = int(args.flags, 0)
    off = CH_ADDR + idx * CH_SIZE
    mem[off:off + CH_SIZE] = ch.to_bytes()
    open(args.image, "wb").write(mem)
    print(f"канал {args.channel} в образе {args.image}:")
    print_table([ch], start=args.channel)
    return 0


def cmd_write(args) -> int:
    mem = open(args.image, "rb").read()
    if len(mem) != MEM_SIZE:
        sys.exit(f"образ должен быть ровно {MEM_SIZE} байт")
    radio = Radio(args.port)
    try:
        current = radio.read_mem()
        os.makedirs("backups", exist_ok=True)
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = os.path.join("backups", f"pr21-{stamp}.img")
        open(backup, "wb").write(current)
        print(f"резервная копия: {backup}")
        if bytes(current) == bytes(mem):
            print("образ совпадает с содержимым рации — писать нечего")
            return 0
        print_table(parse_image(mem))
        if args.full:
            print("ВНИМАНИЕ: --full пишет и служебную область памяти. Откат — write <резервная копия>.")
        if not args.yes:
            answer = input("Записать этот образ в рацию? [да/нет] ").strip().lower()
            if answer not in ("да", "yes", "y"):
                print("отменено")
                return 1
        radio.write_mem(mem, full=args.full)
    finally:
        radio.close()
    check = Radio(args.port)
    try:
        verify = check.read_mem()
    finally:
        check.close()
    if bytes(verify) == bytes(mem):
        print("записано и сверено: содержимое рации совпадает с образом")
        return 0
    diff = [i for i in range(MEM_SIZE) if verify[i] != mem[i]]
    print(f"ВНИМАНИЕ: после записи расходятся байты: {diff[:12]} (всего {len(diff)})")
    return 2


def cmd_backup(args) -> int:
    radio = Radio(args.port)
    try:
        mem = radio.read_mem()
    finally:
        radio.close()
    os.makedirs("backups", exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    path = os.path.join("backups", f"pr21-{stamp}.img")
    open(path, "wb").write(mem)
    print(f"сохранено: {path}")
    return 0



def cmd_poke(args) -> int:
    """Точечная запись одного блока в служебную область (эксперименты)."""
    radio = Radio(args.port)
    try:
        mem = radio.read_mem()
        os.makedirs("backups", exist_ok=True)
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = os.path.join("backups", f"pr21-{stamp}.img")
        open(backup, "wb").write(mem)
        print(f"резервная копия: {backup}")
        addr = int(args.address, 0)
        data = bytes(int(b, 16) for b in args.bytes)
        old = mem[addr:addr + len(data)]
        print(f"{addr:#06x}: было {old.hex(' ') or '—'} -> станет {data.hex(' ')}")
        if not args.yes:
            if input("Записать? [да/нет] ").strip().lower() not in ("да", "yes", "y"):
                print("отменено"); return 1
        radio.write_block(addr, data)
    finally:
        radio.close()
    check = Radio(args.port)
    try:
        got = check.read_mem()[addr:addr + len(data)]
    finally:
        check.close()
    print(f"после записи: {got.hex(' ')} | совпадает: {got == data}")
    print("если настройка не применилась — выключите и включите рацию")
    return 0 if got == data else 2


SETTINGS_ADDR = 0x00D0
SETTINGS_SIZE = 13
SQUELCH_OFFSET = 1   # подтверждено экспериментом 14.11: 0 = открыто, 5 = как в CPS

def cmd_squelch(args) -> int:
    """Уровень шумоподавления 0..9 (0 — открыто, слышно всё)."""
    if not 0 <= args.level <= 9:
        sys.exit("уровень 0..9")
    radio = Radio(args.port)
    try:
        mem = radio.read_mem()
        os.makedirs("backups", exist_ok=True)
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        open(os.path.join("backups", f"pr21-{stamp}.img"), "wb").write(mem)
        old = mem[SETTINGS_ADDR] >> 0
        block = bytearray(mem[SETTINGS_ADDR:SETTINGS_ADDR + SETTINGS_SIZE])
        print(f"шумоподавление: было {block[SQUELCH_OFFSET]} -> станет {args.level}")
        block[SQUELCH_OFFSET] = args.level
        radio.write_block(SETTINGS_ADDR, bytes(block))
    finally:
        radio.close()
    check = Radio(args.port)
    try:
        got = check.read_mem()[SETTINGS_ADDR + SQUELCH_OFFSET]
    finally:
        check.close()
    print(f"в рации теперь {got}" + ("" if got == args.level else " — НЕ совпало"))
    print("выключите и включите рацию, чтобы применилось")
    return 0 if got == args.level else 2


# --------------------------------------------------------------- настройки ---
# Блок настроек 0x00D0, 13 байт. Раскладка восстановлена из декомпилированного CPS
# (колонки CPS считаются от начала кадра из 17 байт: заголовок W + адрес + 13 данных).
TOT_VALUES = ["OFF"] + [str(30 * i) for i in range(1, 11)]          # 0..10
VOX_VALUES = ["OFF"] + [str(i) for i in range(1, 10)]               # 0..9
VOX_DELAY_VALUES = [f"{0.5 * (i + 1):.1f}" for i in range(6)]      # 0..5
VOICE_VALUES = ["None", "Chinese", "English"]
SPEC_VALUES = ["Spec 1", "Spec 2"]
SCAN_VALUES = ["Carrier", "Time"]
SIDE_VALUES = ["OFF", "Transient monitoring", "Scan", "Voice control", "High/Low Power"]


def _pick(values, value, what):
    v = str(value).strip()
    for i, name in enumerate(values):
        if name.lower() == v.lower():
            return i
    try:
        idx = int(v)
        if 0 <= idx < len(values):
            return idx
    except ValueError:
        pass
    raise SystemExit(f"{what}: допустимые значения {', '.join(values)}")


def decode_settings(mem: bytes) -> dict:
    b = mem[SETTINGS_ADDR:SETTINGS_ADDR + SETTINGS_SIZE]
    flags = b[0]
    return {
        "beep": bool(flags & 0x01),
        "battery_save": bool(flags & 0x02),
        "voice": VOICE_VALUES[(flags >> 2) & 0x03],
        "spec": SPEC_VALUES[(flags >> 4) & 0x03] if ((flags >> 4) & 0x03) < len(SPEC_VALUES) else "?",
        "scan_mode": SCAN_VALUES[(flags >> 6) & 0x01],
        "flag7": "ON" if (flags >> 7) & 0x01 else "OFF",
        "squelch": b[1],
        "tot": TOT_VALUES[b[2]] if b[2] < len(TOT_VALUES) else "?",
        "vox": VOX_VALUES[b[3]] if b[3] < len(VOX_VALUES) else "?",
        "vox_delay": VOX_DELAY_VALUES[b[4]] if b[4] < len(VOX_DELAY_VALUES) else "?",
        "side1": SIDE_VALUES[b[7]] if b[7] < len(SIDE_VALUES) else "?",
        "side2": SIDE_VALUES[b[8]] if b[8] < len(SIDE_VALUES) else "?",
        "raw": b.hex(" "),
    }


def print_settings(st: dict) -> None:
    print(f"шумоподавление : {st['squelch']} (0..9)")
    print(f"писк           : {'вкл' if st['beep'] else 'выкл'}")
    print(f"экономия батареи: {'вкл' if st['battery_save'] else 'выкл'}")
    print(f"голос          : {st['voice']}")
    print(f"режим скана    : {st['scan_mode']}")
    print(f"TOT            : {st['tot']} с")
    print(f"VOX            : {st['vox']}")
    print(f"задержка VOX   : {st['vox_delay']} с")
    print(f"боковая 1      : {st['side1']}")
    print(f"боковая 2      : {st['side2']}")
    print(f"spec           : {st['spec']}   служебный бит: {st['flag7']}")
    print(f"сырые байты    : {st['raw']}")


def cmd_settings(args) -> int:
    radio = Radio(args.port)
    try:
        mem = radio.read_mem()
        st = decode_settings(mem)
        changes = {}
        if args.squelch is not None:
            changes[1] = int(args.squelch)
        if args.tot is not None:
            changes[2] = _pick(TOT_VALUES, args.tot, "TOT")
        if args.vox is not None:
            changes[3] = _pick(VOX_VALUES, args.vox, "VOX")
        if args.vox_delay is not None:
            changes[4] = _pick(VOX_DELAY_VALUES, args.vox_delay, "задержка VOX")
        if args.side1 is not None:
            changes[7] = _pick(SIDE_VALUES, args.side1, "боковая 1")
        if args.side2 is not None:
            changes[8] = _pick(SIDE_VALUES, args.side2, "боковая 2")
        flags = mem[SETTINGS_ADDR]

        def setbit(mask, on):
            nonlocal flags
            flags = (flags | mask) if on else (flags & ~mask)

        if args.beep is not None:
            setbit(0x01, args.beep == "on")
        if args.battery_save is not None:
            setbit(0x02, args.battery_save == "on")
        if args.voice is not None:
            v = _pick(VOICE_VALUES, args.voice, "голос")
            flags = (flags & ~0x0C) | (v << 2)
        if args.spec is not None:
            v = _pick(SPEC_VALUES, args.spec, "spec")
            flags = (flags & ~0x30) | (v << 4)
        if args.scan_mode is not None:
            v = _pick(SCAN_VALUES, args.scan_mode, "режим скана")
            flags = (flags & ~0x40) | (v << 6)
        if args.flag7 is not None:
            setbit(0x80, args.flag7 == "on")
        if flags != mem[SETTINGS_ADDR]:
            changes[0] = flags
        if not changes:
            print_settings(st)
            st2 = st
            st2["raw"] = mem[SETTINGS_ADDR:SETTINGS_ADDR + SETTINGS_SIZE].hex(" ")
            return 0
        block = bytearray(mem[SETTINGS_ADDR:SETTINGS_ADDR + SETTINGS_SIZE])
        for col, val in changes.items():
            block[col] = val & 0xFF
        os.makedirs("backups", exist_ok=True)
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        open(os.path.join("backups", f"pr21-{stamp}.img"), "wb").write(mem)
        radio.write_block(SETTINGS_ADDR, bytes(block))
    finally:
        radio.close()
    check = Radio(args.port)
    try:
        mem2 = check.read_mem()
    finally:
        check.close()
    print("после записи:")
    print_settings(decode_settings(mem2))
    print("выключите и включите рацию, чтобы применить")
    return 0

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="pr21", description="ОНИКС ПР-21: чтение и запись каналов и настроек (macOS, Windows, Linux)")
    sub = p.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("read", help="прочитать рацию")
    r.add_argument("--port")
    r.add_argument("--out")
    r.add_argument("--csv")
    r.set_defaults(func=cmd_read)

    s = sub.add_parser("show", help="показать образ")
    s.add_argument("image")
    s.set_defaults(func=cmd_show)

    e = sub.add_parser("set", help="изменить канал в образе")
    e.add_argument("image")
    e.add_argument("channel", type=int)
    e.add_argument("--rx", type=float, help="частота приёма, МГц")
    e.add_argument("--tx", type=float, help="частота передачи, МГц")
    e.add_argument("--tone-rx", help="OFF | D074N | 67.0")
    e.add_argument("--tone-tx", help="OFF | D074N | 67.0")
    e.add_argument("--power", choices=["high", "low"])
    e.add_argument("--busylock", choices=["on", "off"])
    e.add_argument("--scrambler", choices=["on", "off"])
    e.add_argument("--compander", choices=["on", "off"])
    e.add_argument("--scan-add", choices=["on", "off"])
    e.add_argument("--flags", help="прямое значение байта флагов, например 0x8A")
    e.set_defaults(func=cmd_set)

    w = sub.add_parser("write", help="записать образ в рацию")
    w.add_argument("image")
    w.add_argument("--port")
    w.add_argument("--yes", action="store_true", help="без подтверждения")
    w.add_argument("--full", action="store_true",
                   help="писать всю память, включая служебную область (опасно)")
    w.set_defaults(func=cmd_write)

    st = sub.add_parser("settings", help="показать или изменить настройки рации")
    st.add_argument("--port")
    st.add_argument("--squelch")
    st.add_argument("--tot")
    st.add_argument("--vox")
    st.add_argument("--vox-delay", dest="vox_delay")
    st.add_argument("--voice")
    st.add_argument("--spec")
    st.add_argument("--scan-mode", dest="scan_mode")
    st.add_argument("--side1")
    st.add_argument("--side2")
    st.add_argument("--beep", choices=["on", "off"])
    st.add_argument("--battery-save", dest="battery_save", choices=["on", "off"])
    st.add_argument("--flag7", choices=["on", "off"])
    st.set_defaults(func=cmd_settings)

    q = sub.add_parser("squelch", help="уровень шумоподавления 0..9")
    q.add_argument("level", type=int)
    q.add_argument("--port")
    q.set_defaults(func=cmd_squelch)

    k = sub.add_parser("poke", help="точечная запись блока (эксперименты)")
    k.add_argument("address", help="адрес, например 0x0D1")
    k.add_argument("bytes", nargs="+", help="байты в hex")
    k.add_argument("--port")
    k.add_argument("--yes", action="store_true")
    k.set_defaults(func=cmd_poke)

    b = sub.add_parser("backup", help="резервная копия")
    b.add_argument("--port")
    b.set_defaults(func=cmd_backup)
    return p


def main() -> int:
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
