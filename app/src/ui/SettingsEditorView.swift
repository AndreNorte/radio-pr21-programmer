import SwiftUI

/// Редактор настроек рации: шумодав, писк, экономия, голос, скан, TOT, VOX, боковые кнопки.
struct SettingsEditorView: View {
    @EnvironmentObject private var model: AppModel

    @State private var squelch = 5
    @State private var beep = true
    @State private var batterySave = true
    @State private var voice = 2
    @State private var scanMode = 0
    @State private var tot = 2
    @State private var vox = 5
    @State private var voxDelay = 2
    @State private var side1 = 2
    @State private var side2 = 3
    @State private var loaded = false
    @State private var openRow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ГЛОБАЛЬНЫЕ НАСТРОЙКИ РАЦИИ")
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.accent)
                Text("действуют на всю рацию, а не на отдельный канал")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Шумоподавление").font(Theme.label).foregroundStyle(Theme.dim)
                    Spacer()
                    Text("\(squelch)").font(Theme.mono).foregroundStyle(Theme.text)
                }
                Slider(value: Binding(get: { Double(squelch) },
                                      set: { squelch = Int($0.rounded()) }),
                       in: 0...9, step: 1)
                    .tint(Theme.accent)
            }

            Toggle("Писк", isOn: $beep).toggleStyle(.checkbox)
            Toggle("Экономия батареи", isOn: $batterySave).toggleStyle(.checkbox)

            picker("Голос", selection: $voice, values: RadioSettings.voiceValues)
            picker("Режим скана", selection: $scanMode, values: RadioSettings.scanValues)
            picker("TOT", selection: $tot, values: RadioSettings.totValues, suffix: " с")
            picker("VOX", selection: $vox, values: RadioSettings.voxValues)
            picker("Задержка VOX", selection: $voxDelay, values: RadioSettings.voxDelayValues, suffix: " с")
            picker("Боковая 1", selection: $side1, values: RadioSettings.sideValues)
            picker("Боковая 2", selection: $side2, values: RadioSettings.sideValues)

            Button("Применить настройки") { apply() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)
        }
        .font(Theme.label)
        .foregroundStyle(Theme.text)
        .padding(14)
        .background(Theme.row.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { loadIfNeeded() }
        .onChange(of: model.image?.bytes.count) { _ in loadIfNeeded(force: true) }
    }

    /// Свой выпадающий список: без системного Picker и NSMenu, чтобы не ловить падения.
    private func picker(_ label: String, selection: Binding<Int>, values: [String],
                        suffix: String = "") -> some View {
        HStack {
            Text(label).font(Theme.label).foregroundStyle(Theme.dim)
            Spacer(minLength: 8)
            Button {
                openRow = (openRow == label) ? nil : label
            } label: {
                HStack(spacing: 6) {
                    Text(current(values: values, index: selection.wrappedValue) + suffix)
                        .font(Theme.label)
                        .foregroundStyle(Theme.text)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: 168, alignment: .leading)
                .background(Theme.row, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .popover(isPresented: Binding(
                get: { openRow == label },
                set: { if !$0 { openRow = nil } }
            ), arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(values.indices, id: \.self) { index in
                        Button {
                            selection.wrappedValue = index
                            openRow = nil
                        } label: {
                            Text(values[index] + suffix)
                                .font(Theme.label)
                                .foregroundStyle(index == selection.wrappedValue ? Theme.accent : Theme.text)
                                .frame(minWidth: 150, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
            }
        }
    }

    /// Значение вне списка не должно ломать интерфейс: показываем прочерк и зажимаем при загрузке.
    private func current(values: [String], index: Int) -> String {
        values.indices.contains(index) ? values[index] : "—"
    }

    private func clamp(_ value: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(value, 0), count - 1)
    }

    private func loadIfNeeded(force: Bool = false) {
        guard force || !loaded, let settings = model.settings else { return }
        squelch = clamp(settings.squelch, 10)
        beep = settings.beep
        batterySave = settings.batterySave
        voice = clamp(settings.voice, RadioSettings.voiceValues.count)
        scanMode = clamp(settings.scanMode, RadioSettings.scanValues.count)
        tot = clamp(settings.tot, RadioSettings.totValues.count)
        vox = clamp(settings.vox, RadioSettings.voxValues.count)
        voxDelay = clamp(settings.voxDelay, RadioSettings.voxDelayValues.count)
        side1 = clamp(settings.side1, RadioSettings.sideValues.count)
        side2 = clamp(settings.side2, RadioSettings.sideValues.count)
        loaded = true
    }

    private func apply() {
        let settings = RadioSettings(bytes: [
            flagsByte, UInt8(squelch), UInt8(tot), UInt8(vox), UInt8(voxDelay),
            0, 0, UInt8(side1), UInt8(side2), 0, 0, 0, 0
        ])
        model.updateSettings(settings)
    }

    private var flagsByte: UInt8 {
        var value: UInt8 = 0
        if beep { value |= 0x01 }
        if batterySave { value |= 0x02 }
        value |= UInt8((voice & 0x03) << 2)
        value |= UInt8((scanMode & 0x01) << 6)
        if model.settings?.flag7 == true { value |= 0x80 }
        return value
    }
}
