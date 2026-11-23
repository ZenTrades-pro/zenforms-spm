//
//  ReasonsCollectionViewCell.swift
//  crm
//
//  Created by Mayur on 24/02/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import UIKit
internal import SSMediaManager
import AVFoundation

class ReasonsCollectionViewCell: UITableViewCell {
    
    @IBOutlet weak var customView: FPSegmentView!
    
    weak var delegate :FPCollectionCellDelegate?
    weak var fileInputDelegate:PFFileInputDelegate?
    weak var zenFormDelegate: ZenFormsDelegate?
    var index = IndexPath()
    var fieldItem :FPFieldDetails?
    var isNew: Bool = true
    
    override func awakeFromNib() {
        super.awakeFromNib()
        customView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            customView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            customView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            customView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configureCell(with item: FPFieldDetails, indexPath: IndexPath) {
        self.fieldItem = item
        customView.fileInputDelegate = fileInputDelegate
        customView.zenFormDelegate = self.zenFormDelegate
        self.index = indexPath
        if let files = item.attachments?.getArray(){
            files.forEach { uploadedItem in
                if let name = uploadedItem["altText"] as? String{
                    if  uploadedItem["isDeleted"] as? Bool == false ||  uploadedItem["isDeleted"]  == nil {
                        let media  = SSMedia(name: name, id: uploadedItem["id"] as? String , mimeType: (uploadedItem["file"] as? String)?.fileMimeType(), serverUrl: uploadedItem["file"] as? String, moduleType: .forms)
                        if(!item.deletedFiles.contains(media.id ?? "")){
                            FPFormDataHolder.shared.addFileAt(index:indexPath, withMedia: media)
                        }
                    }
                }
            }
        }
        if let delegate = delegate {
            customView.delegate = delegate
        }
        let displayName = item.displayName?.handleAndDisplayApostrophe() ?? ""
        customView.fieldItem = item
        customView.title = displayName
        customView.collectionIndex = indexPath
        customView.attachments =  item.attachments ?? ""
        let reasons = item.getReasonsList(strJson: item.reasons ?? "")
        customView.cellItem = FPReasonsComponent().preparedData(reasons ?? [FPReasons](), value: item.value, templateId: item.templateId ?? "")
    }
    
}
