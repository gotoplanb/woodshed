import SwiftUI

struct TabImageView: View {
    @Environment(StorageService.self) private var storage
    let filename: String
    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                if let url = storage.tabImageURL(for: filename),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .frame(width: geometry.size.width * scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = max(1.0, value.magnification)
                                }
                                .onEnded { value in
                                    scale = max(1.0, value.magnification)
                                }
                        )
                } else {
                    ContentUnavailableView("Image Not Found", systemImage: "photo", description: Text(filename))
                }
            }
        }
    }
}
