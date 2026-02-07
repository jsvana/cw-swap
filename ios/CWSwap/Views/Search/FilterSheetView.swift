import SwiftUI

struct FilterSheetView: View {
    @Bindable var viewModel: ListingsViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var priceMinText = ""
    @State private var priceMaxText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("All").tag(nil as ListingCategory?)
                        ForEach(ListingCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.sfSymbol)
                                .tag(category as ListingCategory?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Source") {
                    Picker("Source", selection: $viewModel.selectedSource) {
                        Text("All Sources").tag(nil as ListingSource?)
                        ForEach(ListingSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source as ListingSource?)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Price Range") {
                    HStack {
                        TextField("Min", text: $priceMinText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Text("to")
                        TextField("Max", text: $priceMaxText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    Toggle("Has Photos", isOn: $viewModel.hasPhotoOnly)
                }

                Section("Sort By") {
                    Picker("Sort", selection: $viewModel.sortOption) {
                        ForEach(ListingsViewModel.SortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.clearFilters()
                        priceMinText = ""
                        priceMaxText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.priceMin = Double(priceMinText)
                        viewModel.priceMax = Double(priceMaxText)
                        onApply()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let min = viewModel.priceMin { priceMinText = "\(Int(min))" }
                if let max = viewModel.priceMax { priceMaxText = "\(Int(max))" }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
