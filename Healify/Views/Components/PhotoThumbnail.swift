import SwiftUI

/// Loads and displays a stored wound photo thumbnail asynchronously so lists
/// and grids stay smooth. Always fills (and clips to) the frame the caller
/// gives it, so its layout size is the frame — never the photo's own aspect
/// ratio. That keeps timeline cards a uniform height regardless of whether the
/// photo is portrait, landscape, or square.
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
            if image == nil {
                let pixel = maxPixel
                let name = filename
                image = await Task.detached { ImageStore.thumbnail(name, maxPixel: pixel) }.value
            }
        }
    }
}
