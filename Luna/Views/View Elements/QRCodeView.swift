import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Scan to Export Logs")
                .font(.headline)
            
            if let image = generateQRCode(from: url.absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding()
            }
            
            Text(url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Done") {
                dismiss()
            }
            .padding(.top)
        }
        .padding(40)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
    }
    
    func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
}
