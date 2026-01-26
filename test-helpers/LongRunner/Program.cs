using System;
using System.Threading.Tasks;

class Program
{
    static async Task<int> Main(string[] args)
    {
        int seconds = 30;
        if (args.Length > 0 && int.TryParse(args[0], out var s)) seconds = s;
        if (args.Length > 0 && args[0].StartsWith("--duration="))
        {
            var parts = args[0].Split('=');
            if (parts.Length == 2 && int.TryParse(parts[1], out var s2)) seconds = s2;
        }

        Console.WriteLine($"LongRunner starting for {seconds} seconds");
        try
        {
            await Task.Delay(TimeSpan.FromSeconds(seconds));
            Console.WriteLine("LongRunner completed normally");
            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"LongRunner caught exception: {ex.Message}");
            return 2;
        }
    }
}
