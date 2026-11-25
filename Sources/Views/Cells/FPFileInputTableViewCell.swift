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
    var onItemsClicked: ((Int)->())?
    
    override func awakeFromNib() {
        tagListView.delegate = self
        super.awakeFromNib()
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        if horizontalFittingPriority == .required, targetSize.width > 0, targetSize.width.isFinite {
            // A newly dequeued cell can still have its nib width when the table first measures it.
            // Lay out the tags at the proposed row width so their intrinsic height reflects wrapping.
            if bounds.width != targetSize.width {
                bounds.size.width = targetSize.width
            }
            setNeedsLayout()
            layoutIfNeeded()
            tagListView?.layoutIfNeeded()
        }
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
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
            for media in files {
                tagListView.addTag(media.name)
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
        guard let index = sender.tagViews.firstIndex(of: tagView) else { return }
        onItemsClicked?(index)
    }
}

protocol PFFileInputDelegate: AnyObject{
    func didAttachTap(at:IndexPath,sender:UIButton, isImageOnly:Bool)
}
