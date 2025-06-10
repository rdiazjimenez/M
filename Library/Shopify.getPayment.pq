(ShopifyOrderTop as table, ShopifyOrderTransaction as table) as table =>
let
    // Join top-level orders with their corresponding transactions
    JoinOrdersWithTransactions = Table.NestedJoin(ShopifyOrderTop, {"Name"}, ShopifyOrderTransaction, {"Name"}, "ShopifyOrdersTransaction", JoinKind.LeftOuter),

    // Keep only relevant columns from orders and joined transactions
    SelectRelevantColumns = Table.SelectColumns(JoinOrdersWithTransactions, {
        "Name", "Created At", "Payment: Status", "Fecha pago", "Factura venta", "Metodo", "ShopifyOrdersTransaction"
    }),

    // Expand transaction fields from the joined table
    ExpandTransactionFields = Table.ExpandTableColumn(SelectRelevantColumns, "ShopifyOrdersTransaction", {
        "Transaction: Processed At", "Transaction: Gateway", "Transaction: Shop Currency Amount"
    }, {
        "Transaction: Processed At", "Transaction: Gateway", "Transaction: Shop Currency Amount"
    }),

    // Add actual payment date using Fecha pago or fallback to Transaction date
    AddActualPaymentDate = Table.AddColumn(ExpandTransactionFields, "Fecha pago real", each [Fecha pago] ?? [#"Transaction: Processed At"], type date),

    // Add actual payment method using Metodo or fallback to Transaction Gateway
    AddActualPaymentMethod = Table.AddColumn(AddActualPaymentDate, "Método de pago real", each [Metodo] ?? [#"Transaction: Gateway"], type text),

    // Rename transaction amount column to Valor pago
    RenameTransactionAmount = Table.RenameColumns(AddActualPaymentMethod, {
        {"Transaction: Shop Currency Amount", "Valor pago"}
    }),

    // Keep only final relevant columns
    SelectFinalColumns = Table.SelectColumns(RenameTransactionAmount, {
        "Name", "Payment: Status", "Factura venta", "Fecha pago real", "Método de pago real", "Valor pago"
    }),

    // Rename final columns for clarity
    RenameFinalColumns = Table.RenameColumns(SelectFinalColumns, {
        {"Método de pago real", "Método pago"},
        {"Fecha pago real", "Fecha pago"}
    })
in
    RenameFinalColumns
