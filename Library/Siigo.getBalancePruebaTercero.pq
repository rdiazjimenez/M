(filtroBalanceTercero as text) =>
let
    apiHeaders = LibPQ("Api.createApiHeaders")(getToken, paramSiigoApiPartnerId),
    queryTableID = "BPT",
    getParams = null,
    postParams = filtroBalanceTercero,
    pageNum = null,
    pageSize = null,
    endpointData = LibPQ("Siigo.getEndpointData")(queryTableID),
    apiResult = LibPQ("Api.getApiResult")(endpointData[endpointURL], endpointData[Type], apiHeaders, getParams, pageNum, pageSize, postParams),
    fileResult = LibPQ("Siigo.getAzureFileFromURL")(apiResult),
    Sheet = fileResult{[Item="bal-prueba-por-tercero",Kind="Sheet"]}[Data],
    DateText = Sheet{3}[Column1],
    removeTopRows = Table.Skip(Sheet,4),
    removeBottomRows = Table.RemoveLastN(removeTopRows,2),
    promoteHeaders = Table.PromoteHeaders(removeBottomRows, [PromoteAllScalars=true]),
    addColMovDebCre = Table.AddColumn(promoteHeaders, "MovimientoDebitoCredito", each [Movimiento Débito] - [Movimiento Crédito], type number),
    addDateCol = Table.AddColumn(addColMovDebCre, "Fecha reporte", each Date.ToText(fechaInicio, "yyyy-MM-dd")),
    changeType = Table.TransformColumnTypes(addDateCol,{{"Nivel", type text}, {"Transaccional", type text}, {"Código cuenta contable", type text}, {"Nombre Cuenta contable", type text}, {"Identificación", type text}, {"Sucursal", type text}, {"Nombre tercero", type text}, {"Saldo Inicial", type number}, {"Movimiento Débito", type number}, {"Movimiento Crédito", type number}, {"Saldo final", type number}, {"Fecha reporte", type date}})
in
    changeType
