//
//  ZTLoaderButton.swift
//

import UIKit

@objc(ZTLIBLoaderButton)

@MainActor
public final class ZTLIBLoaderButton: UIButton {
    var spinner = UIActivityIndicatorView()
    var isLoading = false {
        didSet {
            // whenever `isLoading` state is changed, update the view
            updateView()
        }
    }
    
    // Weak: callers pass their navigation controller's view, which contains this button.
    // A strong reference made a cycle that kept the whole form view hierarchy alive after closing.
    weak var currentView:UIView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    func setupView() {
        spinner.hidesWhenStopped = true
        // to change spinner color
        spinner.color = self.titleColor(for: .normal)
        // default style
        spinner.style = .medium
        
        // add as button subview
        addSubview(spinner)
        // set constraints to always in the middle of button
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
    
    func updateView() {
        if isLoading {
            spinner.startAnimating()
            titleLabel?.alpha = 0
            imageView?.alpha = 0
            // to prevent multiple click while in process
            isEnabled = false
            currentView?.isUserInteractionEnabled = false
        } else {
            spinner.stopAnimating()
            titleLabel?.alpha = 1
            imageView?.alpha = 1
            isEnabled = true
            currentView?.isUserInteractionEnabled = true
        }
    }
}
