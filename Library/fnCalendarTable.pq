let
    // Definición de la función: toma FechaInicio (Date), FechaFin (Date), y Opcional LocaleText (text)
    fnCalendarTable = (start as date, end as date, optional LocaleText as text) as table =>
    let
        // Set the locale: use the provided value, or default to "en-US" (English)
        CultureLocale = if LocaleText = null then "en-US" else LocaleText,

        // 1. Crear una lista de todas las fechas (días) entre start y end
        DayCount = Duration.Days(end - start) + 1,
        ListDays = List.Generate(
            () => [Date = start, Counter = 0],
            each [Counter] < DayCount,
            each [Date = Date.AddDays([Date], 1), Counter = [Counter] + 1],
            each [Date]
        ),

        // 2. Convertir la lista de fechas en una tabla
        Table_Dates = Table.FromList(
            ListDays, 
            Splitter.SplitByNothing(), 
            {"Date"}, 
            null, 
            ExtraValues.Error
        ),

        // 3. Añadir columnas de atributos del día (using CultureLocale parameter)
        AddColumns_DayAttributes = Table.AddColumn(Table_Dates, "DayOfMonth", each Date.Day([Date]), type number),
            
        AddColumns_DayOfWeek = Table.AddColumn(AddColumns_DayAttributes, "DayOfWeek", each Date.DayOfWeek([Date], Day.Monday), type number),

        AddColumns_DayName = Table.AddColumn(AddColumns_DayOfWeek, "DayName", each 
            Date.ToText([Date], "dddd", CultureLocale), type text), // <--- Uses CultureLocale

        // Atributos mensuales (using CultureLocale parameter)
        AddColumns_YYYYMM = Table.AddColumn(AddColumns_DayName, "YYYYMM", each 
            Text.From(Date.Year([Date])) & Text.PadStart(Text.From(Date.Month([Date])), 2, "0"), type text),
            
        AddColumns_ShortMonth = Table.AddColumn(AddColumns_YYYYMM, "ShortMonth", each 
            Date.ToText([Date], "MMM", CultureLocale), type text), // <--- Uses CultureLocale
            
        AddColumns_Month = Table.AddColumn(AddColumns_ShortMonth, "Month", each 
            Date.ToText([Date], "MMMM", CultureLocale), type text), // <--- Uses CultureLocale
            
        AddColumns_YYYY = Table.AddColumn(AddColumns_Month, "YYYY", each Date.Year([Date]), type number),
            
        AddColumns_YYYYQ = Table.AddColumn(AddColumns_YYYY, "YYYY-Q", each 
            Text.From(Date.Year([Date])) & "-T" & Text.From(Date.QuarterOfYear([Date])), type text),
            
        AddColumns_EndOfMonth = Table.AddColumn(AddColumns_YYYYQ, "EndOfMonth", each Date.EndOfMonth([Date]), type date),
        
        AddColumns_MM = Table.AddColumn(AddColumns_EndOfMonth, "MM", each Text.PadStart(Text.From(Date.Month([Date])), 2, "0"), type text),
        
        AddColumns_M = Table.AddColumn(AddColumns_MM, "M", each Date.Month([Date]), type number),
            
        AddColumns_Q = Table.AddColumn(AddColumns_M, "Q", each Date.QuarterOfYear([Date]), type number),

        AddColumns_StartOfMonth = Table.AddColumn(AddColumns_Q, "StartOfMonth", each Date.StartOfMonth([Date]), type date),

        // 4. Reordenar (Opcional)
        FinalTable = Table.ReorderColumns(AddColumns_StartOfMonth, 
            {"Date", "StartOfMonth", "EndOfMonth", "DayOfMonth", "DayOfWeek", "DayName", "YYYYMM", "YYYY", "MM", "M", "YYYY-Q", "Q", "Month", "ShortMonth"})

    in
        FinalTable
in
    fnCalendarTable
