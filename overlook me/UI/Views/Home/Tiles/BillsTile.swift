import SwiftUI

struct BillsTile: View {
    let bills: [UpcomingBill]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Bills", systemImage: "doc.text.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 6) {
                    ForEach(bills.prefix(3)) { bill in
                        HStack(spacing: 10) {
                            Text(bill.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(bill.isUrgent ? .white : .primary)
                            
                            Spacer()
                            
                            Text("\(bill.daysUntil)d")
                                .font(.caption)
                                .foregroundStyle(bill.isUrgent ? .white.opacity(0.8) : .secondary)
                            
                            Text("$\(Int(bill.amount))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(bill.isUrgent ? .white : .primary)
                                .frame(minWidth: 40, alignment: .trailing)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(bill.isUrgent ? AnyShapeStyle(Color.red) : AnyShapeStyle(.fill.tertiary))
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BillsTile(
        bills: [
            UpcomingBill(name: "Netflix", amount: 16, daysUntil: 2, icon: "tv", color: .gray),
            UpcomingBill(name: "Spotify", amount: 10, daysUntil: 5, icon: "music.note", color: .green),
            UpcomingBill(name: "Electric", amount: 85, daysUntil: 8, icon: "bolt.fill", color: .yellow)
        ],
        onTap: {}
    )
    .frame(height: 180)
    .padding()
}
