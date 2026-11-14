import SwiftUI

/// Редактор одного канала: частота, тон, мощность, busy lock, скан.
struct ChannelEditorView: View {
    @EnvironmentObject private var model: AppModel
    let index: Int
    let channel: Channel

    @State private var rx = ""
    @State private var tx = ""
    @State private var toneRX = ""
    @State private var toneTX = ""
    @State private var highPower = true
    @State private var busyLock = true
    @State private var scanAdd = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Канал \(index + 1)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("#\(String(format: "%02X", index * PR21.channelSize))")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.dim)
            }

            field("RX, МГц", text: $rx, hint: "446.06875")
            HStack(spacing: 6) {
                field("TX, МГц", text: $tx, hint: "как RX")
                smallButton("= RX") { tx = rx }
            }
            HStack(spacing: 6) {
                field("Тон RX", text: $toneRX, hint: "D411N, 67.0 или OFF")
                smallButton("= RX") {
                    toneTX = toneRX
                }
            }
            field("Тон TX", text: $toneTX, hint: "D411N, 67.0 или OFF")

            HStack(spacing: 10) {
                Toggle("High 2 Вт", isOn: $highPower)
                Toggle("Busy lock", isOn: $busyLock)
                Toggle("Скан", isOn: $scanAdd)
            }
            .toggleStyle(.checkbox)
            .font(Theme.label)
            .foregroundStyle(Theme.text)

            if highPower && isPMR {
                Text("2 Вт — выше нормы PMR446 (0,5 Вт). Предупреждение, не запрет.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.warn)
            }

            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button("Применить") { apply() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                Button("Сбросить") { load() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Theme.row.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { load() }
        .onChange(of: channel.bytes) { _ in load() }
    }

    private var isPMR: Bool {
        guard let value = Double(rx) else { return false }
        return (446.0...446.1).contains(value)
    }

    private func field(_ label: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(Theme.label).foregroundStyle(Theme.dim)
            TextField(hint, text: text)
                .textFieldStyle(.roundedBorder)
                .font(Theme.mono)
        }
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 11))
            .padding(.top, 14)
    }

    private func load() {
        rx = channel.rx.map { String(format: "%.5f", $0) } ?? ""
        tx = channel.tx.map { String(format: "%.5f", $0) } ?? ""
        toneRX = channel.toneRX.text
        toneTX = channel.toneTX.text
        highPower = channel.flags.highPower
        busyLock = channel.flags.busyLockOn
        scanAdd = channel.flags.scanAddOn
        error = nil
    }

    private func apply() {
        error = nil
        guard let rxValue = Double(rx.replacingOccurrences(of: ",", with: ".")) else {
            error = "не понял частоту RX"; return
        }
        let txValue = tx.isEmpty ? rxValue
            : Double(tx.replacingOccurrences(of: ",", with: "."))
        guard let txValue else { error = "не понял частоту TX"; return }
        guard (400...520).contains(rxValue), (400...520).contains(txValue) else {
            error = "частота вне диапазона 400–520 МГц"; return
        }
        do {
            let tRX = try Tone.parse(toneRX)
            let tTX = try Tone.parse(toneTX)
            let flags = ChannelFlags(busyLockOn: busyLock, highPower: highPower,
                                     scanAddOn: scanAdd,
                                     scramblerOn: channel.flags.scramblerOn,
                                     companderOn: channel.flags.companderOn)
            let updated = Channel(rx: rxValue, tx: txValue, toneRX: tRX, toneTX: tTX, flags: flags)
            model.updateChannel(at: index, with: updated)
        } catch {
            self.error = "не понял тон: \(toneRX) / \(toneTX)"
        }
    }
}
