//
//  ZTDropDown.swift
//  ZenFormsLib
//
//  Created by Harshit on 04/11/24.
//


import UIKit
public class ZTDropDown: UITextField {
    var arrow: Arrow!
    var table: UITableView!
    var shadow: UIView!
    public var selectedIndex: Int?

    // MARK: IBInspectable
    @IBInspectable public var rowHeight: CGFloat = 30
    @IBInspectable public var rowBackgroundColor: UIColor = .white
    @IBInspectable public var itemsColor: UIColor = .darkGray
    @IBInspectable public var itemsTintColor: UIColor = .blue
    @IBInspectable public var selectedRowColor: UIColor = .systemPink
    @IBInspectable public var hideOptionsWhenSelect = true
    @IBInspectable public var isSearchEnable: Bool = true {
        didSet {
            addGesture()
        }
    }

    @IBInspectable public var border_Color: UIColor? = UIColor.lightGray {
        didSet {
            layer.borderColor = border_Color?.cgColor
        }
    }

    @IBInspectable public var listHeight: CGFloat = 150 {
        didSet {}
    }

    @IBInspectable public var border_Width: CGFloat = 0.0 {
        didSet {
            layer.borderWidth = border_Width
        }
    }

    @IBInspectable public var corner_Radius: CGFloat = 5.0 {
        didSet {
            layer.cornerRadius = corner_Radius
        }
    }
    
    // Variables
    fileprivate var tableheightX: CGFloat = 100
    fileprivate var dataArray = [String]()
    fileprivate var imageArray = [String]()
    fileprivate weak var mainController: UIViewController?
    fileprivate var pointToParent = CGPoint(x: 0, y: 0)
    fileprivate var backgroundView = UIView()
    fileprivate var keyboardHeight: CGFloat = 0
    
    public var optionArray = [String]() {
        didSet {
            dataArray = optionArray
        }
    }
    
    public var optionImageArray = [String]() {
        didSet {
            imageArray = optionImageArray
        }
    }
    
    public var optionIds: [Int]?
    var searchText = String() {
        didSet {
            if searchText == "" {
                dataArray = optionArray
            } else {
                dataArray = optionArray.filter {
                    searchFilter(text: $0, searchText: searchText)
                }
            }
            reSizeTable()
            selectedIndex = nil
            table.reloadData()
        }
    }
    
    @IBInspectable public var arrowSize: CGFloat = 15 {
        didSet {
            let center = arrow.superview!.center
            arrow.frame = CGRect(x: center.x - arrowSize / 2, y: center.y - arrowSize / 2, width: arrowSize, height: arrowSize)
        }
    }
    
    @IBInspectable public var arrowColor: UIColor = .black {
        didSet {
            arrow.arrowColor = arrowColor
        }
    }
    
    @IBInspectable public var checkMarkEnabled: Bool = true {
        didSet {
        }
    }
    
    @IBInspectable public var handleKeyboard: Bool = true {
        didSet {
        }
    }
    
    // Init
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        delegate = self
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        setupUI()
        delegate = self
    }
    
    // MARK: Closures
    
    fileprivate var didSelectCompletion: (String, Int, Int) -> Void = { _, _, _ in }
    fileprivate var didEndCompletion: (String) -> Void = { _ in }
    fileprivate var TableWillAppearCompletion: () -> Void = { }
    fileprivate var TableDidAppearCompletion: () -> Void = { }
    fileprivate var TableWillDisappearCompletion: () -> Void = { }
    fileprivate var TableDidDisappearCompletion: () -> Void = { }
    
    func setupUI() {
        let size = frame.height
        let arrowView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: size, height: size))
        let arrowContainerView = UIView(frame: arrowView.frame)
        if semanticContentAttribute == .forceRightToLeft {
            leftView = arrowView
            leftViewMode = .always
            leftView?.addSubview(arrowContainerView)
        } else {
            rightView = arrowView
            rightViewMode = .always
            rightView?.addSubview(arrowContainerView)
        }
        
        arrow = Arrow(origin: CGPoint(x: center.x - arrowSize / 2, y: center.y - arrowSize / 2), size: arrowSize)
        arrowContainerView.addSubview(arrow)
        
        backgroundView = UIView(frame: .zero)
        backgroundView.backgroundColor = .clear
        addGesture()
        if isSearchEnable && handleKeyboard {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil) { notification in
                if self.isFirstResponder {
                    let userInfo: NSDictionary = notification.userInfo! as NSDictionary
                    let keyboardFrame: NSValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue
                    let keyboardRectangle = keyboardFrame.cgRectValue
                    self.keyboardHeight = keyboardRectangle.height
                    if !self.isSelected {
                        self.showList()
                    }
                }
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil) { _ in
                if self.isFirstResponder {
                    self.keyboardHeight = 0
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate func addGesture() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(touchAction))
        if isSearchEnable {
            rightView?.addGestureRecognizer(gesture)
        } else {
            addGestureRecognizer(gesture)
        }
        let gesture2 = UITapGestureRecognizer(target: self, action: #selector(touchAction))
        backgroundView.addGestureRecognizer(gesture2)
    }
    
    func getConvertedPoint(_ targetView: UIView, baseView: UIView?) -> CGPoint {
        var pnt = targetView.frame.origin
        if nil == targetView.superview {
            return pnt
        }
        var superView = targetView.superview
        while superView != baseView {
            pnt = superView!.convert(pnt, to: superView!.superview)
            if nil == superView!.superview {
                break
            } else {
                superView = superView!.superview
            }
        }
        return superView!.convert(pnt, to: baseView)
    }
    
    public func showList() {
        if mainController == nil {
            mainController = dropDownViewController
        }
        backgroundView.frame = mainController?.view.frame ?? backgroundView.frame
        pointToParent = getConvertedPoint(self, baseView: mainController?.view)
        mainController?.view.insertSubview(backgroundView, aboveSubview: self)
        TableWillAppearCompletion()
        if listHeight > rowHeight * CGFloat(dataArray.count) {
            tableheightX = rowHeight * CGFloat(dataArray.count)
        } else {
            tableheightX = listHeight
        }
        table = UITableView(frame: CGRect(x: pointToParent.x,
                                          y: pointToParent.y + frame.height,
                                          width: frame.width ,
                                          height: frame.height))
        shadow = UIView(frame: table.frame)
        shadow.backgroundColor = .darkGray
        
        table.dataSource = self
        table.delegate = self
        table.alpha = 0
        table.separatorStyle = .none
        table.layer.cornerRadius = 3
        table.backgroundColor = rowBackgroundColor
        table.rowHeight = rowHeight
        mainController?.view.addSubview(shadow)
        mainController?.view.addSubview(table)
        isSelected = true
        let height = (mainController?.view.frame.height ?? 0) - (pointToParent.y + frame.height + 5)
        var y = pointToParent.y + frame.height + 5
        if height < (keyboardHeight + tableheightX) {
            y = pointToParent.y - tableheightX
        }
        self.table.frame = CGRect(x: self.pointToParent.x,
                                  y: y,
                                  width: self.frame.width ,
                                  height: self.tableheightX)
        self.table.alpha = 1
        self.shadow.frame = self.table.frame
        self.shadow.dropShadow()
        self.arrow.position = .up
        self.layoutIfNeeded()
        
    }
    
    public func hideList() {
        TableWillDisappearCompletion()
        self.table.frame = CGRect(x: self.pointToParent.x,
                                  y: self.pointToParent.y + self.frame.height,
                                  width: self.frame.width ,
                                  height: 0)
        self.shadow.alpha = 0
        self.shadow.frame = self.table.frame
        self.arrow.position = .down
        
        self.shadow.removeFromSuperview()
        self.table.removeFromSuperview()
        self.backgroundView.removeFromSuperview()
        self.isSelected = false
        self.TableDidDisappearCompletion()
    }
    
    @objc public func touchAction() {
        isSelected ? hideList() : showList()
    }
    
    func reSizeTable() {
        if listHeight > rowHeight * CGFloat(dataArray.count) {
            tableheightX = rowHeight * CGFloat(dataArray.count)
        } else {
            tableheightX = listHeight
        }
        let height = (mainController?.view.frame.height ?? 0) - (pointToParent.y + frame.height + 5)
        var y = pointToParent.y + frame.height + 5
        if height < (keyboardHeight + tableheightX) {
            y = pointToParent.y - tableheightX
        }
        self.table.frame = CGRect(x: self.pointToParent.x,
                                  y: y,
                                  width: self.frame.width ,
                                  height: self.tableheightX)
        self.shadow.frame = self.table.frame
        self.shadow.dropShadow()
        //  self.shadow.layer.shadowPath = UIBezierPath(rect: self.table.bounds).cgPath
        self.layoutIfNeeded()
        
    }
    
    // MARK: Filter Methods
    
    open func searchFilter(text: String, searchText: String) -> Bool {
        return text.range(of: searchText, options: .caseInsensitive) != nil
    }

    // MARK: Actions Methods

    public func didSelect(completion: @escaping (_ selectedText: String, _ index: Int, _ id: Int) -> Void) {
        didSelectCompletion = completion
    }

    public func didEndSelect(completion: @escaping (_ selectedText: String) -> Void) {
        didEndCompletion = completion
    }
    
    public func listWillAppear(completion: @escaping () -> Void) {
        TableWillAppearCompletion = completion
    }

    public func listDidAppear(completion: @escaping () -> Void) {
        TableDidAppearCompletion = completion
    }

    public func listWillDisappear(completion: @escaping () -> Void) {
        TableWillDisappearCompletion = completion
    }

    public func listDidDisappear(completion: @escaping () -> Void) {
        TableDidDisappearCompletion = completion
    }
}

// MARK: UITextFieldDelegate

extension ZTDropDown: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        superview?.endEditing(true)
        return false
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
//        textField.text = ""
        // self.selectedIndex = nil
        dataArray = optionArray
        touchAction()
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return isSearchEnable
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string != "" {
            searchText = text! + string
        } else {
            let subText = text?.dropLast()
            searchText = String(subText!)
        }
        if !isSelected {
            showList()
        }
        return true
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        didEndCompletion(textField.text ?? "")
    }
    
}

// MARK: UITableViewDataSource

extension ZTDropDown: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "DropDownCell"

        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)

        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
        }

        if indexPath.row != selectedIndex {
            cell!.backgroundColor = rowBackgroundColor
        } else {
            cell?.backgroundColor = selectedRowColor
        }
        
        if imageArray.count > indexPath.row {
            cell!.imageView!.image = UIImage(named: imageArray[indexPath.row])
        }
        cell!.textLabel!.text = "\(dataArray[indexPath.row])"
        cell!.textLabel!.textColor = itemsColor
        cell!.tintColor = itemsTintColor
        cell!.accessoryType = (indexPath.row == selectedIndex) && checkMarkEnabled ? .checkmark : .none
        cell!.selectionStyle = .none
        cell?.textLabel?.font = font
        cell?.textLabel?.textAlignment = textAlignment
        cell?.textLabel?.numberOfLines = 0
        cell?.textLabel?.lineBreakMode = .byWordWrapping
        return cell!
    }
}

// MARK: UITableViewDelegate

extension ZTDropDown: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let currentIndex = (indexPath as NSIndexPath).row
        let selectedText = dataArray[currentIndex]
        selectedIndex = isSearchEnable ? (optionArray.firstIndex(of: selectedText) ?? currentIndex) : currentIndex // Correct Index For Searched Text
        
        tableView.cellForRow(at: indexPath)?.alpha = 0
        tableView.cellForRow(at: indexPath)?.alpha = 1.0
        tableView.cellForRow(at: indexPath)?.backgroundColor = self.selectedRowColor
        self.text = "\(selectedText)"
        
        tableView.reloadData()
        if hideOptionsWhenSelect {
            touchAction()
            endEditing(true)
        }
        if let selected = optionArray.firstIndex(where: { $0 == selectedText }) {
            if let id = optionIds?[selected] {
                didSelectCompletion(selectedText, selected, id)
            } else {
                didSelectCompletion(selectedText, selected, 0)
            }
        }
    }
}

// MARK: Arrow

enum Position {
    case left
    case down
    case right
    case up
}

class Arrow: UIView {
    let shapeLayer = CAShapeLayer()
    var arrowColor: UIColor = .black {
        didSet {
            shapeLayer.fillColor = arrowColor.cgColor
        }
    }
    
    var position: Position = .down {
        didSet {
            switch position {
            case .left:
                transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
                break
                
            case .down:
                transform = CGAffineTransform(rotationAngle: CGFloat.pi * 2)
                break
                
            case .right:
                transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
                break
                
            case .up:
                transform = CGAffineTransform(rotationAngle: CGFloat.pi)
                break
            }
        }
    }
    
    init(origin: CGPoint, size: CGFloat) {
        super.init(frame: CGRect(x: origin.x, y: origin.y, width: size, height: size))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        // Get size
        let size = layer.frame.width
        
        // Create path
        let bezierPath = UIBezierPath()
        
        // Draw points
        let qSize = size / 4
        
        bezierPath.move(to: CGPoint(x: 0, y: qSize))
        bezierPath.addLine(to: CGPoint(x: size, y: qSize))
        bezierPath.addLine(to: CGPoint(x: size / 2, y: qSize * 3))
        bezierPath.addLine(to: CGPoint(x: 0, y: qSize))
        bezierPath.close()
        
        // Mask to path
        shapeLayer.path = bezierPath.cgPath
        //  shapeLayer.fillColor = arrowColor.cgColor
        
        self.layer.addSublayer(shapeLayer)
    }
}

extension UIView {
    func dropShadow(scale: Bool = true) {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 1, height: 1)
        layer.shadowRadius = 2
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
    
    func viewBorder(borderColor: UIColor, borderWidth: CGFloat?) {
        layer.borderColor = borderColor.cgColor
        if let borderWidth_ = borderWidth {
            layer.borderWidth = borderWidth_
        } else {
            layer.borderWidth = 1.0
        }
    }
    
    var dropDownViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}
