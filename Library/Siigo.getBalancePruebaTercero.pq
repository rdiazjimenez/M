(filtroBalanceTercero as text, SiigoParamTable as table) =>
let
    token = LibPQ("Siigo.getToken")(SiigoParamTable),
    partnerId =  Table.SelectRows(SiigoParamTable, each ([name] = "partnerId")){0}[value],
    apiHeaders = LibPQ("Api.createApiHeaders")(token, partnerId),
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
    jsonPostParams = Json.Document(postParams),
    startDate = #date(jsonPostParams[year], jsonPostParams[month_start], 1),
    endDate = #date(jsonPostParams[year], jsonPostParams[month_end], 1),
    addDateCol = Table.AddColumn(addColMovDebCre, "Fecha reporte", each Date.ToText(endDate, "yyyy-MM-dd")),
    changeType = Table.TransformColumnTypes(addDateCol,{{"Nivel", type text}, {"Transaccional", type text}, {"Código cuenta contable", type text}, {"Nombre Cuenta contable", type text}, {"Identificación", type text}, {"Sucursal", type text}, {"Nombre tercero", type text}, {"Saldo Inicial", type number}, {"Movimiento Débito", type number}, {"Movimiento Crédito", type number}, {"Saldo final", type number}, {"Fecha reporte", type date}})
in
    changeType
