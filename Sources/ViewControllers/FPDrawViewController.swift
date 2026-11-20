//
//  FPDrawViewController.swift
//  FP-Form-Detail
//
//  Created by apple on 15/04/24.
//

import UIKit
import AVFoundation.AVUtilities
import QuartzCore
internal import ACEDrawingView

let kActionSheetColor  =  100
let kActionSheetTool   =  101

@objc protocol FPDrawHelper: NSObjectProtocol {
    func imageSelected(_ image: UIImage)
}


class FPDrawViewController: UIViewController, UIActionSheetDelegate, ACEDrawingViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    weak var delegate: FPDrawHelper?
    
    @IBOutlet weak var drawingView: ACEDrawingView!
    @IBOutlet weak var lineWidthSlider: UISlider!
    @IBOutlet weak var lineAlphaSlider: UISlider!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var baseImageView: UIImageView!
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!
    @IBOutlet weak var colorButton: UIButton!
    @IBOutlet weak var toolButton: UIButton!
    @IBOutlet weak var alphaButton: UIButton!
    
    @objc var doneButton: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.drawingView.delegate = self
        self.lineWidthSlider.value = Float(self.drawingView.lineWidth)
        self.previewImageView.layer.borderColor = UIColor.gray.cgColor
        self.previewImageView.layer.borderWidth  = 0.2
        self.drawingView.draggableTextFontName = "MarkerFelt-Thin"
        
        self.doneButton = UIBarButtonItem(title:FPLocalizationHelper.localize("Done"), style:.plain, target:self, action:#selector(donePressed))
        self.navigationItem.rightBarButtonItems = [self.doneButton!]
        self.presentOptionsToChooseImageToCustomer()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleOrientationChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)

    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func handleOrientationChange() {
        adjustDrawingViewFrame()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustDrawingViewFrame()
    }

    func adjustDrawingViewFrame() {
        if let image = self.baseImageView.image {
            self.drawingView.frame = AVMakeRect(aspectRatio: image.size, insideRect: self.baseImageView.bounds)
        } else {
            self.drawingView.frame = self.baseImageView.bounds
        }
    }
    
    func updateButtonStatus() {
        self.undoButton.isEnabled = self.drawingView.canUndo()
        self.redoButton.isEnabled = self.drawingView.canRedo()
    }
    
    @objc func donePressed() {
        var baseImage:UIImage?
        if let img = self.drawingView.image {
            baseImage = img
        }
        baseImage = baseImage != nil ? baseImage : UIImage(named: "WhiteImage", in: ZenFormsBundle.bundle, compatibleWith: nil)
        let baseImage1 = self.baseImageView.image
        self.drawingView.endEditing(true)
        self.delegate?.imageSelected((baseImage1 != nil ? self.drawingView.applyDraw(to: baseImage1!) : baseImage) ?? UIImage())
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func takeScreenshot(_ sender:UIButton) {
        var baseImage = self.drawingView.image
        baseImage = baseImage != nil ? baseImage : UIImage(named: "WhiteImage", in: ZenFormsBundle.bundle, compatibleWith: nil)
        self.previewImageView.image =  baseImage != nil ? self.drawingView.applyDraw(to: baseImage!) : self.drawingView.image
        self.previewImageView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.previewImageView.isHidden = true
        }
        self.saveDrawingSnapshot()
    }
    
    func saveDrawingSnapshot() {
        let snapShotImage = self.takeSnapshotOfDrawing(imageView: self.previewImageView)
        self.delegate?.imageSelected(snapShotImage)
    }
    
    
    func takeSnapshotOfDrawing(imageView:UIImageView) -> UIImage {
        UIGraphicsBeginImageContext(CGSizeMake(self.drawingView.frame.size.width, self.drawingView.frame.size.height))
        imageView.drawHierarchy(in: CGRectMake(0, 0, self.drawingView.frame.size.width, self.drawingView.frame.size.height), afterScreenUpdates:true)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return UIImage() }
        UIGraphicsEndImageContext()
        return image
    }
    
    
    @IBAction func undo(_ sender:UIButton) {
        self.drawingView.undoLatestStep()
        self.updateButtonStatus()
    }
    
    @IBAction func redo(_ sender:UIButton) {
        self.drawingView.redoLatestStep()
        self.updateButtonStatus()
    }
    
   
    @IBAction func clear(_ sender:UIBarButtonItem) {
        if let _ = self.drawingView.image {
            self.baseImageView.image = nil
            self.drawingView.frame = self.baseImageView.frame
        }
        self.drawingView.clear()
        self.updateButtonStatus()
    }
    
    // MARK: - ACEDrawing View Delegate
    
    func drawingView(_ view: ACEDrawingView!, didEndDrawUsing tool: ACEDrawingTool!) {
        self.updateButtonStatus()
    }

//    func drawingView(view:ACEDrawingView, configureTextToolLabelView label:ACEDrawingLabelView) {
//    }
    

    
    // MARK: - Settings
    
    @IBAction func colorChange(_ sender:UIButton) {
        let alert = UIAlertController(title: FPLocalizationHelper.localize("lbl_Selet_color"), message: "", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Black"), style: .default , handler:{ action in
            self.colorButton.setTitle(FPLocalizationHelper.localize("lbl_Black"), for: .normal)
            self.drawingView.lineColor = .black
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Red"), style: .default , handler:{ action in
            self.colorButton.setTitle(FPLocalizationHelper.localize("lbl_Red"), for: .normal)
            self.drawingView.lineColor = .red
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Green"), style: .default , handler:{ action in
            self.colorButton.setTitle(FPLocalizationHelper.localize("lbl_Green"), for: .normal)
            self.drawingView.lineColor = .green
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Blue"), style: .default , handler:{ action in
            self.colorButton.setTitle(FPLocalizationHelper.localize("lbl_Blue"), for: .normal)
            self.drawingView.lineColor = .blue
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("Cancel"), style: .cancel , handler:{_ in }))
        alert.applyLegacyActionSheetStyle()
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.present(alert, animated: true) {
            }
        } else {
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func toolChange(_ sender:UIButton) {
        
        let alert = UIAlertController(title:FPLocalizationHelper.localize("lbl_Select_tool"), message: "", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Pen"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Pen"))
            self.drawingView.drawTool = ACEDrawingToolTypePen
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Line"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Line"))
            self.drawingView.drawTool = ACEDrawingToolTypeLine
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Arrow"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Arrow"))
            self.drawingView.drawTool = ACEDrawingToolTypeArrow
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Rect_Stroke"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Rect_Stroke"))
            self.drawingView.drawTool = ACEDrawingToolTypeRectagleStroke
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Rect_Fill"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Rect_Fill"))
            self.drawingView.drawTool = ACEDrawingToolTypeRectagleFill
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Ellipse_Stroke"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Ellipse_Stroke"))
            self.drawingView.drawTool = ACEDrawingToolTypeEllipseStroke
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Ellipse_Fill"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Ellipse_Fill"))
            self.drawingView.drawTool = ACEDrawingToolTypeEllipseFill
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Eraser"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Eraser"))
            self.drawingView.drawTool = ACEDrawingToolTypeEraser
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("lbl_Draggable_Text"), style: .default , handler:{ action in
            self.toolButton.fpUpdateButtonTitle(title: FPLocalizationHelper.localize("lbl_Draggable_Text"))
            self.drawingView.drawTool = ACEDrawingToolTypeDraggableText
            self.alphaButton.isEnabled = true
            self.colorButton.isEnabled = self.alphaButton.isEnabled
        }))
        
        alert.addAction(UIAlertAction(title:FPLocalizationHelper.localize("Cancel"), style: .cancel , handler:{_ in }))
        alert.applyLegacyActionSheetStyle()
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.present(alert, animated: true) {
            }
        } else {
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func toggleWidthSlider(_ sender:UIButton) {
        self.lineWidthSlider.isHidden = !self.lineWidthSlider.isHidden
        self.lineAlphaSlider.isHidden = true
    }
    
    @IBAction func widthChange(_ sender:UISlider) {
        self.drawingView.lineWidth = CGFloat(sender.value)
    }
    
    @IBAction func toggleAlphaSlider(_ sender:UIButton) {
        // toggle the slider
        self.lineAlphaSlider.isHidden = !self.lineAlphaSlider.isHidden
        self.lineWidthSlider.isHidden = true
    }
    
    @IBAction func alphaChange(_ sender:UISlider) {
        self.drawingView.lineAlpha = CGFloat(sender.value)
    }
    
    @IBAction func imageChange(_ sender:UIButton) {
        self.presentOptionsToChooseImageToCustomer()
    }
    
    func presentOptionsToChooseImageToCustomer() {
        let alert = UIAlertController(title: nil, message:FPLocalizationHelper.localize("lbl_Choose_from_options"), preferredStyle:.alert)
        alert.view.backgroundColor = UIColor.white
        alert.view.layer.cornerRadius = 10
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Camera"), style:.default, handler:{ action in
                let imagePicker = UIImagePickerController()
                imagePicker.sourceType =  .camera
                imagePicker.delegate = self
                self.present(imagePicker, animated:true, completion:nil)
            })
            cameraAction.setValue(FPUtility.make("camera"), forKey: "image")
            alert.addAction(cameraAction)
        }
        
        let libraryAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Library"), style:.default, handler:{ action in
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .photoLibrary
            imagePicker.delegate = self
            self.present(imagePicker, animated:true, completion:nil)
        })
        libraryAction.setValue(FPUtility.make("photo.stack"), forKey: "image")
        alert.addAction(libraryAction)
        
        let whiteboardAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_White_Board"), style:.default, handler:{ action in
        })
        whiteboardAction.setValue(FPUtility.make("pencil.and.scribble"), forKey: "image")
        alert.addAction(whiteboardAction)
        
        let cancelAction = UIAlertAction(title: FPLocalizationHelper.localize("Cancel"), style:.cancel, handler:{ _ in})
        alert.addAction(cancelAction)
        alert.applyLegacyActionSheetStyle()
        self.present(alert, animated:true, completion:nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.drawingView.clear()
        self.updateButtonStatus()
        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        self.baseImageView.image = image
        self.drawingView.frame = AVMakeRect(aspectRatio: image.size, insideRect: self.baseImageView.frame)
        self.dismiss(animated: true, completion:nil)
    }
    
}
