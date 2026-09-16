import SwiftUI

private struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct PanelView: View {
    @ObservedObject var state: AppState
    @FocusState private var instructionFocused: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .fixedSize(horizontal: false, vertical: true)   // ideal height, never compressed
                .background(GeometryReader { g in
                    Color.clear.preference(key: ContentSizeKey.self, value: g.size)
                })
        }
        .frame(width: PanelController.width, alignment: .top)
        .background(VisualEffect(material: .popover, blending: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.09)))
        .tint(Theme.accent)
        .onPreferenceChange(ContentSizeKey.self) { size in
            state.panel.contentSizeChanged(size)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let banner = state.banner, state.variants.isEmpty {
                Text(banner)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            if !state.variants.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(state.variants.enumerated()), id: \.element.id) { index, variant in
                        if index > 0, index != state.selectedIndex, index - 1 != state.selectedIndex {
                            Divider().padding(.horizontal, 10).opacity(0.6)
                        }
                        VariantCard(state: state, index: index, variant: variant)
                    }
                }
                tweakBar
                bottomBar
            }
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().scaledToFit()
                .frame(width: 16, height: 16)
            Text("Grammar Llama")
                .font(.system(size: 12, weight: .semibold))
            if !state.original.isEmpty {
                Text(state.original.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            if state.isStreaming {
                ProgressView().controlSize(.mini)
            }
        }
    }

    private var tweakBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !state.tweaks.isEmpty {
                HStack(spacing: 4) {
                    ForEach(state.tweaks, id: \.self) { t in
                        HStack(spacing: 3) {
                            Text(t).font(.system(size: 11, weight: .medium))
                            Button { state.removeTweak(t) } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                TextField("Change something… e.g. more casual, drop the last line", text: $state.instruction)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($instructionFocused)
                    .onSubmit { state.submitInstruction() }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Prefs.customTweaks.filter { !state.tweaks.contains($0) }, id: \.self) { chip in
                        Button(chip) { state.applyTweak(chip) }
                            .buttonStyle(ChipStyle())
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if state.isEditing {
                KeyHint(label: "Replace", keys: "⌘↩")
                KeyHint(label: "Done", keys: "⎋")
            } else {
                KeyHint(label: "Replace", keys: "↩")
                KeyHint(label: "Copy", keys: "C")
                KeyHint(label: "Edit", keys: "E")
            }
            KeyHint(label: "Diff", keys: "D", active: state.showDiff)
            Spacer(minLength: 8)
            Button { state.copy() } label: { Text("Copy") }
                .buttonStyle(GhostStyle())
                .disabled(state.currentText.isEmpty)
            Button { state.replace() } label: { Text("Replace") }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(state.currentText.isEmpty)
        }
        .padding(.top, 2)
    }
}

struct VariantCard: View {
    @ObservedObject var state: AppState
    let index: Int
    let variant: Variant
    @FocusState private var editorFocused: Bool
    @State private var hovering = false

    private var selected: Bool { state.selectedIndex == index }
    private var editing: Bool { selected && state.isEditing }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                KeyCap(String(index + 1), active: selected)
                Text(variant.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                if variant.edited {
                    Text("edited").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer()
                if !variant.isStreaming, variant.error == nil {
                    HStack(spacing: 2) {
                        IconButton(symbol: "arrow.clockwise", help: "Regenerate") { state.regenerate(index) }
                        IconButton(symbol: editing ? "checkmark" : "pencil", help: editing ? "Done editing" : "Edit") {
                            editing ? state.endEditing() : state.beginEditing(index)
                        }
                        IconButton(symbol: "doc.on.doc", help: "Copy this variant") { state.copy(index) }
                    }
                    .opacity(selected || hovering ? 1 : 0.55)
                }
            }
            body_
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.10) : Color.primary.opacity(hovering ? 0.035 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? Theme.accent.opacity(0.55) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { state.select(index); state.beginEditing() }
        .onTapGesture { state.select(index) }
        .onHover { hovering = $0 }
        .onChange(of: editing) { _, now in editorFocused = now }
        .animation(.easeOut(duration: 0.12), value: selected)
    }

    @ViewBuilder
    private var body_: some View {
        if let error = variant.error {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(error).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Retry") { state.regenerate(index) }.controlSize(.mini)
            }
        } else if variant.text.isEmpty && variant.isStreaming {
            Shimmer()
        } else if editing {
            TextField("", text: Binding(get: { variant.text }, set: { state.setEditedText($0) }), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...30)
                .focused($editorFocused)
                .onAppear { editorFocused = true }
        } else if state.showDiff, !variant.isStreaming {
            Text(WordDiff.attributed(state.original, variant.text))
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } else {
            Text(variant.text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Small pieces

struct KeyCap: View {
    let text: String
    let active: Bool
    init(_ text: String, active: Bool = false) { self.text = text; self.active = active }
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, 4)
            .background(active ? Theme.accent : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .foregroundStyle(active ? .white : .secondary)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .frame(width: 22, height: 20)
                .background(Color.primary.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct KeyHint: View {
    let label: String
    let keys: String
    var active = false
    var body: some View {
        HStack(spacing: 4) {
            KeyCap(keys, active: active)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .fixedSize()
    }
}

struct GhostStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(Color.primary.opacity(configuration.isPressed ? 0.09 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .foregroundStyle(.secondary)
    }
}

struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

struct Shimmer: View {
    @State private var phase = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            bar(1.0); bar(0.8); bar(0.55)
        }
        .opacity(phase ? 0.35 : 0.8)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase = true }
    }
    private func bar(_ w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.12))
            .frame(height: 10).frame(maxWidth: 400 * w, alignment: .leading)
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
