import SwiftUI

/// Полоса профилей: готовые наборы каналов, свои профили, импорт и экспорт.
struct ProfileBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: ProfileStore

    @State private var activeID: UUID?
    @State private var showNamePrompt = false
    @State private var newName = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("ПРОФИЛИ")
                .font(.system(size: 10, weight: .medium))
                .kerning(1)
                .foregroundStyle(Theme.dim)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.all) { profile in
                        chip(profile)
                    }
                }
                .padding(.vertical, 2)
            }

            Menu {
                Button("Создать профиль из текущей рации…") {
                    newName = "Мой профиль"
                    showNamePrompt = true
                }
                Button("Импортировать профиль…") { store.importProfile() }
                if let profile = store.all.first(where: { $0.id == activeID }) {
                    Button("Экспортировать «\(profile.name)»…") { store.export(profile) }
                    if store.custom.contains(where: { $0.id == profile.id }) {
                        Button("Удалить «\(profile.name)»", role: .destructive) {
                            store.remove(profile)
                            activeID = nil
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.dim)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 28)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .alert("Название профиля", isPresented: $showNamePrompt) {
            TextField("Например: Дача", text: $newName)
            Button("Сохранить") {
                if let profile = model.captureProfile(named: newName) {
                    store.add(profile)
                    activeID = profile.id
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Профиль запомнит 16 каналов и шумоподавление текущего образа")
        }
    }

    private func chip(_ profile: Profile) -> some View {
        Button {
            model.apply(profile)
            activeID = profile.id
        } label: {
            HStack(spacing: 5) {
                if store.custom.contains(where: { $0.id == profile.id }) {
                    Image(systemName: "person.crop.circle").font(.system(size: 9))
                }
                Text(profile.name).font(.system(size: 12, weight: activeID == profile.id ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(activeID == profile.id ? Theme.accent : Theme.row, in: Capsule())
            .foregroundStyle(activeID == profile.id ? Color(hex: 0x08131A) : Theme.text)
        }
        .buttonStyle(.plain)
        .help(profile.note)
        .disabled(!model.hasImage)
    }
}
