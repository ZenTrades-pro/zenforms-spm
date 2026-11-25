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
            for media in files {
                tagListView.addTag(media.name)
            }
        }
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    fileprivate func fileItemDidTapped(_ selectedIndex: Int) {
        guard let indexPath, let presenter = FPUtility.topViewController() else { return }
        let files = FPFormDataHolder.shared.getFiledFilesArray()[indexPath] ?? []
        FPMedia.presentAttachmentGallery(files, selectedIndex: selectedIndex, from: presenter)
    }
}

extension FileTagListCell : TagListViewDelegate{
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) -> Void{
        guard let index = sender.tagViews.firstIndex(of: tagView) else { return }
        fileItemDidTapped(index)
    }
    
    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) -> Void{
        if let files = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!], let index = sender.tagViews.firstIndex(of: tagView), let media = files[safe: index], FPUtility.isConnectedToNetwork() ||  media.id == nil {
                FPFormDataHolder.shared.removeMediaAt(indexPath: self.indexPath!, index: index)
            sender.removeTagView(tagView)
            onItemsRemoved?(index)
        }else {
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), message:
                                                FPLocalizationHelper.localize("msg_can_not_delete_attachment_offline")){}
        }
    }
    
}



