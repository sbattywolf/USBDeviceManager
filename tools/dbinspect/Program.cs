using System;
using Microsoft.Data.Sqlite;

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: DbInspect <path-to-db>");
    return 2;
}

var path = args[0];
var connStr = $"Data Source={path};Cache=Shared";
try
{
    using var conn = new SqliteConnection(connStr);
    conn.Open();
    Console.WriteLine($"Opened DB: {path}");

    Console.WriteLine("Tables:");
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;";
        using var rdr = cmd.ExecuteReader();
        while (rdr.Read())
        {
            Console.WriteLine(" - " + rdr.GetString(0));
        }
    }

    Console.WriteLine("\nCreate SQL for tables:");
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;";
        using var rdr = cmd.ExecuteReader();
        while (rdr.Read())
        {
            Console.WriteLine($"-- {rdr.GetString(0)}\n{rdr.GetString(1)}\n");
        }
    }

    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine("ERROR: " + ex);
    return 3;
}