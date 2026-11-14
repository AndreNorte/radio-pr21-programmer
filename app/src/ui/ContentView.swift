import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 246)
            Rectangle().fill(Theme.stroke).frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                header
                ProfileBar()
                ChannelTableView()
                writeBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle().fill(Theme.stroke).frame(width: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let index = model.selectedChannel, index < model.channels.count {
                        ChannelEditorView(index: index, channel: model.channels[index])
                            .id("\(index)-\(model.channels[index].bytes)")
                    }
                    SettingsEditorView()
                }
                .padding(14)
            }
            .frame(width: 372)
            .background(Theme.panel)
        }
        .background(Theme.window)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Каналы")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if model.hasImage {
                    Text("\(model.channels.count) каналов")
                        .font(Theme.label)
                        .foregroundStyle(Theme.dim)
                }
            }
            Text("PMR446 и LPD · запись только в область каналов")
                .font(Theme.label)
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var writeBar: some View {
        HStack(spacing: 12) {
            if model.hasUnsavedEdits {
                Circle().fill(Theme.warn).frame(width: 7, height: 7)
                Text("есть неприменённые правки").font(Theme.label).foregroundStyle(Theme.warn)
            }
            Spacer()
            Button("Прочитать заново") { model.connectAndRead() }
                .buttonStyle(.bordered)
            Button("Записать в рацию") { model.writeToRadio() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!model.hasImage)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
