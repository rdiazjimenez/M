(tableID as text) =>
let
    Source = SiigoEndPoint,
    #"Filtered Rows" = Table.SelectRows(Source, each ([ID] = tableID)),
    endPointURL = #"Filtered Rows"{0}[endPointURL]
in
    endPointURL