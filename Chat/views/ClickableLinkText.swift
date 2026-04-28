// Add this view for rendering text with clickable links
struct ClickableLinkText: View {
    let text: String
    let isCurrentUser: Bool
    
    var body: some View {
        Text(attributedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
    
    private var attributedText: AttributedString {
        var result = AttributedString(text)
        
        // Find URLs in text
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches {
            if let range = Range(match.range, in: text),
               let url = match.url {
                let attributedRange = result.range(of: String(text[range]))
                if let attributedRange = attributedRange {
                    result[attributedRange].link = url
                    result[attributedRange].underlineStyle = .single
                }
            }
        }
        
        return result
    }
}