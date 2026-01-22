using System;
using System.Threading;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("SmokeApp started");
        try
        {
            // Keep running for a short while so Stop can find and kill the process
            Thread.Sleep(60000);
        }
        catch (Exception)
        {
        }
    }
}
