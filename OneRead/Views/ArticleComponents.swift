import SwiftUI
import NaturalLanguage
import UIKit

struct ArticleCard: View {
    @EnvironmentObject private var store: ArticleStore
    let article: Article
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ArticleHeroImage(article: article)
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Text(String(format: "%02d", rank))
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.accent.opacity(0.32))
            }

            VStack(alignment: .leading, spacing: 8) {
                ArticleMetaLine(article: article)

                Text(article.title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.summary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(3)
            }

            HStack {
                Label("\(article.readingMinutes) min", systemImage: "clock")
                Spacer()
                Image(systemName: store.isRead(article) ? "checkmark.circle.fill" : "circle")
                Image(systemName: store.isSaved(article) ? "bookmark.fill" : "bookmark")
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.accent)
        }
        .padding(18)
        .cardBackground()
    }
}

struct ArticleListCard: View {
    @EnvironmentObject private var store: ArticleStore
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArticleHeroImage(article: article)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                ArticleMetaLine(article: article)

                Text(article.title)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: store.isSaved(article) ? "bookmark.fill" : "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(store.isSaved(article) ? Palette.amber : Palette.border)
                .padding(.top, 4)
        }
        .padding(16)
        .cardBackground()
    }
}

struct ArticleMetaLine: View {
    let article: Article

    var body: some View {
        HStack(spacing: 8) {
            Label(article.category.title, systemImage: article.category.systemImage)
            Text("·")
            Text(article.source)
            Text("·")
            Text(article.publishedDateTimeText)
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(Palette.muted)
        .lineLimit(1)
    }
}

struct ArticleVisualMark: View {
    let category: ArticleCategory

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.accentSoft)

            Image(systemName: category.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Palette.accent)
        }
    }
}

struct ArticleHeroImage: View {
    let article: Article

    var body: some View {
        ResilientRemoteImage(
            primaryURL: article.imageURL,
            placeholder: placeholder
        )
        .id("\(article.id)|\(article.imageURLString)")
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.surface)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.glass.opacity(0.6))
        }
    }
}

struct ResilientRemoteImage<Placeholder: View>: View {
    let primaryURL: URL?
    let placeholder: Placeholder
    @State private var image: UIImage?
    @State private var activeRequestKey = ""

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .task(id: primaryURL?.absoluteString ?? "no-image") {
            let requestKey = primaryURL?.absoluteString ?? "no-image"
            activeRequestKey = requestKey
            await load(requestKey: requestKey)
        }
        .animation(.easeInOut(duration: 0.18), value: image)
    }

    private func load(requestKey: String) async {
        await MainActor.run {
            guard activeRequestKey == requestKey else {
                return
            }
            image = nil
        }

        if let primaryURL,
           let loaded = await fetchImage(from: primaryURL) {
            await MainActor.run {
                guard activeRequestKey == requestKey else {
                    return
                }
                image = loaded
            }
        }
    }

    private func fetchImage(from url: URL) async -> UIImage? {
        if let cachedImage = ArticleRemoteImageCache.shared.image(for: url) {
            return cachedImage
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  httpResponse.mimeType?.hasPrefix("image/") == true,
                  data.count <= 15 * 1024 * 1024,
                  let loadedImage = UIImage(data: data) else {
                return nil
            }

            ArticleRemoteImageCache.shared.insert(loadedImage, for: url)
            return loadedImage
        } catch {
            return nil
        }
    }
}

private final class ArticleRemoteImageCache {
    static let shared = ArticleRemoteImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

struct ArticleCategoryChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isSelected ? .white : Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Palette.accent : Palette.surface)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ArticleStatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}
