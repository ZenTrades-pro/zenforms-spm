//
//  DatasetColorPickerViewController.swift
//  crm
//
//  Created by apple on 23/02/24.
//  Copyright © 2024 SmartServ. All rights reserved.
//

import UIKit
import SwiftUI

protocol DatasetColorDelegate: AnyObject {
    func datasetColorSelected(color: String, for indexPath: IndexPath)
}

class DatasetColorPickerViewController: UIViewController {

    weak var objcVc: FPChartViewController?
    var fieldItem: FPFieldDetails?
    weak var delegate: DatasetColorDelegate?
    var selectedColor: String?
    var indexPath: IndexPath!

    private var hostingController: UIHostingController<DatasetColorPickerContentView>!
    private var viewSelectedColor: UIView!
    private var availableColors: [String] = []
    private let selectionState = ColorPickerSelectionState()
    private var selectedIndex: Int? {
        get { selectionState.selectedIndex }
        set { selectionState.selectedIndex = newValue }
    }

    var arrChartColors: [String] {
        if let dictChartConts = UserDefaults.dictConstants?["CHART_CONSTANTS"] as? [String: Any] {
            return dictChartConts["lineColors"] as? [String] ?? []
        } else {
            FPFormsServiceManager.getZenFormConstants()
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }

    func setUpView() {
        view.backgroundColor = .systemBackground
        setUpAvailableColors()
        setUpSwatchPreview()
        setUpColorPicker()
        setBarButtons()
    }

    private func setUpSwatchPreview() {
        let swatch = UIView()
        let size: CGFloat = 100
        swatch.layer.cornerRadius = size / 2
        swatch.clipsToBounds = true
        swatch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(swatch)
        NSLayoutConstraint.activate([
            swatch.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            swatch.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swatch.widthAnchor.constraint(equalToConstant: size),
            swatch.heightAnchor.constraint(equalToConstant: size)
        ])
        viewSelectedColor = swatch
        if let selectedColor {
            viewSelectedColor.backgroundColor = FPUtility.colorwithHexString(selectedColor)
        }
    }

    private func setUpColorPicker() {
        let colors = availableColors.map { Color(uiColor: FPUtility.colorwithHexString($0)) }

        let content = DatasetColorPickerContentView(
            colors: colors,
            hexColors: availableColors,
            state: selectionState,
            onSelect: { [weak self] index in
                guard let self, let hex = self.availableColors[safe: index] else { return }
                self.selectedColor = hex
                self.viewSelectedColor.backgroundColor = FPUtility.colorwithHexString(hex)
            }
        )

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .systemBackground
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: viewSelectedColor.bottomAnchor, constant: 16),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    func setUpAvailableColors() {
        var takenColors: [String] = []
        if let dictValue = fieldItem?.value?.getDictonary(), !dictValue.isEmpty,
           let arrDatasets = dictValue["datasets"] as? [[String: Any]] {
            takenColors = arrDatasets.map { $0["borderColor"] as? String ?? "#000000" }
        }
        var available = arrChartColors.filter { !takenColors.contains($0) }
        if let selectedColor {
            available.insert(selectedColor, at: 0)
        }
        availableColors = available

        if let selectedColor {
            selectedIndex = available.firstIndex(where: { $0 == selectedColor })
        } else {
            self.selectedColor = available.first
            selectedIndex = available.indices.first
        }
    }

    // MARK: Nav

    func setBarButtons() {
        let cancelBarButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(DatasetColorPickerViewController.cancelBtnAction))
        let doneButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Done"), style: .plain, target: self, action: #selector(DatasetColorPickerViewController.doneBtnAction))
        self.navigationItem.leftBarButtonItem = cancelBarButton
        self.navigationItem.rightBarButtonItem = doneButton
        self.navigationItem.title = FPLocalizationHelper.localize("SELECT")
    }

    @objc func cancelBtnAction() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func doneBtnAction() {
        if let selectedColor {
            delegate?.datasetColorSelected(color: selectedColor, for: indexPath)
            self.dismiss(animated: true, completion: nil)
        } else {
            _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_chart_select_dataset_color"), completion: nil)
        }
    }
}

extension UIColor {

    func toHex() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            assertionFailure("Failed to get RGBA components from UIColor")
            return "#000000"
        }

        red = max(0, min(1, red))
        green = max(0, min(1, green))
        blue = max(0, min(1, blue))
        alpha = max(0, min(1, alpha))

        if alpha == 1 {
            return String(
                format: "#%02lX%02lX%02lX",
                Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255))
            )
        } else {
            return String(
                format: "#%02lX%02lX%02lX%02lX",
                Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255)),
                Int(round(alpha * 255))
            )
        }
    }
}
