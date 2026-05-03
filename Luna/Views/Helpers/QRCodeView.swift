import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: URL
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Image(uiImage: generateQRCode(from: url))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 300, height: 300)
    }

    private func generateQRCode(from url: URL) -> UIImage {
        let data = Data(url.absoluteString.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
