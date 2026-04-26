//
//  SafariView.swift
//  Luna
//
//  Created by Gemini on 26/04/26.
//

import SwiftUI
import SafariServices

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}
#else
// Fallback for tvOS or other platforms where SFSafariViewController is not available
struct SafariView: View {
    let url: URL
    
    var body: some View {
        VStack {
            Text("Safari is not available on this platform.")
            Text(url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
#endif
