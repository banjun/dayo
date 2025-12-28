import Foundation

public let bundle = Bundle.module

/// metallibs created by MetalCompilerPlugin
enum MetalLibFileURL {
    static let debug = bundle.url(forResource: "debug", withExtension: "metallib")
    static let `default` = bundle.url(forResource: "default", withExtension: "metallib")
}

import Metal

extension MTLDevice {
    func makeBundleDebugLibrary() -> (any MTLLibrary)? {
        MetalLibFileURL.debug.flatMap {try? makeLibrary(URL: $0)} ?? makeDefaultLibrary()
    }
    func makeBundleDefaultLibrary() -> (any MTLLibrary)? {
        MetalLibFileURL.default.flatMap {try? makeLibrary(URL: $0)} ?? makeDefaultLibrary()
    }
}
