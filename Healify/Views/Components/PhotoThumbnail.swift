import SwiftUI

/// Loads a stored wound photo thumbnail asynchronously. Uses a GeometryReader so
/// it always fills (and clips to) the caller's frame rather than the photo's own
/// aspect ratio, keeping timeline cards a uniform height.
struct PhotoThumbnail: View {
    let filename: String
    var maxPixel: CGFloat = 600
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color(.systemGray6).overlay(ProgressView())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .task(id: filename) {
            guard image == nil else { return }
            let (name, pixel) = (filename, maxPixel)
            image = await Task.detached { ImageStore.thumbnail(name, maxPixel: pixel) }.value
        }
    }
}
