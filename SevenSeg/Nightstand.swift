import SwiftUI

/// Bedside-clock mode: landscape, charging, and at least one enabled alarm. Tap to leave until the phone
/// turns back to portrait or is unplugged. Landscape is only allowed while the mode is possible.
struct NightstandHost: ViewModifier {
    @Environment(AlarmStore.self) private var store
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var charging = Self.isCharging
    @State private var dismissed = false

    func body(content: Content) -> some View {
        let eligible = charging && store.alarms.contains(where: \.enabled)
        content
            .overlay {
                if eligible && verticalSizeClass == .compact && !dismissed && store.ringing == nil {
                    NightstandView()
                        .onTapGesture { dismissed = true }
                        .accessibilityAction(named: "Leave nightstand mode") { dismissed = true }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
                charging = Self.isCharging
                if !charging { dismissed = false }
            }
            .onChange(of: verticalSizeClass) { _, size in
                if size != .compact { dismissed = false }
            }
            .onChange(of: eligible, initial: true) { _, on in
                AppDelegate.allowLandscape(on)
            }
    }

    private static var isCharging: Bool {
        #if targetEnvironment(simulator)
        return true // The simulator reports no battery state.
        #else
        UIDevice.current.isBatteryMonitoringEnabled = true
        return [.charging, .full].contains(UIDevice.current.batteryState)
        #endif
    }
}

/// Pure black, dim red digits, no ghost segments, minimum brightness. Shifts a little each minute against OLED burn-in.
private struct NightstandView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var savedBrightness: CGFloat?

    private static let drift: [CGSize] = [
        .zero, CGSize(width: 10, height: -6), CGSize(width: -8, height: 8), CGSize(width: 6, height: 10),
        CGSize(width: -10, height: -8), CGSize(width: 12, height: 4), CGSize(width: -4, height: -10), CGSize(width: -12, height: 2),
    ]

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 12) {
                if let next = store.nextRing(after: context.date) {
                    Legend("AL \(Segments.label(next.date))")
                        .accessibilityLabel("Next alarm \(next.date.formatted(date: .omitted, time: .shortened))")
                }
                SegmentClock(context.date, ghost: false)
                    .frame(maxHeight: 220)
            }
            .padding(.horizontal, 60)
            .offset(Self.drift[Calendar.current.component(.minute, from: context.date) % Self.drift.count])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Color.nightRed)
        .background(.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { dim(true) }
        .onDisappear { dim(false) }
        .onChange(of: scenePhase) { _, phase in dim(phase == .active) }
    }

    private func dim(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
        guard let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen else { return }
        if on, savedBrightness == nil {
            savedBrightness = screen.brightness
            screen.brightness = 0
        } else if !on, let saved = savedBrightness {
            screen.brightness = saved
            savedBrightness = nil
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private static var orientations = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientations
    }

    static func allowLandscape(_ allow: Bool) {
        orientations = allow ? .allButUpsideDown : .portrait
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            if !allow { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
    }
}
