//
//  StremioConfigureView.swift
//  Luna
//
//  Created by Soupy on 2026.
//

import SwiftUI

#if !os(tvOS)
import WebKit
#endif

struct StremioConfigureView: View {
    let addon: StremioAddon
    let manager: StremioAddonManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var error: String?

    /// Derive the configure page URL, preserving the current config path.
    /// e.g. "https://torrentio.strem.fun/sort=qualitysize|..." → ".../sort=qualitysize|.../configure"
    /// If the base has no config path, falls back to "{origin}/configure".
    private var configureURL: URL? {
        var base = addon.configuredURL
        if base.hasSuffix("/") { base = String(base.dropLast()) }
        return URL(string: "\(base)/configure")
    }

    var body: some View {
        NavigationView {
            Group {
#if os(tvOS)
                tvOSFallbackView
#else
                if let error = error {
                    errorView(message: error)
                } else if let url = configureURL {
                    StremioConfigureWebView(
                        url: url,
                        isLoading: $isLoading,
                        onConfigured: { newURL in
                            applyConfiguration(newURL)
                        },
                        onError: { msg in
                            error = msg
                        }
                    )
                    .overlay {
                        if isLoading {
                            ProgressView("Loading configuration…")
                        }
                    }
                } else {
                    errorView(message: "Unable to determine configure URL for this addon.")
                }
#endif
            }
            .navigationTitle("Configure \(addon.manifest.name)")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
#endif
        }
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var tvOSFallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Configure this addon on the web, then use \"Update URL\" to paste the new URL.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let url = configureURL {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textSelection(.enabled)
            }
        }
        .padding()
    }

    private func applyConfiguration(_ newURL: String) {
        Task {
            do {
                try await manager.reconfigureAddon(addon, newURL: newURL)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - WKWebView wrapper (iOS only)

#if !os(tvOS)
struct StremioConfigureWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let onConfigured: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: StremioConfigureWebView

        init(parent: StremioConfigureWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onError(error.localizedDescription)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onError(error.localizedDescription)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let urlString = url.absoluteString

            if urlString.lowercased().hasPrefix("stremio://") {
                decisionHandler(.cancel)
                let configuredURL = extractConfiguredURL(from: urlString)
                DispatchQueue.main.async {
                    self.parent.onConfigured(configuredURL)
                }
                return
            }

            decisionHandler(.allow)
        }

        private func extractConfiguredURL(from stremioURL: String) -> String {
            var cleaned = stremioURL

            if cleaned.lowercased().hasPrefix("stremio://") {
                cleaned = "https://" + cleaned.dropFirst("stremio://".count)
            }

            if cleaned.hasSuffix("/manifest.json") {
                cleaned = String(cleaned.dropLast("/manifest.json".count))
            }

            if cleaned.hasSuffix("/") {
                cleaned = String(cleaned.dropLast())
            }

            return cleaned
        }
    }
}
#endif
