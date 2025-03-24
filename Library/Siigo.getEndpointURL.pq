(tableID as text) =>
let
    Source = SiigoEndPoint,
    #"Filtered Rows" = Table.SelectRows(Source, each ([ID] = tableID)),
    endPointURL = try #"Filtered Rows"{0}[endPointURL] otherwise "No se encontró la URL del endpoint"
in
    endPointURL