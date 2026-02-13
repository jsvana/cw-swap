import SwiftUI

struct AlertFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var keyword: String
    @State private var selectedCategory: ListingCategory?
    @State private var selectedSource: ListingSource?
    @State private var priceMinText: String
    @State private var priceMaxText: String

    private let isEditing: Bool
    private let onSave: (String, String, ListingCategory?, ListingSource?, Double?, Double?) -> Void

    init(
        existingAlert: TriggerAlert? = nil,
        onSave: @escaping (String, String, ListingCategory?, ListingSource?, Double?, Double?) -> Void
    ) {
        self.isEditing = existingAlert != nil
        self.onSave = onSave
        _name = State(initialValue: existingAlert?.name ?? "")
        _keyword = State(initialValue: existingAlert?.keyword ?? "")
        _selectedCategory = State(initialValue: existingAlert?.listingCategory)
        _selectedSource = State(initialValue: existingAlert?.listingSource)
        _priceMinText = State(initialValue: existingAlert?.priceMin.map { String(Int($0)) } ?? "")
        _priceMaxText = State(initialValue: existingAlert?.priceMax.map { String(Int($0)) } ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Alert Name") {
                TextField("e.g. Icom IC-7300 under $900", text: $name)
            }

            Section("Filters") {
                TextField("Keyword (optional)", text: $keyword)
                    .autocorrectionDisabled()

                Picker("Category", selection: $selectedCategory) {
                    Text("Any").tag(ListingCategory?.none)
                    ForEach(ListingCategory.allCases) { category in
                        Text(category.displayName).tag(ListingCategory?.some(category))
                    }
                }

                Picker("Source", selection: $selectedSource) {
                    Text("Any").tag(ListingSource?.none)
                    ForEach(ListingSource.allCases, id: \.self) { source in
                        Text(source.displayName).tag(ListingSource?.some(source))
                    }
                }
            }

            Section {
                HStack {
                    TextField("Min", text: $priceMinText)
                        .keyboardType(.numberPad)
                    Text("to")
                        .foregroundStyle(.secondary)
                    TextField("Max", text: $priceMaxText)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("Price Range")
            } footer: {
                Text("Leave blank for no price filter.")
            }
        }
        .navigationTitle(isEditing ? "Edit Alert" : "New Alert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let priceMin = Double(priceMinText)
                    let priceMax = Double(priceMaxText)
                    onSave(
                        name.trimmingCharacters(in: .whitespaces),
                        keyword.trimmingCharacters(in: .whitespaces),
                        selectedCategory,
                        selectedSource,
                        priceMin,
                        priceMax
                    )
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}
