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
    @State private var tvOSConfiguredURL = ""

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
        Form {
            Section("Web Configuration") {
                Image(systemName: "safari")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Text("Configure this addon on the web, then paste the updated configured URL below to save it on Apple TV.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let url = configureURL {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Section("Configured URL") {
                TextField("Configured addon URL", text: $tvOSConfiguredURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button("Save URL") {
                    applyConfiguration(tvOSConfiguredURL)
                }
                .disabled(tvOSConfiguredURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if tvOSConfiguredURL.isEmpty {
                tvOSConfiguredURL = addon.configuredURL
            }
        }
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

        // Inject JS to intercept stremio:// links and window.location assignments
        let js = """
        (function() {
            // Intercept link clicks
            document.addEventListener('click', function(e) {
                var target = e.target;
                while (target && target.tagName !== 'A') { target = target.parentElement; }
                if (target && target.href && target.href.toLowerCase().startsWith('stremio://')) {
                    e.preventDefault();
                    e.stopPropagation();
                    window.webkit.messageHandlers.stremioInstall.postMessage(target.href);
                }
            }, true);
            // Intercept window.location changes
            var origAssign = window.location.assign;
            window.location.assign = function(url) {
                if (typeof url === 'string' && url.toLowerCase().startsWith('stremio://')) {
                    window.webkit.messageHandlers.stremioInstall.postMessage(url);
                    return;
                }
                origAssign.call(window.location, url);
            };
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "stremioInstall")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: StremioConfigureWebView

        init(parent: StremioConfigureWebView) {
            self.parent = parent
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "stremioInstall", let urlString = message.body as? String {
                let configuredURL = extractConfiguredURL(from: urlString)
                DispatchQueue.main.async {
                    self.parent.onConfigured(configuredURL)
                }
            }
        }

        // MARK: - WKNavigationDelegate

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
