import Foundation

public enum IOSDeviceClass: Sendable {
    case phone
    case pad
}

public enum IOSHorizontalSize: Sendable {
    case compact
    case regular
}

public enum IOSRootLayout: Sendable, Equatable {
    case tabView
}

public enum DownloadsViewPresentation: Sendable, Equatable {
    case phone
    case pad
}

public enum IOSDownloadsSearchPlacement: Sendable, Equatable {
    case navigationBarDrawer
    case toolbarSearchable
}

public enum IOSLayoutPolicy {
    public static func rootLayout(device: IOSDeviceClass, horizontalSize: IOSHorizontalSize) -> IOSRootLayout {
        .tabView
    }

    public static func downloadsPresentation(device: IOSDeviceClass, horizontalSize: IOSHorizontalSize) -> DownloadsViewPresentation {
        device == .pad && horizontalSize == .regular ? .pad : .phone
    }

    public static func downloadsSearchPlacement(device: IOSDeviceClass, horizontalSize: IOSHorizontalSize) -> IOSDownloadsSearchPlacement {
        device == .pad && horizontalSize == .regular ? .toolbarSearchable : .navigationBarDrawer
    }
}
