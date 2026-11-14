import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showHelp = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                radioBlock

                actionButton("Прочитать", prominent: true) { model.connectAndRead() }
                    .padding(.top, 16)

                actionButton("Записать каналы", disabled: !model.hasImage) {
                    model.writeToRadio(channelsOnly: true)
                }
                actionButton("Клонировать полностью", disabled: !model.hasImage) {
                    cloneIntoRadio()
                }
                Text("«Каналы» — только сетка. «Клонировать» — сетка и настройки сразу.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
                    .padding(.bottom, 10)

                actionButton("Снять бэкап", disabled: !model.hasImage) { model.connectAndRead() }
                actionButton("Открыть образ…") { model.openImage() }
                actionButton("Сохранить образ…", disabled: !model.hasImage) { model.saveImage() }
                actionButton("Справка") { showHelp = true }

                SectionTitle(text: "Бэкапы")
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                if model.backupURLs.isEmpty {
                    Text("пока пусто").font(Theme.label).foregroundStyle(Theme.dim)
                } else {
                    ForEach(model.backupURLs, id: \.self) { url in
                        HStack(spacing: 6) {
                            Button { model.loadBackup(url) } label: {
                                Text(url.deletingPathExtension().lastPathComponent
                                    .replacingOccurrences(of: "pr21-", with: ""))
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .help("Загрузить бэкап в память приложения")

                            Button { model.exportBackup(url) } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.dim)
                            }
                            .buttonStyle(.plain)
                            .help("Сохранить бэкап в файл")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.row, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.panel)
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    private var radioBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Рация")
            Text("ПР-21").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text)

            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(model.status.text)
                    .font(Theme.label)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if case .connected(let port, _) = model.status {
                Text(port).font(Theme.monoSmall).foregroundStyle(Theme.dim)
            }
        }
    }

    private func cloneIntoRadio() {
        let alert = NSAlert()
        alert.messageText = "Записать в рацию каналы и настройки?"
        alert.informativeText = "Будет перезаписано всё: 16 каналов и блок настроек. Перед записью автоматически снимается бэкап."
        alert.addButton(withTitle: "Записать")
        alert.addButton(withTitle: "Отмена")
        if alert.runModal() == .alertFirstButtonReturn {
            model.writeToRadio(channelsOnly: false)
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .connected: return Theme.ok
        case .connecting: return Theme.warn
        case .failed: return Color(hex: 0xFF6B6B)
        case .disconnected: return Theme.dim
        }
    }

    private func actionButton(_ title: String, prominent: Bool = false,
                              disabled: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: prominent ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color(hex: 0x08131A) : Theme.text)
        .background(prominent ? Theme.accent : Theme.row, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke, lineWidth: 1))
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
        .padding(.bottom, 7)
    }
}
