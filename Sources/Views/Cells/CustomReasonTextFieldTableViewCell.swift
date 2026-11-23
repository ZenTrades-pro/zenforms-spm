//
//  CustomReasonTextFieldTableViewCell.swift
//  crm
//
//  Created by Mayur on 02/03/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import UIKit

protocol CustomReasonTextFieldTableViewCellDelegate: AnyObject {
    func updateCustomReasonWith(_ value: String,otherData:[String:Any])
    func updateCustomAiSuggestionWith()
}

class CustomReasonTextFieldTableViewCell: UITableViewCell {

    @IBOutlet weak var reasonTextField: UITextField!
    weak var delegate: CustomReasonTextFieldTableViewCellDelegate?
    override func awakeFromNib() {
        super.awakeFromNib()
        setReasonTextField()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.reasonTextField.text = ""
    }
    
    private func setReasonTextField() {
        self.reasonTextField.layer.cornerRadius = 4
        self.reasonTextField.layer.borderColor = UIColor.systemGray4.cgColor
        self.reasonTextField.layer.borderWidth = 1
        self.reasonTextField.text = ""
        self.reasonTextField.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func setCustomReasonCell(reasonText: String, index: Int) {
        self.reasonTextField.text = reasonText
        self.reasonTextField.tag = index
    }
    
}

extension CustomReasonTextFieldTableViewCell: UITextFieldDelegate{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        delegate?.updateCustomReasonWith(textField.text ?? "",otherData: [:])
    }
}
