// =============================================
// Function: Siigo.getBalancePruebaTercero
// Description:
//   Genera el Balance de prueba por tercero (POST, endpoint "BPT"), descarga el
//   Excel desde file_url y lo devuelve como tabla tipada.
// Parameters:
//   - filtroBalanceTercero (text): body JSON, p. ej.
//       {"year": 2026, "month_start": 1, "month_end": 10, "includes_tax_difference": false}
//     opcionales: "account_start", "account_end"
//   - EndpointData (table): tabla de endpoints
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
// Notes:
//   - month 13 = periodo de cierre; para las columnas de fecha se trata como diciembre.
// History:
//   - 2026-11-17: "Fecha fin" = último día del mes final (antes quedaba el día 1);
//     month_start/month_end = 13 ya no generan error de fecha;
//     no se envían page/page_size a un POST.
//     Versión anterior en OlderVersions/Siigo.getBalancePruebaTercero.20261117.pq
// =============================================

(filtroBalanceTercero as text,
 EndpointData as table,
 ApiConnInfo as any) =>
let
    endpointID = "BPT",
    getParams  = filtroBalanceTercero,

    ApiResult  = LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, endpointID, getParams),
    fileResult = LibPQ("Siigo.getAzureFileFromURL")(ApiResult),
    Sheet = fileResult{[Item = "bal-prueba-por-tercero", Kind = "Sheet"]}[Data],

    removeTopRows    = Table.Skip(Sheet, 4),
    removeBottomRows = Table.RemoveLastN(removeTopRows, 2),
    promoteHeaders   = Table.PromoteHeaders(removeBottomRows, [PromoteAllScalars = true]),
    addColMovDebCre  = Table.AddColumn(promoteHeaders, "MovimientoDebitoCredito",
                           each [Movimiento Débito] - [Movimiento Crédito], type number),

    jsonPostParams = Json.Document(getParams),
    yearNum   = jsonPostParams[year],
    monthFrom = Number.Min({jsonPostParams[month_start], 12}),
    monthTo   = Number.Min({jsonPostParams[month_end], 12}),
    startDate = #date(yearNum, monthFrom, 1),
    endDate   = Date.EndOfMonth(#date(yearNum, monthTo, 1)),

    addDateCol  = Table.AddColumn(addColMovDebCre, "Fecha inicio", each startDate, type date),
    addDateCol2 = Table.AddColumn(addDateCol, "Fecha fin", each endDate, type date),
    changeType  = Table.TransformColumnTypes(addDateCol2, {
        {"Nivel", type text}, {"Transaccional", type text},
        {"Código cuenta contable", type text}, {"Nombre Cuenta contable", type text},
        {"Identificación", type text}, {"Sucursal", type text}, {"Nombre tercero", type text},
        {"Saldo Inicial", type number}, {"Movimiento Débito", type number},
        {"Movimiento Crédito", type number}, {"Saldo final", type number}
    })
in
    changeType
