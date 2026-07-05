import SwiftUI
import SwiftData

/// Inventaire des proies : quantités, seuil d'alerte, ajustement rapide.
/// Le stock est décrémenté automatiquement à chaque nourrissage enregistré
/// avec le type correspondant.
struct PreyStockView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<PreyStock>(\.typeRawValue)]) private var stocks: [PreyStock]
    @Query(sort: [SortDescriptor<CustomPreyType>(\.name)]) private var customPreyTypes: [CustomPreyType]
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if stocks.isEmpty {
                ContentUnavailableView(
                    "Aucun stock suivi",
                    systemImage: "shippingbox",
                    description: Text("Ajoute un type de proie avec le bouton + : il sera décompté automatiquement à chaque nourrissage.")
                )
            } else {
                ForEach(stocks) { stock in
                    HStack(spacing: 12) {
                        Image(systemName: stock.isLow ? "exclamationmark.triangle.fill" : "shippingbox.fill")
                            .foregroundStyle(stock.isLow ? Brand.warning : Brand.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stock.displayName)
                                .font(.headline)
                            Text(stock.isLow ? "Stock bas (seuil \(stock.lowThreshold))" : "Seuil d'alerte : \(stock.lowThreshold)")
                                .font(.caption)
                                .foregroundStyle(stock.isLow ? Brand.warning : Color.secondary)
                        }
                        Spacer()
                        Stepper(value: Binding(
                            get: { stock.quantity },
                            set: { newValue in
                                stock.quantity = max(0, newValue)
                                stock.updatedAt = .now
                                try? context.save()
                            }
                        ), in: 0...9999) {
                            Text("\(stock.quantity)")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                        .fixedSize()
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(stocks[index])
                    }
                    try? context.save()
                }
            }
        }
        .navigationTitle("Stock de proies")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPreyStockView(existingTypeRawValues: Set(stocks.map(\.typeRawValue)),
                             customPreyTypeNames: customPreyTypes.map(\.name))
        }
    }
}

struct AddPreyStockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existingTypeRawValues: Set<String>
    let customPreyTypeNames: [String]

    @State private var selectedType: String = PreyType.drosophile.rawValue
    @State private var quantity = 20
    @State private var lowThreshold = 5

    /// Types proposables : proies standard + types personnalisés, sans ceux déjà suivis.
    private var availableTypes: [(rawValue: String, label: String)] {
        let standard = PreyType.allCases
            .filter { $0 != .other }
            .map { (rawValue: $0.rawValue, label: $0.displayName) }
        let custom = customPreyTypeNames.map { (rawValue: $0, label: $0) }
        return (standard + custom).filter { !existingTypeRawValues.contains($0.rawValue) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type de proie", selection: $selectedType) {
                    ForEach(availableTypes, id: \.rawValue) { type in
                        Text(type.label).tag(type.rawValue)
                    }
                }
                Stepper("Quantité : \(quantity)", value: $quantity, in: 0...9999)
                Stepper("Seuil d'alerte : \(lowThreshold)", value: $lowThreshold, in: 1...999)
            }
            .navigationTitle("Suivre un stock")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let first = availableTypes.first {
                    selectedType = first.rawValue
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") {
                        context.insert(PreyStock(
                            typeRawValue: selectedType,
                            quantity: quantity,
                            lowThreshold: lowThreshold
                        ))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(availableTypes.isEmpty)
                }
            }
        }
    }
}
