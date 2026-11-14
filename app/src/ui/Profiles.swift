import SwiftUI
import Foundation

/// Канал внутри профиля: то, что профиль задаёт.
struct ProfileChannel: Codable, Equatable {
    var frequency: Double
    var tone: String
    var highPower: Bool
    var busyLock: Bool
    var scan: Bool
}

/// Профиль — это набор из 16 каналов плюс шумоподавление.
/// Профиль меняет частоты, тона, мощность и скан: именно за этим он и нужен.
struct Profile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var note: String
    var squelch: Int
    var channels: [ProfileChannel]

    var filled: Int { channels.filter { $0.frequency > 0 }.count }

    static func pmr(_ index: Int, tone: String, high: Bool = true, scan: Bool = false) -> ProfileChannel {
        ProfileChannel(frequency: 446.00625 + 0.0125 * Double(index), tone: tone,
                       highPower: high, busyLock: true, scan: scan)
    }

    static func lpd(_ index: Int, tone: String, high: Bool = false) -> ProfileChannel {
        ProfileChannel(frequency: 434.5 + 0.025 * Double(index), tone: tone,
                       highPower: high, busyLock: true, scan: false)
    }

    static let pmrTones = ["D074N", "D114N", "D155N", "D225N", "D306N", "D411N", "D503N", "D631N"]
    static let lpdTones = ["D047N", "D114N", "D155N", "D225N", "D306N", "D411N", "D503N"]

    /// Заводская сетка: 8 каналов PMR446 и 8 каналов LPD с теми же DCS-кодами.
    static var factory: Profile {
        var channels: [ProfileChannel] = []
        for i in 0..<8 { channels.append(pmr(i, tone: pmrTones[i])) }
        channels.append(lpd(0, tone: "D047N"))
        channels.append(lpd(1, tone: "D114N"))
        channels.append(lpd(2, tone: "D155N"))
        channels.append(lpd(3, tone: "D225N"))
        channels.append(lpd(4, tone: "D306N"))
        channels.append(lpd(5, tone: "D411N"))
        channels.append(lpd(6, tone: "D503N"))
        channels.append(ProfileChannel(frequency: 434.675, tone: "OFF", highPower: true,
                                       busyLock: false, scan: false))
        return Profile(name: "Заводской", note: "Как пришла с завода: 8 PMR446 + 8 LPD, DCS-коды по порядку",
                       squelch: 5, channels: channels)
    }

    /// PMR446 с мощностью по рельефу. Частоты — только законные восемь каналов.
    static func pmrProfile(name: String, note: String, squelch: Int, high: Bool, scan: Bool) -> Profile {
        var channels: [ProfileChannel] = []
        for i in 0..<8 { channels.append(pmr(i, tone: pmrTones[i], high: high, scan: scan)) }
        for i in 0..<7 { channels.append(lpd(i, tone: lpdTones[i])) }
        channels.append(ProfileChannel(frequency: 434.675, tone: "OFF", highPower: false,
                                       busyLock: false, scan: false))
        return Profile(name: name, note: note, squelch: squelch, channels: channels)
    }

    static var builtins: [Profile] {
        [
            factory,
            pmrProfile(name: "Горы", note: "Открытая линия, дальше важнее экономии: 2 Вт, шумодав 4",
                       squelch: 4, high: true, scan: false),
            pmrProfile(name: "Холмы", note: "Пересечёнка: 2 Вт, шумодав 6, без скана",
                       squelch: 6, high: true, scan: false),
            pmrProfile(name: "Лес и ЛЭП", note: "Кроны и помехи: 2 Вт, шумодав 7",
                       squelch: 7, high: true, scan: false),
            pmrProfile(name: "Трасса", note: "Движение рядом: 0,5 Вт, скан включён",
                       squelch: 5, high: false, scan: true),
            pmrProfile(name: "Лагерь", note: "Ближняя связь, бережём батарею: 0,5 Вт",
                       squelch: 5, high: false, scan: false),
        ]
    }
}

/// Хранилище профилей: встроенные + пользовательские, с экспортом и импортом.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var custom: [Profile] = []

    var all: [Profile] { Profile.builtins + custom }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("PR21Manager", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("profiles.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Profile].self, from: data) else { return }
        custom = list
    }

    func save() {
        guard let data = try? JSONEncoder().encode(custom) else { return }
        try? data.write(to: fileURL)
    }

    func add(_ profile: Profile) {
        custom.append(profile)
        save()
    }

    func remove(_ profile: Profile) {
        custom.removeAll { $0.id == profile.id }
        save()
    }

    func export(_ profile: Profile) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(profile.name).pr21profile.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profile) { try? data.write(to: url) }
    }

    func importProfile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              var profile = try? JSONDecoder().decode(Profile.self, from: data) else { return }
        profile.id = UUID()
        add(profile)
    }
}
