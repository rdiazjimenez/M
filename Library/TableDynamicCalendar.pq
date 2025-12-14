let
    Source = TableInfo,
    start = Table.SelectRows(Source, let earliest = List.Min(Source[Date]) in each [Date] = earliest){0}[Date],
    end = Table.SelectRows(Source, let latest = List.Max(Source[Date]) in each [Date] = latest){0}[Date],
    Result = fnCalendarTable(start, end)
in
    Result
