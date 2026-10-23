import Testing
@testable import ZenForms

private func makeComponent(rows: [[(String, String)]], ids: [[String: Any]]? = nil) -> TableComponent {
    let component = TableComponent()
    component.rows = rows.map { cols in
        Rows(columns: cols.map { ColumnData(key: $0.0, value: $0.1, uiType: "INPUT", dataType: "TEXT", dropDownOptions: nil) })
    }
    component.values = ids
    return component
}

@Test func fingerprintIsStableForUnchangedData() {
    let a = makeComponent(rows: [[("name", "Pump"), ("qty", "2")], [("name", "Valve"), ("qty", "5")]])
    let b = makeComponent(rows: [[("name", "Pump"), ("qty", "2")], [("name", "Valve"), ("qty", "5")]])
    #expect(a.contentFingerprint() == a.contentFingerprint())
    #expect(a.contentFingerprint() == b.contentFingerprint())
}

@Test func fingerprintChangesWhenAnyValueIsEdited() {
    let base = makeComponent(rows: [[("name", "Pump"), ("qty", "2")], [("name", "Valve"), ("qty", "5")]])
    let edited = makeComponent(rows: [[("name", "Pump"), ("qty", "2")], [("name", "Valve"), ("qty", "6")]])
    #expect(base.contentFingerprint() != edited.contentFingerprint())
}

@Test func fingerprintChangesOnEveryKindOfEdit() {
    let base = makeComponent(rows: [[("a", "1"), ("b", "2")], [("a", "3"), ("b", "4")]])
    let fp = base.contentFingerprint()
    // value cleared
    #expect(fp != makeComponent(rows: [[("a", ""), ("b", "2")], [("a", "3"), ("b", "4")]]).contentFingerprint())
    // row added
    #expect(fp != makeComponent(rows: [[("a", "1"), ("b", "2")], [("a", "3"), ("b", "4")], [("a", "", ), ("b", "")]]).contentFingerprint())
    // row deleted
    #expect(fp != makeComponent(rows: [[("a", "1"), ("b", "2")]]).contentFingerprint())
    // rows reordered
    #expect(fp != makeComponent(rows: [[("a", "3"), ("b", "4")], [("a", "1"), ("b", "2")]]).contentFingerprint())
    // value moved to the other column
    #expect(fp != makeComponent(rows: [[("a", "2"), ("b", "1")], [("a", "3"), ("b", "4")]]).contentFingerprint())
    // a value that only differs by whitespace or case
    #expect(fp != makeComponent(rows: [[("a", "1 "), ("b", "2")], [("a", "3"), ("b", "4")]]).contentFingerprint())
    #expect(makeComponent(rows: [[("a", "x")]]).contentFingerprint() != makeComponent(rows: [[("a", "X")]]).contentFingerprint())
}

@Test func fingerprintChangesWhenRowIdentityChanges() {
    let rows = [[("a", "1")], [("a", "2")]]
    let one = makeComponent(rows: rows, ids: [["__localId__": "L1"], ["__localId__": "L2"]])
    let two = makeComponent(rows: rows, ids: [["__localId__": "L1"], ["__localId__": "LX"]])
    let synced = makeComponent(rows: rows, ids: [["__localId__": "L1", "__id__": "99"], ["__localId__": "L2"]])
    #expect(one.contentFingerprint() != two.contentFingerprint())
    #expect(one.contentFingerprint() != synced.contentFingerprint())
}

@Test func fingerprintMatchesWhatTheDraftWouldContain() {
    // Two components that produce the same draft JSON must have the same fingerprint (so a skip loses nothing).
    let a = makeComponent(rows: [[("a", "1"), ("b", "2")]], ids: [["__localId__": "L1"]])
    let b = makeComponent(rows: [[("a", "1"), ("b", "2")]], ids: [["__localId__": "L1"]])
    #expect(a.getValuesObject().getJson() == b.getValuesObject().getJson())
    #expect(a.contentFingerprint() == b.contentFingerprint())
}
