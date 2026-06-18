import Foundation

extension String {
    var htmlDecoded: String {
        guard contains("&"), let data = data(using: .utf8) else {
            return self
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let decoded = try? NSAttributedString(data: data, options: options, documentAttributes: nil).string else {
            return self
        }

        return decoded
    }
}
