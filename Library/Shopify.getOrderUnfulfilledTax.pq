(ShopifyOrder as table) as table =>
let
    // Load Shopify orders data
    Source = ShopifyOrder,

    // Filter rows where the line has no fulfillment status
    FilterUnfulfilledLines = Table.SelectRows(Source, each ([#"Line: Fulfillment Status"] = null)),

    // Group by order name and sum the tax amount for unfulfilled lines
    GroupAndSumTax = Table.Group(FilterUnfulfilledLines, {"Name"}, {
        {"Tax 1 Price Sum", each List.Sum([#"Line: Tax 1 Price"]), type nullable number}
    }),

    // Remove rows with null, 0, or empty tax values
    FilterNonZeroTax = Table.SelectRows(GroupAndSumTax, each ([Tax 1 Price Sum] <> null and [Tax 1 Price Sum] <> 0 and [Tax 1 Price Sum] <> "")),

    // Rename summed column to indicate it's from unfulfilled lines
    RenameTaxColumn = Table.RenameColumns(FilterNonZeroTax, {{"Tax 1 Price Sum", "Tax 1 Unfulfilled"}})
in
    RenameTaxColumn
