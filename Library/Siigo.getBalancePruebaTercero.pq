// =============================================
// Function: Siigo.getBalancePruebaTercero
// Description:
//   Genera el Balance de prueba por tercero (POST, endpoint "BPT"), descarga el
//   Excel desde file_url y lo devuelve como tabla tipada.
//   Opcionalmente, algunas cuentas se devuelven SIN tercero (consolidadas por cuenta).
// Parameters:
//   - filtroBalanceTercero (text): body JSON, p. ej.
//       {"year": 2026, "month_start": 1, "month_end": 10, "includes_tax_difference": false}
//     opcionales: "account_start", "account_end"
//   - EndpointData (table): tabla de endpoints
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
//   - CuentasSinTercero (list | text, opcional): prefijos de cuenta que se devuelven
//     sin tercero, p. ej. {"4"} o "4,5,6". "*" = todo el balance sin tercero.
//     Si se omite, el resultado es el de siempre (todo con tercero).
// Notes:
//   - month 13 = periodo de cierre; para las columnas de fecha se trata como diciembre.
//   - Siempre es UNA sola llamada a Siigo. Las cuentas sin tercero se consolidan
//     localmente (suma por cuenta); Identificación, Sucursal y Nombre tercero van en null.
//     Si una cuenta trae una fila propia sin tercero (subtotal), se usa esa fila y no
//     se suman los terceros, para no duplicar.
//   - Pedir a Siigo varios reportes por mes (balance general + rangos por tercero)
//     resultó más lento que un solo reporte: el tiempo lo pone la generación del
//     archivo en Siigo, no su tamaño. Esa versión está en
//     OlderVersions/Siigo.getBalancePruebaTercero.20261117c.pq
// History:
//   - 2026-11-17 (c): CuentasSinTercero se resuelve con una sola llamada y
//     consolidación local. Versión anterior en OlderVersions/...20261117c.pq
//   - 2026-11-17 (b): parámetro opcional CuentasSinTercero.
//     Versión anterior en OlderVersions/Siigo.getBalancePruebaTercero.20261117b.pq
//   - 2026-11-17: "Fecha fin" = último día del mes final (antes quedaba el día 1);
//     month_start/month_end = 13 ya no generan error de fecha;
//     no se envían page/page_size a un POST.
//     Versión anterior en OlderVersions/Siigo.getBalancePruebaTercero.20261117.pq
// =============================================

(filtroBalanceTercero as text,
 EndpointData as table,
 ApiConnInfo as any,
 optional CuentasSinTercero as any) =>
let
    // ---------- Reporte por tercero (una llamada) ----------
    ApiResult  = LibPQ("Siigo.getApiData")(EndpointData, ApiConnInfo, "BPT", filtroBalanceTercero),
    fileResult = LibPQ("Siigo.getAzureFileFromURL")(ApiResult),
    Sheet      = fileResult{[Item = "bal-prueba-por-tercero", Kind = "Sheet"]}[Data],

    removeTopRows    = Table.Skip(Sheet, 4),
    removeBottomRows = Table.RemoveLastN(removeTopRows, 2),
    promoteHeaders   = Table.PromoteHeaders(removeBottomRows, [PromoteAllScalars = true]),
    addColMovDebCre  = Table.AddColumn(promoteHeaders, "MovimientoDebitoCredito",
                           each [Movimiento Débito] - [Movimiento Crédito], type number),

    filtro    = Json.Document(filtroBalanceTercero),
    yearNum   = filtro[year],
    monthFrom = List.Min({filtro[month_start], 12}),
    monthTo   = List.Min({filtro[month_end], 12}),
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
    }),

    // ---------- Opción CuentasSinTercero: consolidación local ----------
    prefijosRaw = if CuentasSinTercero = null then {}
                  else if CuentasSinTercero is text then Text.Split(CuentasSinTercero, ",")
                  else CuentasSinTercero,
    prefijos    = List.Select(List.Transform(prefijosRaw, each Text.Trim(Text.From(_))), each _ <> ""),
    todas       = List.Contains(prefijos, "*"),

    esSinTercero = (codigo) => todas or (codigo <> null and
        List.AnyTrue(List.Transform(prefijos, (p) => Text.StartsWith(Text.Trim(Text.From(codigo)), p)))),

    sumas  = {"Saldo Inicial", "Movimiento Débito", "Movimiento Crédito", "Saldo final", "MovimientoDebitoCredito"},
    llaves = {"Nivel", "Transaccional", "Código cuenta contable", "Nombre Cuenta contable", "Fecha inicio", "Fecha fin"},

    consolidar = (t as table) as table =>
        let
            agrupada = Table.Group(t, llaves, {{"g", (g) =>
                let
                    sinIdent = Table.SelectRows(g, each [Identificación] = null or Text.Trim([Identificación]) = ""),
                    base     = if Table.RowCount(sinIdent) > 0 then sinIdent else g
                in
                    Record.FromList(List.Transform(sumas, each List.Sum(Table.Column(base, _))), sumas)}}),
            expandida = Table.ExpandRecordColumn(agrupada, "g", sumas),
            conNull   = Table.AddColumn(Table.AddColumn(Table.AddColumn(expandida,
                            "Identificación", each null, type text),
                            "Sucursal", each null, type text),
                            "Nombre tercero", each null, type text)
        in
            Table.TransformColumnTypes(conNull, List.Transform(sumas, each {_, type number})),

    resultado =
        if List.Count(prefijos) = 0 then changeType
        else
            let
                buf   = Table.Buffer(changeType),
                resto = Table.SelectRows(buf, each not esSinTercero([Código cuenta contable])),
                sinT  = consolidar(Table.SelectRows(buf, each esSinTercero([Código cuenta contable])))
            in
                Table.SelectColumns(Table.Combine({resto, sinT}), Table.ColumnNames(changeType))
in
    resultado
