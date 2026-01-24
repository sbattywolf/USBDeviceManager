using System;
using System.Threading;
using System.Threading.Tasks;

class Program
{
    static async Task<int> Main(string[] args)
    {
        Console.WriteLine("LongRunnerDummy starting...");
        int sleepMs = 300_000; // default 5 minutes
        if (args.Length >= 2 && (args[0] == "--sleep" || args[0] == "-s") && int.TryParse(args[1], out var s))
        {
            sleepMs = s * 1000;
        }
        using var cts = new CancellationTokenSource();
        Console.CancelKeyPress += (s, e) =>
        {
            Console.WriteLine("Cancel requested.");
            e.Cancel = true;
            cts.Cancel();
        };
        try
        {
            Console.WriteLine($"Sleeping for {sleepMs}ms");
            await Task.Delay(sleepMs, cts.Token);
            Console.WriteLine("Completed sleep.");
            return 0;
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("Interrupted and exiting with code 2.");
            return 2;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Unhandled exception: {ex}");
            return 3;
        }
    }
}
