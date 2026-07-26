// JawabiUserSelectionRow.swift
import SwiftUI

struct JawabiUserSelectionRow: View {
    let user: GetAllUsersDM
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                JawabiAvatar(
                    name: user.name,
                    imageUrl: user.fullPictureUrl,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(user.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color.jawabiPrimary : .gray)
                    .font(.title2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}