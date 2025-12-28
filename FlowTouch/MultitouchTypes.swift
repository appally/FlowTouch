import Foundation

// MARK: - C Bridge
// Accessing private functions via defined symbols

@_silgen_name("MTDeviceCreateList")
func MTDeviceCreateList() -> Unmanaged<CFArray>?

@_silgen_name("MTDeviceCreateDefault")
func MTDeviceCreateDefault() -> MTDeviceRef?

@_silgen_name("MTDeviceStart")
func MTDeviceStart(_ device: MTDeviceRef, _ state: Int32)

@_silgen_name("MTDeviceStop")
func MTDeviceStop(_ device: MTDeviceRef)

@_silgen_name("MTRegisterContactFrameCallback")
func MTRegisterContactFrameCallback(_ device: MTDeviceRef, _ callback: @convention(c) (MTDeviceRef, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void)

// Opaque Types
typealias MTDeviceRef = UnsafeMutableRawPointer

// Structure mirroring the internal layout of a Touch
struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32  // Private API - values vary by macOS version, don't rely on specific values
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var unknown1: Float
    var unknown2: Float
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var unknown3: Int32
    var unknown4: Int32
    var density: Float
    var size: Float
}

struct MTVector {
    var x: Float
    var y: Float
}

// Callback signature
typealias MTContactCallback = @convention(c) (MTDeviceRef, Int32, Int32, Int32, UnsafeMutableRawPointer?, Int32) -> Void
