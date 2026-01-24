using System;
using System.Diagnostics;
using System.IO;

class Program
{
    static int Main(string[] args)
    {
        // Use the same working directory as the CI failure
        var workingDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "server", "USBDeviceManager.Tests", "bin", "Debug", "net8.0"));
        var relative = @".\artifacts\longrunner\win-x64\LongRunner.exe";
        var absolute = Path.GetFullPath(Path.Combine(workingDir, relative));

        Console.WriteLine($"WorkingDirectory: {workingDir}");
        Console.WriteLine($"Relative path: {relative}");
        Console.WriteLine($"Absolute path: {absolute}");

        TryStart("Relative, UseShellExecute=false", relative, workingDir, useShell: false);
        TryStart("Relative, UseShellExecute=true", relative, workingDir, useShell: true);
        TryStart("Absolute, UseShellExecute=false", absolute, workingDir, useShell: false);
        TryStart("Absolute, UseShellExecute=true", absolute, workingDir, useShell: true);

        // also try static Process.Start(string)
        Console.WriteLine("\nStatic Process.Start(file) attempt:");
        try
        {
            var proc = Process.Start(absolute);
            if (proc == null) Console.WriteLine("Process.Start returned null");
            else
            {
                Console.WriteLine("Process.Start returned a process object; waiting 1s...");
                proc.WaitForExit(1000);
                try { Console.WriteLine($"ExitCode: {proc.ExitCode}"); } catch (Exception ex) { Console.WriteLine("Reading ExitCode failed: " + ex.GetType().FullName + ": " + ex.Message); }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Exception: {ex.GetType().FullName}: {ex.Message}");
            Console.WriteLine(ex);
        }

        return 0;
    }

    static void TryStart(string label, string file, string workingDir, bool useShell)
    {
        Console.WriteLine($"\nAttempt: {label}");
        var psi = new ProcessStartInfo
        {
            FileName = file,
            WorkingDirectory = workingDir,
            UseShellExecute = useShell,
            RedirectStandardOutput = !useShell,
            RedirectStandardError = !useShell,
            CreateNoWindow = true
        };

        try
        {
            using var p = Process.Start(psi);
            if (p == null)
            {
                Console.WriteLine("Process.Start returned null");
                return;
            }
            Console.WriteLine("Started process object; waiting 500ms...");
            p.WaitForExit(500);
            try { Console.WriteLine($"ExitCode: {p.ExitCode}"); }
            catch (Exception ex) { Console.WriteLine("Reading ExitCode failed: " + ex.GetType().FullName + ": " + ex.Message); }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Exception: {ex.GetType().FullName}: {ex.Message}");
            Console.WriteLine(ex);
        }
    }
}
