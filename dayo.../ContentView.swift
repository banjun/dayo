//
//  ContentView.swift
//  dayo...
//
//  Created by banjun on R 6/09/29.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(ImmersiveViewModel.self) private var immersiveViewModel

    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            ToggleImmersiveSpaceButton()
                .padding()

            @Bindable var immersiveViewModel = immersiveViewModel
            Toggle("SkyDome", isOn: $immersiveViewModel.showsSkyDome)
                .toggleStyle(.button)
                .padding()
            Toggle("Hands", isOn: .init(get: {immersiveViewModel.upperLimbVisibility != .hidden}, set: {immersiveViewModel.upperLimbVisibility = $0 ? .automatic : .hidden}))
                .toggleStyle(.button)
                .padding()
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
