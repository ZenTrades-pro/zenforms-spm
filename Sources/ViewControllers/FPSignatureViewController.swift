//
//  FPSignatureViewController.swift
//  FP-Form-Detail
//
//  Created by apple on 15/04/24.
//

import UIKit
import Foundation
internal import PPSSignatureView
@objc protocol FPSignatureDelegate {
    func getSignatureImage(_ image: UIImage?)
}


@objc class FPSignatureViewController: UIViewController{
    
    @IBOutlet private weak var signatureImageBackgroundView: PPSSignatureView!
    @IBOutlet weak var savedSignatureImageView: UIImageView!
    @IBOutlet weak var outerSignatureView: UIView!
    @IBOutlet weak var signHightConst: NSLayoutConstraint!

    @objc var del: FPSignatureDelegate?
    @objc var signature: FPMedia?
    @IBOutlet weak var signWidhConst: NSLayoutConstraint!
    @IBOutlet weak var signPhoneWidthConst: NSLayoutConstraint!

    private var clearButton: UIBarButtonItem?
    private var saveButton: UIBarButtonItem?
    private var strokeWidthSlider: UISlider?


    var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearButton = UIBarButtonItem(title: FPLocalizationHelper.localize("lbl_Clear"), style: .plain, target: self, action: #selector(self.clearSignatureView(_:)))
        saveButton = UIBarButtonItem(title: FPLocalizationHelper.localize("SAVE"), style: .plain, target: self, action: #selector(self.saveSignature(_:)))
        navigationItem.rightBarButtonItems = [saveButton, clearButton] as? [UIBarButtonItem]
        outerSignatureView.layer.borderWidth = 1.0
        outerSignatureView.layer.borderColor = UIColor(red: 64 / 255.0, green: 164 / 255.0, blue: 28 / 255.0, alpha: 1.0).cgColor
        navigationItem.title = FPLocalizationHelper.localize("lbl_Signature")
        
        let isRegular = traitCollection.horizontalSizeClass == .regular
        signPhoneWidthConst.isActive = !isRegular
        signWidhConst.isActive = isRegular
        
        if (signature != nil) {
            saveButton?.isEnabled = false
            savedSignatureImageView.isHidden = false
        } else {
            saveButton?.isEnabled = true
            savedSignatureImageView.isHidden = true
        }
       
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Setup slider after view has appeared and layout is complete
        if strokeWidthSlider == nil {
            setupStrokeWidthSlider()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSignViewConstraints()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            // Recreate slider after rotation is complete
            self.setupStrokeWidthSlider()
            self.updateSignViewConstraints()
        }
        self.view.layoutIfNeeded()
    }
    
    func updateSignViewConstraints() {
        signHightConst.constant = screenHeight * 0.4
        self.view.layoutIfNeeded()
    }
    
    @objc func saveSignature(_ sender: UIBarButtonItem?) {

        if signatureImageBackgroundView.hasSignature {
            FPUtility.showHUDWithLoadingMessage()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                guard let signatureImage = self.signatureImageBackgroundView.signatureImage else { return }
                let resizedImage = FPUtility.imageWithImage(image: signatureImage, convertToSize: CGSize(width: 730.0, height: 250.0))
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    FPUtility.hideHUD()
                    self.del?.getSignatureImage(resizedImage)
                    self.navigationController?.popViewController(animated: true)
                }
            }
        } else {
            FPUtility.showErrorMessage(nil, withTitle: FPLocalizationHelper.localize("No_Signature"), withWarningMessage:  FPLocalizationHelper.localize("Please_Get_Signature"))
        }
    }
    
    @objc func clearSignatureView(_ sender: UIBarButtonItem?) {
        if signatureImageBackgroundView.hasSignature {
            signatureImageBackgroundView.erase()
        } else if !savedSignatureImageView.isHidden {
            saveButton?.isEnabled = true
            savedSignatureImageView.isHidden = true
        }
    }
    
    
    func serviceAgreementNotPitchedAction() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupStrokeWidthSlider() {
        // Remove existing slider if any
        strokeWidthSlider?.removeFromSuperview()
        
        let slider = UISlider()
        slider.minimumValue = 1.0
        slider.maximumValue = 10.0
        slider.value = strokeWidthSlider?.value ?? 1.0
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        // Style the slider
        slider.minimumTrackTintColor = UIColor(named: "BT-Primary") ?? .systemBlue
        slider.maximumTrackTintColor = .lightGray
        slider.thumbTintColor = UIColor(named: "BT-Primary") ?? .systemBlue
        
        // Rotate to vertical
        slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        slider.addTarget(self, action: #selector(strokeWidthChanged(_:)), for: .valueChanged)
        
        // Add as subview to main view
        view.addSubview(slider)
        view.bringSubviewToFront(slider)
        
        // Position just to the right of the signature box - works on all screen sizes
        let sliderHeight = signatureImageBackgroundView.bounds.height * 0.9
        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: outerSignatureView.trailingAnchor, constant: UIDevice.current.userInterfaceIdiom == .pad ? 32 : 16),
            slider.centerYAnchor.constraint(equalTo: signatureImageBackgroundView.centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 32),
            slider.widthAnchor.constraint(equalToConstant: sliderHeight)
        ])

        strokeWidthSlider = slider
        signatureImageBackgroundView.strokeWidth = CGFloat(slider.value)
    }
    
    @objc private func strokeWidthChanged(_ slider: UISlider) {
        signatureImageBackgroundView.strokeWidth = CGFloat(slider.value)
    }
    
}
