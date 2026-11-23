//
//  FileReasonCell.swift
//  pro.zentrades.FPInspecter
//
//  Created by Apple on 06/06/23.
//

import UIKit

class FileReasonCell: UITableViewCell {
    weak var delegate:PFFileInputDelegate?
    var indexPath:IndexPath?
    @IBOutlet weak var btnAddImage: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    @IBAction func addImage(_ sender: UIButton) {
        delegate?.didAttachTap(at: indexPath!, sender: sender, isImageOnly: true)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
