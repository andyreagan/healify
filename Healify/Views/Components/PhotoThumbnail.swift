import SwiftUI

/// Loads and displays a stored wound photo thumbnail asynchronously so lists
/// and grids stay smooth.
struct PhotoThumbnail: View {
    let filename: String
    var maxPixel: CGFloat = 600
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray6))
                    .overlay(ProgressView())
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: filename) {
            if image == nil {
                let pixel = maxPixel
                let name = filename
                image = await Task.detached { ImageStore.thumbnail(name, maxPixel: pixel) }.value
            }
        }
    }
}
