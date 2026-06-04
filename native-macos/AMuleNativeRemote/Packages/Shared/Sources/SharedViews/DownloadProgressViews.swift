import SwiftUI

public struct DownloadSegmentedProgressBar: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    public init(colors: [UInt32], fallbackProgress: Double) {
        self.colors = colors
        self.fallbackProgress = fallbackProgress
    }

    private let outerCornerRadius: CGFloat = 6
    private let innerCornerRadius: CGFloat = 4.5

    private static let fallbackDoneColor = packedColor(r: 104, g: 104, b: 104)
    private static let fallbackMissingColor = packedColor(r: 255, g: 0, b: 0)

    private var renderedColors: [UInt32] {
        if !colors.isEmpty {
            return colors
        }
        let segmentCount = 48
        let safeProgress = max(0, min(fallbackProgress, 1))
        let doneSegments = Int((safeProgress * Double(segmentCount)).rounded(.down))
        return (0..<segmentCount).map {
            $0 < doneSegments ? Self.fallbackDoneColor : Self.fallbackMissingColor
        }
    }

    public var body: some View {
        Canvas { context, size in
            let segments = renderedColors
            let count = max(segments.count, 1)
            let height = max(1, size.height)

            for index in 0..<count {
                let left = floor(CGFloat(index) * size.width / CGFloat(count))
                let right = floor(CGFloat(index + 1) * size.width / CGFloat(count))
                let width = max(1, right - left)
                let rect = CGRect(x: left, y: 0, width: width, height: height)
                context.fill(
                    Path(rect),
                    with: .color(color(from: segments[min(index, segments.count - 1)]))
                )
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.75)
        }
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let saturationScale = 0.55
        let softenedRed = luma + (red - luma) * saturationScale
        let softenedGreen = luma + (green - luma) * saturationScale
        let softenedBlue = luma + (blue - luma) * saturationScale
        return Color(
            red: softenedRed,
            green: softenedGreen,
            blue: softenedBlue,
            opacity: 0.82
        )
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

public struct DownloadRowSegmentBackground: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    public init(colors: [UInt32], fallbackProgress: Double) {
        self.colors = colors
        self.fallbackProgress = fallbackProgress
    }

    private static let fallbackDoneColor = packedColor(r: 104, g: 104, b: 104)
    private static let fallbackMissingColor = packedColor(r: 255, g: 0, b: 0)

    private var renderedColors: [UInt32] {
        if !colors.isEmpty {
            return colors
        }

        let segmentCount = 64
        let safeProgress = max(0, min(fallbackProgress, 1))
        let doneSegments = Int((safeProgress * Double(segmentCount)).rounded(.down))
        return (0..<segmentCount).map {
            $0 < doneSegments ? Self.fallbackDoneColor : Self.fallbackMissingColor
        }
    }

    public var body: some View {
        Canvas { context, size in
            let segments = renderedColors
            let count = max(segments.count, 1)
            let height = max(1, size.height)

            for index in 0..<count {
                let left = floor(CGFloat(index) * size.width / CGFloat(count))
                let right = floor(CGFloat(index + 1) * size.width / CGFloat(count))
                let width = max(1, right - left)
                let rect = CGRect(x: left, y: 0, width: width, height: height)
                context.fill(
                    Path(rect),
                    with: .color(color(from: segments[min(index, segments.count - 1)]))
                )
            }
        }
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let saturationScale = 0.42
        let softenedRed = luma + (red - luma) * saturationScale
        let softenedGreen = luma + (green - luma) * saturationScale
        let softenedBlue = luma + (blue - luma) * saturationScale
        return Color(red: softenedRed, green: softenedGreen, blue: softenedBlue)
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

#if DEBUG
import SharedModels

#Preview("Segmented Progress Bar") {
    VStack(spacing: 16) {
        DownloadSegmentedProgressBar(
            colors: PreviewFixtures.downloadingDownload.progressColors,
            fallbackProgress: PreviewFixtures.downloadingDownload.progressValue / 100.0
        )
        DownloadRowSegmentBackground(
            colors: PreviewFixtures.downloadingDownload.progressColors,
            fallbackProgress: PreviewFixtures.downloadingDownload.progressValue / 100.0
        )
        .frame(height: 24)
    }
    .padding()
}

#Preview("Progress Bar - Fallback") {
    VStack(spacing: 16) {
        DownloadSegmentedProgressBar(
            colors: [],
            fallbackProgress: 0.33
        )
        DownloadRowSegmentBackground(
            colors: [],
            fallbackProgress: 0.33
        )
        .frame(height: 24)
    }
    .padding()
}

#Preview("Progress Bar - Complete") {
    VStack(spacing: 16) {
        DownloadSegmentedProgressBar(
            colors: PreviewFixtures.completedDownload.progressColors,
            fallbackProgress: 1.0
        )
        DownloadRowSegmentBackground(
            colors: PreviewFixtures.completedDownload.progressColors,
            fallbackProgress: 1.0
        )
        .frame(height: 24)
    }
    .padding()
}
#endif