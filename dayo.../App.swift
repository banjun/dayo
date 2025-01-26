import SwiftUI

@main
struct App: SwiftUI.App {

    @State private var appModel = AppModel()
    @State private var immersiveViewModel = ImmersiveViewModel()
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(immersiveViewModel)
                .task {
                    await openImmersiveSpace(id: appModel.immersiveSpaceID)
                }
        }
        .windowResizability(.contentSize)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(immersiveViewModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
