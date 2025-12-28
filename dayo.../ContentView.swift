//
//  ContentView.swift
//  dayo...
//
//  Created by banjun on R 6/09/29.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersionStylePicker: View {
    @Binding var immersionStyle: ImmersionStyle
    var body: some View {
        Picker("Immersion Style", selection: .init(get: {
            switch immersionStyle {
            case is MixedImmersionStyle: "Mixed"
            case is ProgressiveImmersionStyle: "Progressive"
            case is FullImmersionStyle: "Full"
            default: fatalError()
            }
        }, set: {
            immersionStyle = switch $0 {
            case "Mixed": .mixed
            case "Progressive": .progressive
            case "Full": .full
            default: .mixed
            }
        })) {
            Text("Mixed").tag("Mixed")
            Text("Progressive").tag("Progressive")
            Text("Full").tag("Full")
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(ImmersiveViewModel.self) private var immersiveViewModel

    var body: some View {
        VStack {
            @Bindable var model = model
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            ToggleImmersiveSpaceButton()
                .padding()
            ImmersionStylePicker(immersionStyle: $model.immersionStyle)

            @Bindable var immersiveViewModel = immersiveViewModel
            Toggle("SkyDome", isOn: $immersiveViewModel.showsSkyDome)
                .toggleStyle(.button)
                .padding()
            Toggle("Hands", isOn: .init(get: {immersiveViewModel.upperLimbVisibility != .hidden}, set: {immersiveViewModel.upperLimbVisibility = $0 ? .automatic : .hidden}))
                .toggleStyle(.button)
                .padding()
            Toggle("Bloom", isOn: $immersiveViewModel.addsBloom)
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
