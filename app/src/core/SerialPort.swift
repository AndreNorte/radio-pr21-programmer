import Foundation

enum SerialError: Error, CustomStringConvertible {
    case open(String)
    case config
    case timeout(String)
    case io(String)

    var description: String {
        switch self {
        case .open(let p): return "не удалось открыть порт \(p)"
        case .config: return "не удалось настроить порт"
        case .timeout(let what): return "таймаут: \(what)"
        case .io(let m): return "ошибка ввода-вывода: \(m)"
        }
    }
}

/// Последовательный порт 9600 8N1 поверх POSIX: без сторонних зависимостей.
final class SerialPort {
    private var fd: Int32 = -1

    init(path: String, baud: UInt32 = 9600) throws {
        fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { throw SerialError.open(path) }

        var options = termios()
        guard tcgetattr(fd, &options) == 0 else { throw SerialError.config }
        cfmakeraw(&options)
        cfsetispeed(&options, speed_t(baud))
        cfsetospeed(&options, speed_t(baud))
        options.c_cflag |= tcflag_t(CLOCAL | CREAD)
        options.c_cflag &= ~tcflag_t(CSTOPB | PARENB | CRTSCTS)
        options.c_cflag |= tcflag_t(CS8)
        options.c_cc.16 = 0 // VMIN
        options.c_cc.17 = 0 // VTIME
        guard tcsetattr(fd, TCSANOW, &options) == 0 else { throw SerialError.config }

        // Поднять DTR и RTS: кабелю нужны обе линии
        var bits: Int32 = TIOCM_DTR | TIOCM_RTS
        _ = ioctl(fd, TIOCMBIS, &bits)
        tcflush(fd, TCIOFLUSH)
    }

    deinit { close() }

    func close() {
        guard fd >= 0 else { return }
        Darwin.close(fd)
        fd = -1
    }

    func write(_ bytes: [UInt8]) throws {
        guard fd >= 0 else { throw SerialError.io("порт закрыт") }
        var sent = 0
        let deadline = Date().addingTimeInterval(2.0)
        while sent < bytes.count {
            if Date() > deadline { throw SerialError.timeout("запись") }
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let ready = poll(&pfd, 1, 100)
            if ready <= 0 { continue }
            let n = bytes.withUnsafeBytes { raw -> Int in
                let base = raw.baseAddress!.advanced(by: sent)
                return Darwin.write(fd, base, bytes.count - sent)
            }
            if n > 0 { sent += n } else if n < 0 && errno != EAGAIN { throw SerialError.io("write errno \(errno)") }
        }
        tcdrain(fd)
    }

    /// Читает ровно `count` байт или возвращает то, что успело прийти до таймаута.
    func read(count: Int, timeout: TimeInterval) throws -> [UInt8] {
        guard fd >= 0 else { throw SerialError.io("порт закрыт") }
        var result = [UInt8]()
        let deadline = Date().addingTimeInterval(timeout)
        while result.count < count {
            let remain = deadline.timeIntervalSinceNow
            if remain <= 0 { break }
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, Int32(max(1, min(100, remain * 1000))))
            if ready <= 0 { continue }
            var buffer = [UInt8](repeating: 0, count: count - result.count)
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n > 0 {
                result.append(contentsOf: buffer.prefix(n))
            } else if n < 0 && errno != EAGAIN {
                throw SerialError.io("read errno \(errno)")
            }
        }
        return result
    }

    func flush() {
        guard fd >= 0 else { return }
        tcflush(fd, TCIOFLUSH)
    }
}
