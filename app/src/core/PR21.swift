import Foundation

/// Протокол ОНИКС ПР-21 (платформа M31).
/// Вход: 0x02 + "CD18RAM" -> 0x06; 0x02 -> 8 байт идентификатора; 0x06 -> 0x06.
/// Чтение: 'R' + адрес(2 BE) + размер(1) -> 'W' + адрес + размер + данные.
/// Запись: 'W' + адрес(2 BE) + размер(1) + данные -> 0x06.
/// Выход: 'E'.
struct PR21 {
    static let magic: [UInt8] = Array("CD18RAM".utf8)
    static let memorySize = 0x100
    static let blockSize = 13
    static let channelSize = 13
    static let channelCount = 16
    static let settingsAddress = 0x00D0

    let port: SerialPort

    init(path: String) throws {
        port = try SerialPort(path: path)
    }

    static func findPort() throws -> String {
        let fm = FileManager.default
        for prefix in ["/dev/cu.wchusbserial", "/dev/cu.usbserial"] {
            if let entries = try? fm.contentsOfDirectory(atPath: "/dev") {
                let found = entries.filter { $0.hasPrefix((prefix as NSString).lastPathComponent) }.sorted()
                if let first = found.first { return "/dev/" + first }
            }
        }
        throw SerialError.open("кабель не найден (/dev/cu.wchusbserial*)")
    }

    mutating func enter() throws -> [UInt8] {
        for _ in 0..<6 {
            port.flush()
            try port.write([0x02] + PR21.magic)
            let ack = try port.read(count: 1, timeout: 0.8)
            guard ack.first == 0x06 else {
                try? port.write([0x45]) // 'E'
                continue
            }
            try port.write([0x02])
            let ident = try port.read(count: 8, timeout: 1.5)
            try port.write([0x06])
            _ = try port.read(count: 1, timeout: 0.8)
            return ident
        }
        throw SerialError.timeout("рация не отвечает на вход (CD18RAM)")
    }

    mutating func readMemory() throws -> [UInt8] {
        var memory = [UInt8](repeating: 0, count: PR21.memorySize)
        var address = 0
        while address < PR21.memorySize {
            let size = min(PR21.blockSize, PR21.memorySize - address)
            port.flush()
            try port.write([0x52, UInt8(address >> 8), UInt8(address & 0xFF), UInt8(size)])
            let response = try port.read(count: 4 + size, timeout: 0.8)
            guard response.count >= 4 + size,
                  response[0] == 0x57,
                  Int(response[1]) << 8 | Int(response[2]) == address else {
                throw SerialError.io(String(format: "сбой чтения на 0x%04X", address))
            }
            for i in 0..<size { memory[address + i] = response[4 + i] }
            address += size
        }
        return memory
    }

    mutating func writeBlock(address: Int, data: [UInt8]) throws {
        port.flush()
        try port.write([0x57, UInt8(address >> 8), UInt8(address & 0xFF), UInt8(data.count)] + data)
        let ack = try port.read(count: 1, timeout: 0.8)
        guard ack.first == 0x06 else {
            throw SerialError.io(String(format: "блок 0x%04X не подтверждён", address))
        }
    }

    /// Пишет только область каналов: служебная зона не затрагивается.
    mutating func writeChannels(_ memory: [UInt8]) throws {
        let end = PR21.channelCount * PR21.channelSize
        guard memory.count >= end else {
            throw SerialError.io("образ короче области каналов: \(memory.count) из \(end)")
        }
        var address = 0
        while address < end {
            let size = min(PR21.blockSize, end - address)
            try writeBlock(address: address, data: Array(memory[address..<(address + size)]))
            address += size
        }
    }

    /// Принимает ровно один блок настроек (13 байт), а не весь образ.
    mutating func writeSettings(_ block: [UInt8]) throws {
        guard block.count == PR21.blockSize else {
            throw SerialError.io("блок настроек должен быть \(PR21.blockSize) байт, получено \(block.count)")
        }
        try writeBlock(address: PR21.settingsAddress, data: block)
    }

    func exit() {
        try? port.write([0x45])
        port.close()
    }
}
