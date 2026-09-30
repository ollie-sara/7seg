import SwiftUI

@main
struct OpenAlarmApp: App {
    @State private var store = AlarmStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AlarmListView()
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
        }
    }
}
