let
    // Definición de la función: toma FechaInicio (Date) y FechaFin (Date)
    fnCalendarTable = (start as date, end as date) as table =>
    let
        // 1. Crear una lista de fechas que inician en el primer día de cada mes.
        // Se calcula la diferencia en meses y se genera una lista de índices.
        StartDate = Date.StartOfMonth(start),
        EndDate = Date.StartOfMonth(end),
        MonthCount = ((Date.Year(EndDate) - Date.Year(StartDate)) * 12) + (Date.Month(EndDate) - Date.Month(StartDate)) + 1,

        ListPeriods = List.Generate(
            () => [Date = StartDate, Counter = 0],
            each [Counter] < MonthCount,
            each [Date = Date.AddMonths([Date], 1), Counter = [Counter] + 1],
            each [Date]
        ),

        // 2. Convertir la lista de fechas al inicio de mes en una tabla
        Table_StartOfMonths = Table.FromList(
            ListPeriods, 
            Splitter.SplitByNothing(), 
            {"Date"}, 
            null, 
            ExtraValues.Error
        ),

        // 3. Añadir columnas de atributos del período
        AddPeriodAttributes = Table.TransformColumns(
            Table_StartOfMonths, 
            {{"Date", each Date.StartOfMonth(_), type date}}
        ),

        AddColumns = Table.AddColumn(AddPeriodAttributes, "YYYYMM", each 
            Text.From(Date.Year([Date])) & Text.PadStart(Text.From(Date.Month([Date])), 2, "0"), type text),
            
        AddColumns1 = Table.AddColumn(AddColumns, "ShortMonth", each 
            Date.ToText([Date], "MMM", "es-ES"), type text),
            
        AddColumns2 = Table.AddColumn(AddColumns1, "Month", each 
            Date.ToText([Date], "MMMM", "es-ES"), type text),
            
        AddColumns3 = Table.AddColumn(AddColumns2, "Year", each 
            Date.Year([Date]), type number),
            
        AddColumns4 = Table.AddColumn(AddColumns3, "Quarter", each 
            Text.From(Date.Year([Date])) & "-T" & Text.From(Date.QuarterOfYear([Date])), type text),
            
        AddColumns5 = Table.AddColumn(AddColumns4, "EndOfMonth", each 
            Date.EndOfMonth([Date]), type date),

        // 4. Reordenar y renombrar (Opcional)
        FinalTable = Table.ReorderColumns(AddColumns5, 
            {"Date", "EndOfMonth", "YYYYMM", "Year", "Quarter", "Month", "ShortMonth"})

    in
        FinalTable
in
    fnCalendarTable
