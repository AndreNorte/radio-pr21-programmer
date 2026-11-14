import Foundation

/// Тон: DCS (0x8000 | код в восьмеричной записи), CTCSS в десятых долях герца или выключен.
enum Tone: Equatable {
    case off
    case dcs(Int)        // код как число, например 74 для D074N
    case ctcss(Double)   // герцы, например 67.0

    init(raw: UInt16) {
        if raw == 0 || raw == 0xFFFF { self = .off; return }
        if raw & 0x8000 != 0 {
            self = .dcs(Int(raw & 0x7FFF))
        } else {
            self = .ctcss(Double(raw) / 10.0)
        }
    }

    var raw: UInt16 {
        switch self {
        case .off: return 0xFFFF
        case .dcs(let code): return 0x8000 | UInt16(code)
        case .ctcss(let hz): return UInt16((hz * 10).rounded())
        }
    }

    var text: String {
        switch self {
        case .off: return "OFF"
        case .dcs(let code): return String(format: "D%03oN", code)
        case .ctcss(let hz): return String(format: "%.1f", hz)
        }
    }

    /// Разбор строки: OFF, D074N или DCS074, 67.0
    static func parse(_ text: String) throws -> Tone {
        let t = text.trimmingCharacters(in: .whitespaces).uppercased()
        if t == "OFF" || t == "-" || t == "0" || t.isEmpty { return .off }
        if t.hasPrefix("D") {
            let digits = t.dropFirst().filter { $0.isNumber }
            guard let code = Int(digits, radix: 8) else { throw ToneError.bad(text) }
            return .dcs(code)
        }
        guard let hz = Double(t.replacingOccurrences(of: ",", with: ".")) else { throw ToneError.bad(text) }
        return .ctcss(hz)
    }
}

enum ToneError: Error, CustomStringConvertible {
    case bad(String)
    var description: String { "не разобрал тон" }
}

/// Флаги канала.
struct ChannelFlags {
    var raw: UInt8

    init(raw: UInt8) { self.raw = raw }

    init(busyLockOn: Bool, highPower: Bool, scanAddOn: Bool = true,
         scramblerOn: Bool = false, companderOn: Bool = true) {
        var value: UInt8 = 0
        if !busyLockOn { value |= 0x01 }
        if highPower { value |= 0x08 }
        if !scanAddOn { value |= 0x10 }
        if !scramblerOn { value |= 0x20 }
        if !companderOn { value |= 0x40 }
        self.raw = value
    }

    var busyLockOn: Bool { raw & 0x01 == 0 }
    var highPower: Bool { raw & 0x08 != 0 }
    var scanAddOn: Bool { raw & 0x10 == 0 }
    var scramblerOn: Bool { raw & 0x20 == 0 }
    var companderOn: Bool { raw & 0x40 == 0 }
}

struct Channel {
    var rx: Double?
    var tx: Double?
    var toneRX: Tone
    var toneTX: Tone
    var flags: ChannelFlags

    init(rx: Double?, tx: Double?, toneRX: Tone, toneTX: Tone, flags: ChannelFlags) {
        self.rx = rx
        self.tx = tx
        self.toneRX = toneRX
        self.toneTX = toneTX
        self.flags = flags
    }

    init(bytes: [UInt8]) {
        precondition(bytes.count == 13)
        let rxRaw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let txRaw = UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24
        rx = rxRaw == 0xFFFFFFFF ? nil : Double(rxRaw) / 100000.0
        tx = txRaw == 0xFFFFFFFF ? nil : Double(txRaw) / 100000.0
        toneRX = Tone(raw: UInt16(bytes[8]) | UInt16(bytes[9]) << 8)
        toneTX = Tone(raw: UInt16(bytes[10]) | UInt16(bytes[11]) << 8)
        flags = ChannelFlags(raw: bytes[12])
    }

    var bytes: [UInt8] {
        func freq(_ value: Double?) -> UInt32 {
            value == nil ? 0xFFFFFFFF : UInt32((value! * 100000).rounded())
        }
        let rxRaw = freq(rx), txRaw = freq(tx)
        let trx = toneRX.raw, ttx = toneTX.raw
        return [
            UInt8(rxRaw & 0xFF), UInt8(rxRaw >> 8 & 0xFF), UInt8(rxRaw >> 16 & 0xFF), UInt8(rxRaw >> 24 & 0xFF),
            UInt8(txRaw & 0xFF), UInt8(txRaw >> 8 & 0xFF), UInt8(txRaw >> 16 & 0xFF), UInt8(txRaw >> 24 & 0xFF),
            UInt8(trx & 0xFF), UInt8(trx >> 8),
            UInt8(ttx & 0xFF), UInt8(ttx >> 8),
            flags.raw
        ]
    }
}

/// Настройки рации, блок 0x00D0.
struct RadioSettings {
    static let totValues = ["OFF"] + (1...10).map { String(30 * $0) }
    static let voxValues = ["OFF"] + (1...9).map(String.init)
    static let voxDelayValues = (1...6).map { String(format: "%.1f", 0.5 * Double($0)) }
    static let voiceValues = ["None", "Chinese", "English"]
    static let specValues = ["Spec 1", "Spec 2"]
    static let scanValues = ["Carrier", "Time"]
    static let sideValues = ["OFF", "Transient monitoring", "Scan", "Voice control", "High/Low Power"]

    var beep: Bool
    var batterySave: Bool
    var voice: Int
    var spec: Int
    var scanMode: Int
    var flag7: Bool
    var squelch: Int
    var tot: Int
    var vox: Int
    var voxDelay: Int
    var side1: Int
    var side2: Int


    init(bytes: [UInt8]) {
        let f = bytes[0]
        beep = f & 0x01 != 0
        batterySave = f & 0x02 != 0
        voice = Int((f >> 2) & 0x03)
        spec = Int((f >> 4) & 0x03)
        scanMode = Int((f >> 6) & 0x01)
        flag7 = (f >> 7) & 0x01 == 1
        squelch = Int(bytes[1])
        tot = Int(bytes[2])
        vox = Int(bytes[3])
        voxDelay = Int(bytes[4])
        side1 = Int(bytes[7])
        side2 = Int(bytes[8])
    }

    var bytes: [UInt8] {
        var f: UInt8 = 0
        if beep { f |= 0x01 }
        if batterySave { f |= 0x02 }
        f |= UInt8((voice & 0x03) << 2)
        f |= UInt8((spec & 0x03) << 4)
        f |= UInt8((scanMode & 0x01) << 6)
        if flag7 { f |= 0x80 }
        return [f, UInt8(squelch), UInt8(tot), UInt8(vox), UInt8(voxDelay), 0, 0,
                UInt8(side1), UInt8(side2), 0, 0, 0, 0]
    }

    var description: String {
        let names = { (values: [String], index: Int) -> String in
            index >= 0 && index < values.count ? values[index] : "?"
        }
        return """
        шумоподавление  : \(squelch) (0..9)
        писк            : \(beep ? "вкл" : "выкл")
        экономия батареи: \(batterySave ? "вкл" : "выкл")
        голос           : \(names(RadioSettings.voiceValues, voice))
        режим скана     : \(names(RadioSettings.scanValues, scanMode))
        TOT             : \(names(RadioSettings.totValues, tot)) с
        VOX             : \(names(RadioSettings.voxValues, vox))
        задержка VOX    : \(names(RadioSettings.voxDelayValues, voxDelay)) с
        боковая 1       : \(names(RadioSettings.sideValues, side1))
        боковая 2       : \(names(RadioSettings.sideValues, side2))
        spec            : \(names(RadioSettings.specValues, spec))   служебный бит: \(flag7 ? "ON" : "OFF")
        """
    }
}

struct RadioImage {
    var bytes: [UInt8]

    var channels: [Channel] {
        (0..<PR21.channelCount).map { index in
            let start = index * PR21.channelSize
            return Channel(bytes: Array(bytes[start..<(start + PR21.channelSize)]))
        }
    }

    var settings: RadioSettings {
        RadioSettings(bytes: Array(bytes[PR21.settingsAddress..<(PR21.settingsAddress + PR21.blockSize)]))
    }
}
