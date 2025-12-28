import SwiftUI

@main
struct App: SwiftUI.App {
    @State private var appModel = AppModel()
    @State private var immersiveViewModel: ImmersiveViewModel?
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some SwiftUI.Scene {
        WindowGroup {
            if let immersiveViewModel {
                ContentView()
                    .environment(appModel)
                    .environment(immersiveViewModel)
                    .task {
                        await openImmersiveSpace(id: appModel.immersiveSpaceID)
                    }
            } else {
                ProgressView().task {
                    immersiveViewModel = await .init()
                }
            }
        }
        .windowResizability(.contentSize)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            if let immersiveViewModel {
                ImmersiveView()
                    .environment(appModel)
                    .environment(immersiveViewModel)
                    .onAppear {
                        appModel.immersiveSpaceState = .open
                    }
                    .onDisappear {
                        appModel.immersiveSpaceState = .closed
                    }
            } else {
                ProgressView().task {
                    immersiveViewModel = await .init()
                }
            }
        }
        .immersionStyle(selection: $appModel.immersionStyle, in: .mixed, .progressive, .full)
     }
}
