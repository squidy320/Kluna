//
//  TrackersSettingsView.swift
//  Luna
//
//  Created by Soupy-dev
//

import SwiftUI
import Kingfisher

struct TrackersSettingsView: View {
    @StateObject private var trackerManager = TrackerManager.shared
    @State private var selectedTracker: TrackerService?
    @State private var showImportConfirmation = false
    @State private var showingTVAuthSheet = false
    @State private var tvAuthInput = ""

    @State private var scrollOffset: CGFloat = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trackers")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    // Sync Toggle
                    Toggle("Enable Sync", isOn: $trackerManager.trackerState.syncEnabled)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)

                    // AniList Section
                    trackerRow(
                        service: .anilist,
                        isConnected: trackerManager.trackerState.getAccount(for: .anilist) != nil,
                        username: trackerManager.trackerState.getAccount(for: .anilist)?.username,
                        onConnect: { beginTrackerLogin(.anilist) },
                        onDisconnect: { trackerManager.disconnectTracker(.anilist) }
                    )

                    // AniList Import Section
                    if trackerManager.trackerState.getAccount(for: .anilist) != nil {
                        aniListImportSection
                    }

                    // Trakt Section
                    trackerRow(
                        service: .trakt,
                        isConnected: trackerManager.trackerState.getAccount(for: .trakt) != nil,
                        username: trackerManager.trackerState.getAccount(for: .trakt)?.username,
                        onConnect: { beginTrackerLogin(.trakt) },
                        onDisconnect: { trackerManager.disconnectTracker(.trakt) }
                    )
                }
                .padding(.horizontal)

                if let error = trackerManager.authError {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
            .frame(maxWidth: isIPad ? 700 : .infinity)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: -geo.frame(in: .named("trackersScroll")).origin.y
                    )
                }
            )
        }
        .coordinateSpace(name: "trackersScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollOffset = $0 }
        .background(SettingsGradientBackground(scrollOffset: scrollOffset).ignoresSafeArea())
        .navigationTitle("Trackers")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Import AniList Library", isPresented: $showImportConfirmation) {
            Button("Import", role: .none) {
                trackerManager.importAniListToLibrary()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will import your AniList Watching, Planning, and Completed lists as collections in your library. Existing items won't be duplicated.")
        }
#if os(tvOS)
        .sheet(isPresented: $showingTVAuthSheet) {
            tvAuthSheet
        }
#endif
    }

    // MARK: - AniList Import Section

    @ViewBuilder
    private var aniListImportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import AniList Library")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Import your Watching, Planning, and Completed lists as collections")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if trackerManager.isImportingAniList {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Button(action: { showImportConfirmation = true }) {
                        Text("Import")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                }
            }

            if let progress = trackerManager.aniListImportProgress {
                Text(progress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = trackerManager.aniListImportError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func trackerRow(
        service: TrackerService,
        isConnected: Bool,
        username: String?,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let logoURL = service.logoURL {
                    KFImage(logoURL)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.displayName)
                        .font(.headline)
                        .foregroundColor(.white)

                    if let username = username {
                        Text(username)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        Button(action: onDisconnect) {
                            Text("Disconnect")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    Button(action: onConnect) {
                        Text("Connect")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func beginTrackerLogin(_ service: TrackerService) {
        Logger.shared.log("TrackersSettingsView: Begin login for \(service.rawValue)", type: "Tracker")
#if os(tvOS)
        Logger.shared.log("TrackersSettingsView: Using tvOS auth flow for \(service.rawValue)", type: "Tracker")
        selectedTracker = service
        tvAuthInput = ""
        trackerManager.authError = nil
        trackerManager.isAuthenticating = false
        showingTVAuthSheet = true
#else
        switch service {
        case .anilist:
            Logger.shared.log("TrackersSettingsView: Using standard AniList auth flow", type: "Tracker")
            trackerManager.startAniListAuth()
        case .trakt:
            Logger.shared.log("TrackersSettingsView: Using standard Trakt auth flow", type: "Tracker")
            trackerManager.startTraktAuth()
        }
#endif
    }

#if os(tvOS)
    @ViewBuilder
    private var tvAuthSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(selectedTracker?.displayName ?? "Tracker Login")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)

                    Text(tvAuthInstructions)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    if let authURL = currentTVAuthURL {
                        Button {
                            openURL(authURL)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .font(.system(size: 22, weight: .semibold))
                                Text("Open Login Page")
                                    .font(.system(size: 24, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 64)
                            .applyLiquidGlassBackground(cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paste Callback URL or Code")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)

                        TextField("luna://... or authorization code", text: $tvAuthInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 22, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 18)
                            .frame(minHeight: 66)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    HStack(spacing: 16) {
                        Button("Cancel") {
                            showingTVAuthSheet = false
                            selectedTracker = nil
                            tvAuthInput = ""
                        }
                        .buttonStyle(.bordered)

                        Button("Complete Login") {
                            completeTVTrackerAuth()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(tvAuthInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .font(.system(size: 22, weight: .semibold))

                    if trackerManager.isAuthenticating {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Signing in…")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    if let error = trackerManager.authError, !error.isEmpty {
                        Text(error)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .frame(maxWidth: min(UIScreen.main.bounds.width * 0.72, 980), alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.vertical, 36)
            }
            .background(SettingsGradientBackground(scrollOffset: scrollOffset).ignoresSafeArea())
            .navigationTitle("Tracker Login")
        }
        .preferredColorScheme(.dark)
        .onReceive(trackerManager.$trackerState) { _ in
            guard let selectedTracker else { return }
            if trackerManager.trackerState.getAccount(for: selectedTracker) != nil {
                showingTVAuthSheet = false
                self.selectedTracker = nil
                tvAuthInput = ""
            }
        }
    }

    private var currentTVAuthURL: URL? {
        switch selectedTracker {
        case .anilist:
            return trackerManager.getAniListAuthURL()
        case .trakt:
            return trackerManager.getTraktAuthURL()
        case .none:
            return nil
        }
    }

    private var tvAuthInstructions: String {
        switch selectedTracker {
        case .anilist:
            return "Open the AniList login page, sign in on your phone or browser, then paste the callback URL or the returned code here to finish linking your account."
        case .trakt:
            return "Open the Trakt login page, approve access, then paste the callback URL or the returned code here to finish linking your account."
        case .none:
            return "Complete login in your browser, then paste the callback URL or code here."
        }
    }

    private func completeTVTrackerAuth() {
        let trimmed = tvAuthInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let selectedTracker else { return }

        if let callbackURL = URL(string: trimmed), trackerManager.handleAuthCallbackURL(callbackURL) {
            return
        }

        switch selectedTracker {
        case .anilist:
            trackerManager.handleAniListCallback(code: trimmed)
        case .trakt:
            trackerManager.handleTraktCallback(code: trimmed)
        }
    }
#endif
}
