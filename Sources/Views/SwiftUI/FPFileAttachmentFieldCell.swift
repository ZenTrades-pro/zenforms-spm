import SwiftUI
internal import SwiftUIFlowLayout

struct FPFileAttachmentFieldCell: View {
    let displayName: String
    let items: [String]
    var isViewOnly: Bool = false
    
    var onAttachFileClicked: (() -> Void)?
    var onItemsRemoved: ((Int)-> Void)?
    var onItemsClicked: ((Int)-> Void)?
    
    @ViewBuilder
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SwiftUI.Text(displayName)
                    .font(.headline)
                    .foregroundStyle(Color("ZT-Black"))
                
                Spacer()
                if !isViewOnly{
                    Button(FPLocalizationHelper.localize("lbl_Attach_file")) {
                        onAttachFileClicked?()
                    }
                    .foregroundColor(Color("BT-Primary"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
            attachedFilesView
        }
        .padding(10)
        .background(Color.white)
    }
    
    @ViewBuilder
    private var attachedFilesView: some View {
        FlowLayout(mode: .scrollable, items: Array(items.indices), itemSpacing: 4) { index in
            HStack(spacing: 8) {
                SwiftUI.Text(items[index])
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                
                if !isViewOnly{
                    Button(action: {
                        onItemsRemoved?(index)
                    }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.trailing, 8)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("BT-Primary"))
            )
            .onTapGesture {
                onItemsClicked?(index)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    FPFileAttachmentFieldCell(
        displayName: "Section Attachment",
        items: ["1059041.jpeg", "9667319.jpeg", "9833648.jpeg", "1907559.jpeg", "4457763.jpeg", "4644495.jpeg", "8198355.jpeg"],
        isViewOnly: false,
        onAttachFileClicked: {},
        onItemsRemoved: { _ in }
    )
}
