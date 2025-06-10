(ShopifyOrder as table) as table =>
let
    // Load Shopify orders data
    Source = ShopifyOrder,

    // Keep only rows where the line type is "Transaction"
    FilterTransactionLines = Table.SelectRows(Source, each ([#"Line: Type"] = "Transaction")),

    // Keep only relevant transaction columns
    SelectTransactionColumns = Table.SelectColumns(FilterTransactionLines, {
        "Name", 
        "Transaction: Processed At", 
        "Transaction: Currency", 
        "Transaction: Shop Currency Amount", 
        "Transaction: Status", 
        "Transaction: Gateway"
    }),

    // Keep only successful transactions
    FilterSuccessfulTransactions = Table.SelectRows(SelectTransactionColumns, each ([#"Transaction: Status"] = "success")),

    // Keep only final required columns
    SelectFinalColumns = Table.SelectColumns(FilterSuccessfulTransactions, {
        "Name", 
        "Transaction: Processed At", 
        "Transaction: Gateway", 
        "Transaction: Shop Currency Amount"
    })
in
    SelectFinalColumns
