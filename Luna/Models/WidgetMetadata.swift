//
//  WidgetMetadata.swift
//  Luna
//
//  Curated metadata for home screen discover widgets.
//

import Foundation

// MARK: - Network Widget

struct WidgetNetwork: Identifiable {
    let id: Int // TMDB network ID
    let name: String
    let logoName: String // SF Symbol or asset name
    
    static let curated: [WidgetNetwork] = [
        WidgetNetwork(id: 213,  name: "Netflix",      logoName: "play.rectangle.fill"),
        WidgetNetwork(id: 2739, name: "Disney+",      logoName: "sparkles.tv.fill"),
        WidgetNetwork(id: 49,   name: "HBO",           logoName: "tv.fill"),
        WidgetNetwork(id: 1024, name: "Amazon",        logoName: "shippingbox.fill"),
        WidgetNetwork(id: 2552, name: "Apple TV+",     logoName: "apple.logo"),
        WidgetNetwork(id: 453,  name: "Hulu",          logoName: "play.tv.fill"),
        WidgetNetwork(id: 4330, name: "Paramount+",    logoName: "mountain.2.fill"),
        WidgetNetwork(id: 1112, name: "Crunchyroll",   logoName: "play.circle.fill")
    ]
}

// MARK: - Company Widget

struct WidgetCompany: Identifiable {
    let id: Int // TMDB company ID
    let name: String
    
    static let curated: [WidgetCompany] = [
        WidgetCompany(id: 33,    name: "Universal"),
        WidgetCompany(id: 4,     name: "Paramount"),
        WidgetCompany(id: 174,   name: "Warner Bros."),
        WidgetCompany(id: 25,    name: "20th Century"),
        WidgetCompany(id: 2,     name: "Walt Disney"),
        WidgetCompany(id: 41077, name: "A24"),
        WidgetCompany(id: 1632,  name: "Lionsgate"),
        WidgetCompany(id: 5,     name: "Columbia")
    ]
}

// MARK: - Genre Widget

struct WidgetGenre: Identifiable {
    let id: Int // TMDB genre ID
    let name: String
    
    static let curated: [WidgetGenre] = [
        WidgetGenre(id: 28,    name: "Action"),
        WidgetGenre(id: 35,    name: "Comedy"),
        WidgetGenre(id: 18,    name: "Drama"),
        WidgetGenre(id: 878,   name: "Sci-Fi"),
        WidgetGenre(id: 10749, name: "Romance"),
        WidgetGenre(id: 16,    name: "Animation"),
        WidgetGenre(id: 10751, name: "Family"),
        WidgetGenre(id: 53,    name: "Thriller"),
        WidgetGenre(id: 27,    name: "Horror"),
        WidgetGenre(id: 99,    name: "Documentary")
    ]
}
