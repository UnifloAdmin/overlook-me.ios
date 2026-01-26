import SwiftUI

struct QuoteTile: View {
    let quote: DailyQuote
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                
                Text(quote.text)
                    .font(.subheadline)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("— \(quote.author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuoteTile(
        quote: DailyQuote(
            text: "The only way to do great work is to love what you do.",
            author: "Steve Jobs"
        ),
        onTap: {}
    )
    .padding()
}
