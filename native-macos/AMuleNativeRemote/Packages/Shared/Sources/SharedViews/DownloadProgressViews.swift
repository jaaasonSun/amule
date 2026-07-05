import SwiftUI

public enum DownloadProgressVisualStyle {
    public static let segmentOpacity = 0.88
    public static let rowBackgroundOpacity = 0.26
}

public struct DownloadSegmentedProgressBar: View {
    let colors: [UInt32]

    public init(colors: [UInt32]) {
        self.colors = colors
    }

    private let outerCornerRadius: CGFloat = 6
    private let innerCornerRadius: CGFloat = 4.5

    public var body: some View {
        Canvas { context, size in
            let segments = colors
            guard !segments.isEmpty else { return }
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
            opacity: DownloadProgressVisualStyle.segmentOpacity
        )
    }

}

public struct DownloadRowSegmentBackground: View {
    let colors: [UInt32]

    public init(colors: [UInt32]) {
        self.colors = colors
    }

    public var body: some View {
        Canvas { context, size in
            let segments = colors
            guard !segments.isEmpty else { return }
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

}

#if DEBUG
import SharedModels

#Preview("Segmented Progress Bar") {
    VStack(spacing: 16) {
        DownloadSegmentedProgressBar(
            colors: PreviewFixtures.downloadingDownload.progressColors
        )
        DownloadRowSegmentBackground(
            colors: PreviewFixtures.downloadingDownload.progressColors
        )
        .frame(height: 24)
    }
    .padding()
}

#Preview("Progress Bar - Empty Colors") {
    VStack(spacing: 16) {
        DownloadSegmentedProgressBar(colors: [])
        DownloadRowSegmentBackground(colors: [])
        .frame(height: 24)
    }
    .padding()
}

#Preview("Progress Bar - Complete") {
    VStack(spacing: 16) {
        DownloadSegmentedProgressBar(
            colors: PreviewFixtures.completedDownload.progressColors
        )
        DownloadRowSegmentBackground(
            colors: PreviewFixtures.completedDownload.progressColors
        )
        .frame(height: 24)
    }
    .padding()
}
#endif
