import SwiftUI

@main
struct SevenSegApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store = AlarmStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = Appearance.system

    init() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.foregroundColor: UIColor.ink]
        bar.titleTextAttributes = [.foregroundColor: UIColor.ink]
    }

    var body: some Scene {
        WindowGroup {
            AlarmListView()
                .modifier(NightstandHost())
                .foregroundStyle(Color.ink)
                .tint(Color.ink)
                .toggleStyle(LCDToggleStyle())
                .environment(store)
                .background(VolumeHack().frame(width: 1, height: 1))
                .fullScreenCover(isPresented: .constant(store.ringing != nil)) {
                    RingingView().environment(store)
                }
                .task {
                    await store.requestAuthorization()
                    await store.observe()
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    store.scenePhaseChanged(phase)
                }
                .onChange(of: appearance, initial: true) { old, new in
                    new.apply(animated: old != new)
                }
        }
    }
}
