(ShopifyOrder as table, ShopifyOrderUnfulfilledTax as table) as table =>
let
    // Load Shopify orders data
    Source = ShopifyOrder,

    // Filter to include only top-level rows
    FilterTopRows = Table.SelectRows(Source, each ([Top Row] = "TRUE")),

    // Keep only relevant columns for calculations and reporting
    SelectRelevantColumns = Table.SelectColumns(FilterTopRows, {
        "Name", "Created At", "Price: Current Subtotal", "Tax 1: Price", 
        "Price: Total Discount", "Price: Total Shipping", "Price: Current Total", 
        "Payment: Status", "Fecha pago", "Factura venta", "Metodo"
    }),

    // Merge with unfulfilled tax table to get additional tax values
    MergeUnfulfilledTaxes = Table.NestedJoin(SelectRelevantColumns, {"Name"}, ShopifyOrderUnfulfilledTax, {"Name"}, "ShopifyOrdersTaxesUnfulfilled", JoinKind.LeftOuter),

    // Expand the merged tax column
    ExpandUnfulfilledTax = Table.ExpandTableColumn(MergeUnfulfilledTaxes, "ShopifyOrdersTaxesUnfulfilled", {"Tax 1 Unfulfilled"}, {"Tax 1 Unfulfilled"}),

    // Keep only rows with valid payment statuses
    FilterPaidOrPartiallyRefunded = Table.SelectRows(ExpandUnfulfilledTax, each ([#"Payment: Status"] = "paid" or [#"Payment: Status"] = "partially_refunded")),

    // Add a custom column for net base value
    AddBaseValueColumn = Table.AddColumn(FilterPaidOrPartiallyRefunded, "Valor base", each List.Sum({
        [#"Price: Current Total"], 
        - [#"Tax 1: Price"], 
        [Tax 1 Unfulfilled]
    }), type number)
in
    AddBaseValueColumn
