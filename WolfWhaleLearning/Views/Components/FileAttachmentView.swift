import SwiftUI

/// A reusable component that displays attached files and provides an "Add Attachment" button.
struct FileAttachmentView: View {
    @Binding var attachments: [PickedFile]
    @State private var showFilePicker = false
    @State private var hapticTrigger = false

    /// Maximum number of attachments allowed.
    let maxAttachments: Int

    init(attachments: Binding<[PickedFile]>, maxAttachments: Int = 5) {
        self._attachments = attachments
        self.maxAttachments = maxAttachments
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Attached Files List
            if !attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(attachments) { file in
                        fileRow(file)
                    }
                }
            }

            // MARK: - Add Attachment Button
            if attachments.count < maxAttachments {
                Button {
                    hapticTrigger.toggle()
                    showFilePicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("Add Attachment")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(attachments.count)/\(maxAttachments)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .sheet(isPresented: $showFilePicker) {
            FilePickerView { pickedFile in
                if attachments.count < maxAttachments {
                    attachments.append(pickedFile)
                }
                showFilePicker = false
            } onCancel: {
                showFilePicker = false
            }
        }
    }

    // MARK: - File Row

    private func fileRow(_ file: PickedFile) -> some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: file.iconName)
                .font(.title3)
                .foregroundStyle(file.iconColor)
                .frame(width: 36, height: 36)
                .background(file.iconColor.opacity(0.12), in: .rect(cornerRadius: 8))

            // File name and size
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Remove button
            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    attachments.removeAll { $0.id == file.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }
}
