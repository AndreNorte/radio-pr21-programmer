import SwiftUI

struct ChannelTableView: View {
    @EnvironmentObject private var model: AppModel

    private let columns: [(String, CGFloat)] = [
        ("CH", 34), ("RX, МГц", 118), ("TX, МГц", 118), ("Тон", 82), ("Мощн.", 70), ("Busy", 60)
    ]

    var body: some View {
        if model.channels.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                headerRow
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(model.channels.enumerated()), id: \.offset) { index, channel in
                            row(number: index + 1, channel: channel)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.0) { title, width in
                Text(title)
                    .font(Theme.label)
                    .foregroundStyle(Theme.dim)
                    .frame(width: width, alignment: title == "CH" ? .leading : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 6)
    }

    private func row(number: Int, channel: Channel) -> some View {
        let isSelected = model.selectedChannel == number - 1
        return Button {
            model.selectedChannel = number - 1
        } label: {
            HStack(spacing: 0) {
                Text("\(number)")
                    .font(Theme.monoSmall).foregroundStyle(Theme.dim)
                    .frame(width: 34, alignment: .leading)
                Text(channel.rx.map { String(format: "%.5f", $0) } ?? "—")
                    .font(Theme.mono).foregroundStyle(Theme.text)
                    .frame(width: 118, alignment: .leading)
                Text(channel.tx.map { String(format: "%.5f", $0) } ?? "—")
                    .font(Theme.mono).foregroundStyle(Theme.text)
                    .frame(width: 118, alignment: .leading)
                Text(channel.toneRX.text)
                    .font(Theme.mono)
                    .foregroundStyle(channel.toneRX == .off ? Theme.dim : Theme.accent)
                    .frame(width: 82, alignment: .leading)
                Text(channel.flags.highPower ? "High" : "Low")
                    .font(Theme.value)
                    .foregroundStyle(channel.flags.highPower ? Theme.text : Theme.warn)
                    .frame(width: 70, alignment: .leading)
                Text(channel.flags.busyLockOn ? "ON" : "OFF")
                    .font(Theme.value)
                    .foregroundStyle(channel.flags.busyLockOn ? Theme.text : Theme.dim)
                    .frame(width: 60, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.row.opacity(0.95) : Theme.row.opacity(0.35))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 34))
                .foregroundStyle(Theme.dim)
            Text("Рация не прочитана")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.text)
            Text("Подключите кабель, включите рацию и нажмите «Прочитать»")
                .font(Theme.label)
                .foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
