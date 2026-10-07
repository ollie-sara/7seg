import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    /// Sets every window's style, so sheets, the ringing cover and the UIKit-resolved palette all follow.
    func apply(animated: Bool) {
        let style: UIUserInterfaceStyle = switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows where window.overrideUserInterfaceStyle != style {
            // Crossfade the whole glass rather than letting each view snap on its own.
            UIView.transition(with: window, duration: animated ? 0.35 : 0, options: .transitionCrossDissolve) {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = Appearance.system

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ForEach(Appearance.allCases) { option in
                            AppearanceTile(option: option, selected: appearance == option) { appearance = option }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: appearance)
                } header: {
                    Text("Appearance").foregroundStyle(Color.ink2)
                } footer: {
                    Text("System follows the iPhone's Light and Dark setting.").foregroundStyle(Color.ink2)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)

                Section {
                    LabeledContent("Version", value: Self.version)
                } header: {
                    Text("About").foregroundStyle(Color.ink2)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)
            }
            .sheetForm()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(InkButtonStyle())
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    private static let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }()
}

/// A small piece of glass printed in that appearance's palette. System shows light and dark split on the diagonal.
private struct AppearanceTile: View {
    let option: Appearance
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 8) {
                Group {
                    switch option {
                    case .light: Glass().environment(\.colorScheme, .light)
                    case .dark: Glass().environment(\.colorScheme, .dark)
                    case .system:
                        ZStack {
                            Glass().environment(\.colorScheme, .light)
                            Glass().environment(\.colorScheme, .dark).mask(LowerTriangle())
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ink.opacity(0.16), lineWidth: 1)
                }
                .padding(4)
                .overlay {
                    if selected { RoundedRectangle(cornerRadius: 9).strokeBorder(Color.ink, lineWidth: 2) }
                }
                Legend(option.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(selected ? Color.ink : Color.ink2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The tile's glass and a ghosted "12:00" in whatever color scheme the environment sets.
private struct Glass: View {
    var body: some View {
        Color.lcd
            .overlay {
                SegmentText(text: "12:00")
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 10)
            }
            .aspectRatio(1.15, contentMode: .fit)
    }
}

private struct LowerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
