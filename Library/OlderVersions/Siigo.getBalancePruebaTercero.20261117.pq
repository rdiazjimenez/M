(filtroBalanceTercero as text,
 EndpointData as table,
 ApiConnInfo as table) =>
let
    endpointID = "BPT",
    getParams = filtroBalanceTercero,
    pageSize = "100",

    // Call the function with the parameters
    ApiResult = LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams, "1", pageSize),
    fileResult = LibPQ("Siigo.getAzureFileFromURL")(ApiResult),
    Sheet = fileResult{[Item="bal-prueba-por-tercero",Kind="Sheet"]}[Data],
    DateText = Sheet{3}[Column1],
    removeTopRows = Table.Skip(Sheet,4),
    removeBottomRows = Table.RemoveLastN(removeTopRows,2),
    promoteHeaders = Table.PromoteHeaders(removeBottomRows, [PromoteAllScalars=true]),
    addColMovDebCre = Table.AddColumn(promoteHeaders, "MovimientoDebitoCredito", each [Movimiento Débito] - [Movimiento Crédito], type number),
    jsonPostParams = Json.Document(getParams),
    startDate = #date(jsonPostParams[year], jsonPostParams[month_start], 1),
    endDate = #date(jsonPostParams[year], jsonPostParams[month_end], 1),
    addDateCol = Table.AddColumn(addColMovDebCre, "Fecha inicio", each Date.ToText(startDate, "yyyy-MM-dd")),
    addDateCol2 = Table.AddColumn(addDateCol, "Fecha fin", each Date.ToText(endDate, "yyyy-MM-dd")),
    changeType = Table.TransformColumnTypes(addDateCol2,{{"Nivel", type text}, {"Transaccional", type text}, {"Código cuenta contable", type text}, {"Nombre Cuenta contable", type text}, {"Identificación", type text}, {"Sucursal", type text}, {"Nombre tercero", type text}, {"Saldo Inicial", type number}, {"Movimiento Débito", type number}, {"Movimiento Crédito", type number}, {"Saldo final", type number}, {"Fecha inicio", type date}, {"Fecha fin", type date}})
in
    changeType
