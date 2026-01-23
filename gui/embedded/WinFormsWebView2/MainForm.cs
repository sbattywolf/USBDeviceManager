using Microsoft.Web.WebView2.Core;
using System;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace WinFormsWebView2
{
    public partial class MainForm : Form
    {
        public MainForm()
        {
            InitializeComponent();
        }

        protected override async void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            try
            {
                await InitializeWebViewAsync();
                // Navigate to server preview page (server should be started separately)
                webView21.CoreWebView2.Navigate("http://localhost:5000/preview/index.html");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"WebView initialization failed: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private async Task InitializeWebViewAsync()
        {
            if (webView21.CoreWebView2 == null)
            {
                var env = await CoreWebView2Environment.CreateAsync();
                await webView21.EnsureCoreWebView2Async(env);
            }
        }
    }
}
