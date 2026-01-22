using System;
using System.Windows.Forms;

namespace WinFormsWebView2
{
    internal static class Program
    {
        [STAThread]
        static void Main()
        {
            ApplicationConfiguration.Initialize();
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            using var form = new MainForm();
            Application.Run(form);
        }
    }
}
