//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

enum EpisodeCellLayout {
    case automatic
    case horizontal
    case immersiveHorizontal
}

struct EpisodeCell: View {
    let episode: TMDBEpisode
    let showId: Int
    let showTitle: String
    let showPosterURL: String?
    let progress: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onResetProgress: () -> Void
    var onDownload: (() -> Void)? = nil
    var layout: EpisodeCellLayout = .automatic
    
    @State private var isWatched: Bool = false
    @State private var progressValue: Double = 0
    @State private var isFocusedOnTV: Bool = false
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList: Bool = false

    private var usesHorizontalLayout: Bool {
        switch layout {
        case .automatic:
            return horizontalEpisodeList
        case .horizontal, .immersiveHorizontal:
            return true
        }
    }

    private var isImmersiveHorizontal: Bool {
        if case .immersiveHorizontal = layout {
            return true
        }
        return false
    }

    private var horizontalCardWidth: CGFloat {
        isImmersiveHorizontal ? 348 : 240 * iPadScaleSmall
    }

    private var horizontalArtworkHeight: CGFloat {
        isImmersiveHorizontal ? 196 : 135 * iPadScaleSmall
    }

    private var horizontalCardTextMinHeight: CGFloat {
        isImmersiveHorizontal ? 118 : 0
    }

    private var displayedEpisodeName: String {
        episode.name.isEmpty ? "Episode \(episode.episodeNumber)" : episode.name
    }
    
    var body: some View {
        Button(action: onTap) {
            if usesHorizontalLayout {
                horizontalLayoutContent
            } else {
                verticalLayoutContent
            }
        }
        .buttonStyle(PlainButtonStyle())
        .modifier(TVEpisodeCardFocusModifier(cornerRadius: isImmersiveHorizontal ? 24 : 16, isSelected: isSelected))
        .modifier(TVEpisodeHoverBindingModifier(isFocused: $isFocusedOnTV))
        .onLongPressGesture(minimumDuration: 0.8) {
            #if os(tvOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if isWatched {
                ProgressManager.shared.markEpisodeAsUnwatched(
                    showId: showId,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber
                )
            } else {
                ProgressManager.shared.markEpisodeAsWatched(
                    showId: showId,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber
                )
            }
            refreshProgressState()
            #endif
        }
        .onPlayPauseCommand(perform: onTap)
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
            progressValue = progress
            loadEpisodeProgress()
        }
        .onReceive(ProgressManager.shared.$episodeProgressList) { _ in
            refreshProgressState()
            progressValue = ProgressManager.shared.getEpisodeProgress(
                showId: showId,
                seasonNumber: episode.seasonNumber,
                episodeNumber: episode.episodeNumber
            )
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var horizontalLayoutContent: some View {
        VStack(alignment: .leading, spacing: isImmersiveHorizontal ? 12 : 8) {
            ZStack {
                KFImage(URL(string: episode.fullStillURL ?? ""))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(isImmersiveHorizontal ? 0.22 : 0.3))
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: horizontalCardWidth, height: horizontalArtworkHeight)
                    .clipShape(RoundedRectangle(cornerRadius: isImmersiveHorizontal ? 18 : 12))
                
                if progressValue > 0 && progressValue < 0.85 {
                    VStack {
                        Spacer()
                        ProgressView(value: progressValue)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .frame(height: isImmersiveHorizontal ? 5 : 3)
                            .padding(.horizontal, isImmersiveHorizontal ? 8 : 4)
                            .padding(.bottom, isImmersiveHorizontal ? 8 : 4)
                    }
                    .frame(width: horizontalCardWidth, height: horizontalArtworkHeight)
                    .clipShape(RoundedRectangle(cornerRadius: isImmersiveHorizontal ? 18 : 12))
                }
            }
            
            VStack(alignment: .leading, spacing: isImmersiveHorizontal ? 10 : 4) {
                HStack {
                    Text("Episode \(episode.episodeNumber)")
                        .font(isImmersiveHorizontal ? .subheadline.weight(.semibold) : .caption)
                        .foregroundColor(isImmersiveHorizontal ? .white.opacity(isFocusedOnTV ? 0.88 : 0.72) : .secondary)
                    
                    Spacer()
                    
                    HStack(spacing: isImmersiveHorizontal ? 4 : 2) {
                        if episode.voteAverage > 0 {
                            Image(systemName: "star.fill")
                                .font(isImmersiveHorizontal ? .subheadline.weight(.semibold) : .caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", episode.voteAverage))
                                .font(isImmersiveHorizontal ? .subheadline.weight(.semibold) : .caption2)
                                .foregroundColor(.white)
                            
                            Text(" - ")
                                .font(isImmersiveHorizontal ? .subheadline.weight(.semibold) : .caption2)
                                .foregroundColor(.white)
                        }
                        
                        if let runtime = episode.runtime, runtime > 0 {
                            Text(episode.runtimeFormatted)
                                .font(isImmersiveHorizontal ? .subheadline.weight(.semibold) : .caption2)
                                .foregroundColor(.white)
                        }
                        
                        #if os(tvOS)
                        Text("HD")
                            .font(.system(size: 12, weight: .black))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(4)
                            .foregroundColor(.white)
                        #endif
                    }
                    .padding(.horizontal, isImmersiveHorizontal ? 10 : 4)
                    .padding(.vertical, isImmersiveHorizontal ? 6 : 2)
                    .frame(minHeight: isImmersiveHorizontal ? 34 : nil)
                    .applyLiquidGlassBackground(
                        cornerRadius: 16,
                        fallbackFill: Color.gray.opacity(0.2),
                        fallbackMaterial: .thinMaterial,
                        glassTint: Color.gray.opacity(0.15)
                    )
                    .clipShape(Capsule())
                }
                
                Text(displayedEpisodeName)
                    .font(isImmersiveHorizontal ? .headline : .subheadline)
                    .fontWeight(isImmersiveHorizontal ? .bold : .regular)
                    .foregroundColor(isFocusedOnTV ? .white : .white.opacity(0.96))
                    .opacity(isWatched ? 0.45 : 1)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: isImmersiveHorizontal ? 56 : nil, alignment: .topLeading)
                
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(isImmersiveHorizontal ? .subheadline : .caption2)
                        .foregroundColor(isImmersiveHorizontal ? .white.opacity(isFocusedOnTV ? 0.8 : 0.62) : .secondary)
                        .lineLimit(isImmersiveHorizontal ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: horizontalCardWidth, alignment: .leading)
            .frame(minHeight: horizontalCardTextMinHeight, alignment: .topLeading)
        }
        .padding(isImmersiveHorizontal ? 14 : 0)
        .frame(width: horizontalCardWidth + (isImmersiveHorizontal ? 28 : 0), alignment: .leading)
        .background(
            Group {
                if isImmersiveHorizontal {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(isFocusedOnTV ? 0.12 : 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    isFocusedOnTV ? Color.white.opacity(0.18) : Color.clear,
                                    lineWidth: isFocusedOnTV ? 2 : 0
                                )
                        )
                }
            }
        )
    }

    @ViewBuilder
    private var verticalLayoutContent: some View {
        HStack(spacing: 12) {
            ZStack {
                KFImage(URL(string: episode.fullStillURL ?? ""))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120 * iPadScaleSmall, height: 68 * iPadScaleSmall)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if progressValue > 0 && progressValue < 0.85 {
                    VStack {
                        Spacer()
                        ProgressView(value: progressValue)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .frame(height: 3)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }
                    .frame(width: 120 * iPadScaleSmall, height: 68 * iPadScaleSmall)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Episode \(episode.episodeNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        if episode.voteAverage > 0 {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", episode.voteAverage))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(" - ")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        
                        if let runtime = episode.runtime, runtime > 0 {
                            Text(episode.runtimeFormatted)
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .applyLiquidGlassBackground(
                        cornerRadius: 16,
                        fallbackFill: Color.gray.opacity(0.2),
                        fallbackMaterial: .thinMaterial,
                        glassTint: Color.gray.opacity(0.15)
                    )
                    .clipShape(Capsule())
                }
                
                if !episode.name.isEmpty {
                    Text(episode.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .opacity(isWatched ? 0.45 : 1)
                }
                
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .applyLiquidGlassBackground(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private var episodeContextMenu: some View {
        Group {
            Button(action: onTap) {
                Label("Play", systemImage: "play.fill")
            }
            
            if let onDownload = onDownload {
                let isDownloaded = DownloadManager.shared.isDownloaded(
                    tmdbId: showId, isMovie: false,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber
                )
                let isDownloading = DownloadManager.shared.isDownloading(
                    tmdbId: showId, isMovie: false,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber
                )
                
                if isDownloaded {
                    Button(role: .destructive, action: {
                        let id = "dl_ep_\(showId)_s\(episode.seasonNumber)_e\(episode.episodeNumber)"
                        DownloadManager.shared.removeDownload(id: id, deleteFile: true)
                    }) {
                        Label("Remove Download", systemImage: "trash")
                    }
                } else if !isDownloading {
                    Button(action: onDownload) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
            }
            
            if episode.episodeNumber > 1 {
                Button(action: {
                    ProgressManager.shared.markPreviousEpisodesAsWatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    refreshProgressState()
                }) {
                    Label("Mark Previous as Watched", systemImage: "chevron.left.slash.chevron.right")
                }

                Button(action: {
                    ProgressManager.shared.markPreviousEpisodesAsUnwatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    refreshProgressState()
                }) {
                    Label("Mark Previous as Not Watched", systemImage: "arrow.uturn.backward")
                }
            }
            
            if isWatched {
                Button(action: {
                    ProgressManager.shared.markEpisodeAsUnwatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onResetProgress()
                    isWatched = false
                    refreshProgressState()
                }) {
                    Label("Mark as Not Watched", systemImage: "eye.slash")
                }
            } else {
                Button(action: {
                    ProgressManager.shared.markEpisodeAsWatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onMarkWatched()
                    isWatched = true
                    progressValue = 1
                }) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progressValue > 0 {
                Button(action: {
                    ProgressManager.shared.resetEpisodeProgress(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onResetProgress()
                    isWatched = false
                    progressValue = 0
                }) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
    
    private func loadEpisodeProgress() {
        refreshProgressState()
        progressValue = ProgressManager.shared.getEpisodeProgress(
            showId: showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }

    private func refreshProgressState() {
        isWatched = ProgressManager.shared.isEpisodeWatched(
            showId: showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
}
