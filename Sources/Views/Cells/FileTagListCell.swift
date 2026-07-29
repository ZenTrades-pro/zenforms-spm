//
//  FileTagListCell.swift
//  pro.zentrades.FPInspecter
//
//  Created by Apple on 06/06/23.
//

import UIKit
internal import TagListView

class FileTagListCell: UITableViewCell {
    var indexPath:IndexPath?

    @IBOutlet weak var tagListView: TagListView!
    
    var onItemsRemoved: ((Int)->())?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    func configure(){
        tagListView.delegate = self
        tagListView.removeAllTags()
        if let files = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!]{
            var arrTags = [String]()
            files.forEach { media in
                if !arrTags.contains(media.name){
                    arrTags.append(media.name)
                }
            }
            arrTags.forEach { tagName in
                tagListView.addTag(tagName)
            }
        }
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    fileprivate func fileItemDidTapped(_ title: String) {
        if let ssMedia = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!]?.first(where: {$0.name == title}), FPUtility.isConnectedToNetwork() ||  ssMedia.id == nil {
            FPMedia.getPreviewFilePath(fileName: ssMedia.name, serverUrl: ssMedia.serverUrl) { [weak self] filePath in
                guard let self = self, let filePath = filePath else { return }
                
                let url = URL(fileURLWithPath: filePath)
                let documentInteractionController = UIDocumentInteractionController(url: url)
                documentInteractionController.delegate = self
                DispatchQueue.main.async {
                    documentInteractionController.presentPreview(animated: true)
                }
            }
        } else {
            _  = FPUtility.showAlertController(title:FPLocalizationHelper.localize("alert_dialog_title"), message:FPLocalizationHelper.localize("msg_can_not_view_attachment_offline")){}
        }
    }
    
}


extension FileTagListCell:  UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return FPUtility.topViewController() ?? UIViewController()
    }
}

extension FileTagListCell : TagListViewDelegate{
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) -> Void{
        self.fileItemDidTapped(title)
    }
    
    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) -> Void{
        if let files = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!], let index = files.firstIndex(where:{$0.name == title}), let media = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!]?[index], FPUtility.isConnectedToNetwork() ||  media.id == nil {
                FPFormDataHolder.shared.removeMediaAt(indexPath: self.indexPath!, index: index)
            tagListView.removeTag(title)
            onItemsRemoved?(index)
        }else {
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), message:
                                                FPLocalizationHelper.localize("msg_can_not_delete_attachment_offline")){}
        }
    }
    
}



