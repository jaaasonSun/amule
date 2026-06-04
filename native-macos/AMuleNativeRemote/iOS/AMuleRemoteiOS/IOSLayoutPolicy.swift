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
    case sidebarDetail
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
        device == .pad && horizontalSize == .regular ? .sidebarDetail : .tabView
    }

    public static func downloadsPresentation(device: IOSDeviceClass, horizontalSize: IOSHorizontalSize) -> DownloadsViewPresentation {
        rootLayout(device: device, horizontalSize: horizontalSize) == .sidebarDetail ? .pad : .phone
    }

    public static func downloadsSearchPlacement(device: IOSDeviceClass, horizontalSize: IOSHorizontalSize) -> IOSDownloadsSearchPlacement {
        rootLayout(device: device, horizontalSize: horizontalSize) == .sidebarDetail ? .toolbarSearchable : .navigationBarDrawer
    }
}
