//
//  FPAssetFormTableViewController.swift
//  ZenForms
//
//  Read-only view of a compliance form's asset form table (`options.isAssetFormTable`). The server fills the
//  rows live from the asset forms grouped under the compliance form, one row per asset form.
//

import UIKit

final class FPAssetFormTableViewController: UITableViewController {

    private struct Column {
        let name: String
        let header: String
    }

    /// Columns that carry ids for the app, never shown.
    static let hiddenColumnNames: Set<String> = ["fpFormId", "assetId"]

    private let titleText: String?
    private let columns: [Column]
    private let rows: [[String: Any]]
    private let ticketId: NSNumber?
    private let isParentEditable: Bool

    init(field: FPFieldDetails, title: String?, ticketId: NSNumber?, isParentEditable: Bool) {
        self.titleText = title
        self.ticketId = ticketId
        self.isParentEditable = isParentEditable
        let options = field.getOptionsDictionary() ?? [:]
        columns = (options["columns"] as? [[String: Any]] ?? []).compactMap { column in
            guard let name = column["name"] as? String, !Self.hiddenColumnNames.contains(name),
                  (column["uiType"] as? String) != "HIDDEN" else { return nil }
            let header = column["displayName"] as? String
            return Column(name: name, header: header?.isEmpty == false ? header! : name)
        }
        if let data = field.value?.data(using: .utf8),
           let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            rows = parsed
        } else {
            rows = []
        }
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        if rows.isEmpty {
            let label = UILabel()
            label.text = FPLocalizationHelper.localize("msg_no_grouped_asset_forms")
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            label.font = .preferredFont(forTextStyle: .body)
            tableView.backgroundView = label
        }
        tableView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(showFullRow(_:))))
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    /// A missing or null cell shows blank.
    private func text(_ row: [String: Any], _ column: Column) -> String {
        switch row[column.name] {
        case let value as String: return value
        case let value as NSNumber: return value.stringValue
        case nil, is NSNull: return ""
        case let value?: return "\(value)"
        }
    }

    private static func formId(_ row: [String: Any]) -> String? {
        switch row["fpFormId"] {
        case let value as String where !value.isEmpty: return value
        case let value as NSNumber: return value.stringValue
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let row = rows[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        // Every visible column is left-aligned text with its header; long text is cut at 2 lines.
        let lines = columns.map { "\($0.header): \(text(row, $0))" }
        content.text = lines.first
        content.secondaryText = lines.dropFirst().joined(separator: "\n")
        content.textProperties.numberOfLines = 2
        content.secondaryTextProperties.numberOfLines = 2 * max(lines.count - 1, 1)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = Self.formId(row) == nil ? .none : .disclosureIndicator
        return cell
    }

    @objc private func showFullRow(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = tableView.indexPathForRow(at: gesture.location(in: tableView)),
              let row = rows[safe: indexPath.row] else { return }
        let message = columns.map { "\($0.header): \(text(row, $0))" }.joined(separator: "\n\n")
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default))
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let id = rows[safe: indexPath.row].flatMap(Self.formId), let ticketId,
              let open = ZenForms.openAssetForm else { return }
        guard isParentEditable else { open(id, ticketId); return }
        let alert = UIAlertController(title: nil, message: FPLocalizationHelper.localize("msg_open_asset_form_confirm"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in open(id, ticketId) })
        present(alert, animated: true)
    }
}
