//
//  FPFileInputTableViewCell.swift
//  crm
//
//  Created by Apple on 14/06/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import UIKit
internal import TagListView
internal import SSMediaManager

class FPFileInputTableViewCell: UITableViewCell {

    @IBOutlet weak var lblQuestion: UILabel!
    @IBOutlet weak var tagListView: TagListView!
    @IBOutlet weak var btnAttachFile: UIButton!

    var indexPath:IndexPath?
    weak var delegate:PFFileInputDelegate?
    var onItemsRemoved: ((Int)->())?
    var onItemsClicked: ((String)->())?
    
    override func awakeFromNib() {
        tagListView.delegate = self
        super.awakeFromNib()
    }

    @IBAction func attachFileDidTap(_ sender: UIButton) {
        if let index = indexPath{
            delegate?.didAttachTap(at: index,sender: sender, isImageOnly: false)
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func configureCell(files: [SSMedia]?){
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
    
}

extension FPFileInputTableViewCell: TagListViewDelegate {
    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) {
        if let index = sender.tagViews.firstIndex(of: tagView) {
            onItemsRemoved?(index)
        }
    }
    
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
        onItemsClicked?(title)
    }
}

protocol PFFileInputDelegate: AnyObject{
    func didAttachTap(at:IndexPath,sender:UIButton, isImageOnly:Bool)
}
