# aMule EC Bridge iOS In-Process Probe

This probe validates the first iOS-compatible extraction seam for the bridge:
`AMuleECBridgeCopyCapabilitiesJson()` is compiled into an iOS Simulator static
library without wxWidgets, EC socket, or aMule core dependencies. The same C API
is then invoked in-process by `CapabilitiesProbe.cpp` and decoded as the stable
capabilities JSON envelope.

Run from the repository root:

```sh
native-ios/AMuleECBridgeInProcessProbe/test-ios-capabilities.sh
```

Current path: source/static library first. XCFramework packaging should wait
until a second operation proves the required socket/core adapter surface.
