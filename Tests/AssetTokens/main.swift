import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
var checks = 0
func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
    checks += 1
}
for name in ["asset-auto-populate-token-spec", "inspection-schedule-token-spec"] {
    let data = try Data(contentsOf: root.appendingPathComponent(name + ".json"))
    let fixture = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    for item in fixture["cases"] as! [[String: Any]] {
        let id = item["id"] as! String
        for zoneName in ["UTC", "Asia/Kolkata", "America/Los_Angeles"] {
            let asset = item["asset"] as! [String: Any]
            let expected = item["expected"] as! [String: Any]
            let tokens: [String: [String: String]]
            if name.hasPrefix("asset-") {
                let zone = TimeZone(identifier: item["timeZone"] as? String ?? zoneName)!
                tokens = FPAssetTokens.build(FPAssetTokenContext(asset: asset, assetType: item["assetType"] as? [String: Any]), timeZone: zone)
                for source in ["ASSET", "ASSET_CUSTOM_FIELD"] {
                    check(tokens[source] == expected[source] as? [String: String], "\(id) \(zoneName) \(source): \(tokens[source]!) != \(expected[source]!)")
                }
            } else {
                let values = FPAssetTokens.schedules(asset: asset, ticketAsset: item["ticketAsset"] as! [String: Any], today: item["today"] as! String)
                check(values == expected as? [String: String], "\(id): \(values) != \(expected)")
                tokens = ["INSPECTION_SCHEDULE": values]
            }
            for lookup in item["lookups"] as? [[String: String]] ?? [] {
                check(FPAssetTokens.lookup(tokens, source: lookup["entityType"]!, entity: lookup["entity"]!) == lookup["value"]!, "\(id): lookup \(lookup)")
            }
        }
    }
}
print("Asset/schedule fixtures passed: \(checks) assertions across 3 time zones")

let normal = FPAssetTokens.build(FPAssetTokenContext(asset: ["serialNumber": "AB 12", "customFieldValues": [["name": " Rated_Flow ", "uiType": "INPUT", "dataType": "NUMBER", "value": 0]]]))
check(FPAssetTokens.lookup(normal, source: "ASSET_CUSTOM_FIELD", entity: " RATED_FLOW ") == "0", "Custom names normalize whitespace and case")
check(FPAssetTokens.lookup(normal, source: "ASSET", entity: "SERIALNUMBER").isEmpty, "Asset keys remain case sensitive")
check(FPAssetTokens.lookup(normal, source: "UNKNOWN", entity: "serialNumber").isEmpty, "Unknown source is safe")
check(FPAssetTokens.build(FPAssetTokenContext(asset: [:]))["INSPECTION_SCHEDULE"] == [:], "New offline asset has no schedule dates")
for frequency: Any in [0, -1, 1.5, "invalid", NSNull()] {
    let asset: [String: Any] = ["inspectionDates": ["bySchedule": [["scheduleId": 1, "status": "ACTIVE"]]]]
    let visit: [String: Any] = ["inspectionSchedules": [["inspectionScheduleId": 1, "status": "ACTIVE", "frequencyUnit": "MONTHLY", "frequencyValue": frequency, "recurrenceType": "ROLLING"]]]
    let result = FPAssetTokens.schedules(asset: asset, ticketAsset: visit, today: "2024-01-31")
    check(result["inspectionSchedule.1.next"] == "02/29/2024", "Invalid frequency defaults to one")
}
print("Additional edge cases passed; total assertions: \(checks)")
