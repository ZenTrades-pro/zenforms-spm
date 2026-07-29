
import SwiftUI
internal import SSMediaManager

struct FPSignatureFieldCell: View {
    var fieldItem: FPFieldDetails
    var fieldIndexPth:IndexPath
    var isViewOnly: Bool = false
    var onAddSignatureClicked: () -> Void
    var onSignatureRemove: () -> Void
    
    @State var localImge = Image("WhiteImage")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if fieldItem.mandatory, fieldItem.getUIType() != .AUTO_POPULATE{
                    SwiftUI.Text(fetchAttributedString())
                }else{
                    SwiftUI.Text(fieldItem.displayName?.handleAndDisplayApostrophe() ?? "")
                        .font(.headline)
                        .foregroundColor(Color("ZT-Black"))
                }
                Spacer()
                if !isViewOnly{
                    Button(action: onAddSignatureClicked) {
                        SwiftUI.Text(FPLocalizationHelper.localize("lbl_Add_Signature"))
                            .foregroundStyle(Color("BT-Primary"))
                            .font(.system(size: 14, weight: .medium))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150, alignment: .trailing)
                    }
                }
            }
            if !isImageHidden(){
                HStack(alignment: .center, spacing: 16) {
                    localImge
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .border(Color("BT-Success"), width: 1)

                    if !isViewOnly{
                        Button(action: onSignatureRemove) {
                            Image("delete")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .frame(width: 40, height: 40)
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .onAppear {
            self.getItemImage { img in
                if let img = img{
                    self.localImge = Image(uiImage: img)
                }
            }
        }
    }
    
    func fetchAttributedString() -> AttributedString {
        let fontAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.black]
        let baseString =  NSAttributedString(string: " \(fieldItem.displayName?.handleAndDisplayApostrophe() ?? "")", attributes: fontAttributes)
        let colrattributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.red]
        let starString =  NSAttributedString(string: "*", attributes: colrattributes)
        let mutableString = NSMutableAttributedString(attributedString: starString)
        mutableString.append(baseString)
        return AttributedString(mutableString)
    }
    
    func getItemImage( completion: @escaping ((_ img: UIImage?) -> Void )){
        if self.isImageHidden(){
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .default).async {
            let fileManager = FileManager.default
            var itemValue = fieldItem.value
            var file = FPFormDataHolder.shared.getFiledFilesArray()[fieldIndexPth]?.first
            if isFromCoPILOT{
                itemValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: itemValue, isForLocal: false)
            }
            if (file == nil && (itemValue != nil || itemValue != "")){
                file = SSMedia(name: "signature.png",serverUrl: itemValue, moduleType: .forms)
            }
            if let filePath = file?.filePath, fileManager.fileExists(atPath:filePath){
                let image = UIImage(contentsOfFile: file!.filePath!)
                DispatchQueue.main.async {
                    completion(image)
                }
            }else{
                FPUtility.downloadedImage(from: file?.serverUrl) { (image) in
                    DispatchQueue.main.async {
                        if let downImg = image {
                            completion(downImg)
                            do {
                                let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
                                let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateImageFileName())
                                let imageData = image!.pngData()
                                fileManager.createFile(atPath: fileURL.path, contents: imageData, attributes: nil)
                                let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection:fieldIndexPth.section, atIndex: fieldIndexPth.row)
                                let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                                FPFormDataHolder.shared.addFileAt(index:fieldIndexPth, withMedia: media)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func isImageHidden() -> Bool{
        var itemValue = fieldItem.value
        let file = FPFormDataHolder.shared.getFiledFilesArray()[fieldIndexPth]?.first
        if isFromCoPILOT{
            itemValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: itemValue, isForLocal: false)
        }
        let isHidden =  (itemValue == nil || itemValue == "") && (file?.filePath == nil &&  file?.serverUrl == nil)
        return isHidden
    }
}
