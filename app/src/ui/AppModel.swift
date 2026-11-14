import SwiftUI
import Foundation
import AppKit

/// Состояние приложения: порт, образ памяти, занятость и ошибки.
/// Работа с портом идёт в фоне, интерфейс обновляется на главном потоке.
@MainActor
final class AppModel: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case connecting
        case connected(port: String, ident: String)
        case failed(String)

        var text: String {
            switch self {
            case .disconnected: return "не подключено"
            case .connecting: return "подключение…"
            case .connected(let port, _): return "подключено · \(port)"
            case .failed(let message): return "ошибка: \(message)"
            }
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        var isBusy: Bool {
            if case .connecting = self { return true }
            return false
        }
    }

    @Published private(set) var status: Status = .disconnected
    @Published private(set) var image: RadioImage?
    @Published var selectedChannel: Int?
    @Published var hasUnsavedEdits = false
    @Published private(set) var backupURLs: [URL] = []

    var channels: [Channel] { image?.channels ?? [] }
    var settings: RadioSettings? { image?.settings }
    var hasImage: Bool { image != nil }

    /// Бэкапы живут в Application Support, а не рядом с проектом: путь не зависит от машины.
    private var backupsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("PR21Manager/backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    init() {
        reloadBackups()
    }

    // MARK: – чтение

    func connectAndRead() {
        guard !status.isBusy else { return }
        status = .connecting
        Task.detached(priority: .userInitiated) {
            do {
                let path = try PR21.findPort()
                var radio = try PR21(path: path)
                let ident = try radio.enter()
                let memory = try radio.readMemory()
                radio.exit()
                let identText = ident.map { String(format: "%02x", $0) }.joined(separator: " ")
                await MainActor.run {
                    self.image = RadioImage(bytes: memory)
                    self.status = .connected(port: path, ident: identText)
                    self.saveBackup(memory)
                }
            } catch {
                await MainActor.run {
                    self.status = .failed(String(describing: error))
                }
            }
        }
    }

    // MARK: – правка

    /// Заменяет канал в образе. В рацию ничего не пишет — только память приложения.
    func updateChannel(at index: Int, with channel: Channel) {
        guard var image, index >= 0, index < PR21.channelCount else { return }
        let start = index * PR21.channelSize
        let encoded = channel.bytes
        guard start + PR21.channelSize <= image.bytes.count else { return }
        image.bytes.replaceSubrange(start..<(start + PR21.channelSize), with: encoded)
        self.image = image
        hasUnsavedEdits = true
    }

    func updateSettings(_ settings: RadioSettings) {
        guard var image else { return }
        let start = PR21.settingsAddress
        guard start + PR21.blockSize <= image.bytes.count else { return }
        image.bytes.replaceSubrange(start..<(start + PR21.blockSize), with: settings.bytes)
        self.image = image
        hasUnsavedEdits = true
    }

    func revertEdits() {
        hasUnsavedEdits = false
        connectAndRead()
    }

    // MARK: – запись

    func writeToRadio(channelsOnly: Bool = false) {
        guard let image, !status.isBusy, case .connected = status else { return }
        status = .connecting
        Task.detached(priority: .userInitiated) {
            do {
                let path = try PR21.findPort()
                var radio = try PR21(path: path)
                _ = try radio.enter()
                let current = try radio.readMemory()
                try radio.writeChannels(image.bytes)
                if !channelsOnly {
                    try radio.writeSettings(Array(image.bytes[PR21.settingsAddress..<(PR21.settingsAddress + PR21.blockSize)]))
                }
                radio.exit()
                var check = try PR21(path: path)
                _ = try check.enter()
                let after = try check.readMemory()
                check.exit()
                let matches = Array(after.prefix(PR21.channelCount * PR21.channelSize))
                    == Array(image.bytes.prefix(PR21.channelCount * PR21.channelSize))
                await MainActor.run {
                    self.status = .connected(port: path, ident: "")
                    self.hasUnsavedEdits = false
                    self.saveBackup(current)
                    if !matches {
                        self.status = .failed("после записи образ не совпал — проверьте рацию")
                    }
                }
            } catch {
                await MainActor.run {
                    self.status = .failed(String(describing: error))
                }
            }
        }
    }

    // MARK: – профили

    /// Применяет профиль к образу: частоты, тона, мощность, busy lock, скан и шумодав.
    func apply(_ profile: Profile) {
        guard var image else { return }
        for (index, preset) in profile.channels.enumerated() where index < PR21.channelCount {
            guard preset.frequency >= 400 else { continue }
            let tone = (try? Tone.parse(preset.tone)) ?? .off
            let flags = ChannelFlags(busyLockOn: preset.busyLock, highPower: preset.highPower,
                                     scanAddOn: preset.scan, scramblerOn: false, companderOn: true)
            let channel = Channel(rx: preset.frequency, tx: preset.frequency,
                                  toneRX: tone, toneTX: tone, flags: flags)
            let start = index * PR21.channelSize
            image.bytes.replaceSubrange(start..<(start + PR21.channelSize), with: channel.bytes)
        }
        if var settings = RadioSettings(bytes: Array(image.bytes[PR21.settingsAddress..<(PR21.settingsAddress + PR21.blockSize)])) as RadioSettings? {
            settings.squelch = profile.squelch
            image.bytes.replaceSubrange(PR21.settingsAddress..<(PR21.settingsAddress + PR21.blockSize),
                                        with: settings.bytes)
        }
        self.image = image
        hasUnsavedEdits = true
    }

    /// Снимает профиль с текущего образа — чтобы сохранить свою настройку.
    func captureProfile(named name: String) -> Profile? {
        guard let image else { return nil }
        let channels = image.channels.map { channel in
            ProfileChannel(frequency: channel.rx ?? channel.tx ?? 0,
                           tone: channel.toneRX.text,
                           highPower: channel.flags.highPower,
                           busyLock: channel.flags.busyLockOn,
                           scan: channel.flags.scanAddOn)
        }
        return Profile(name: name, note: "Снят с рации \(ISO8601DateFormatter().string(from: Date()))",
                       squelch: image.settings.squelch, channels: channels)
    }

    // MARK: – файлы образов

    /// Загружает образ из файла: дальше его можно посмотреть и записать в рацию.
    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.message = "Выберите образ памяти рации (256 байт)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url), data.count >= PR21.memorySize else {
            status = .failed("файл короче 256 байт"); return
        }
        image = RadioImage(bytes: [UInt8](data.prefix(PR21.memorySize)))
        status = .connected(port: "файл", ident: url.lastPathComponent)
    }

    func saveImage() {
        guard let image else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "pr21.img"
        panel.message = "Сохранить образ памяти"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Data(image.bytes).write(to: url)
    }

    /// Сохраняет копию бэкапа в выбранное место — чтобы её можно было скачать и хранить отдельно.
    func exportBackup(_ url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        guard panel.runModal() == .OK, let target = panel.url else { return }
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.copyItem(at: url, to: target)
    }

    /// Восстанавливает образ из бэкапа в память приложения (не в рацию).
    func loadBackup(_ url: URL) {
        guard let data = try? Data(contentsOf: url), data.count >= PR21.memorySize else { return }
        image = RadioImage(bytes: [UInt8](data.prefix(PR21.memorySize)))
        hasUnsavedEdits = true
    }

    // MARK: – бэкапы

    private func saveBackup(_ memory: [UInt8]) {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = backupsDirectory.appendingPathComponent("pr21-\(stamp).img")
        try? Data(memory).write(to: url)
        reloadBackups()
    }

    func reloadBackups() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: backupsDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        backupURLs = files
            .filter { $0.pathExtension == "img" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(8)
            .map { $0 }
    }
}
