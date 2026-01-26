using System;
using System.IO;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    public class DbValidityTests
    {
        [Fact]
        public void Factory_Creates_Valid_Sqlite_Db()
        {
            // Enable repro behavior so factory creates a repo-local DB and preserves it
            Environment.SetEnvironmentVariable("RUN_DB_REPRO", "1");

            using var factory = new USBDeviceManager.Tests.Fixtures.SimRacingTestFactory();
            var path = factory.DbFilePath;
            Assert.False(string.IsNullOrEmpty(path));
            Assert.True(File.Exists(path), $"DB file not found: {path}");

            var buf = new byte[16];
            using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                int n = fs.Read(buf, 0, buf.Length);
                Assert.True(n >= 16, "DB file too small to contain SQLite header");
            }

            var header = System.Text.Encoding.ASCII.GetString(buf);
            Assert.True(header.StartsWith("SQLite format 3\0"), $"Invalid SQLite header: {header}");
        }
    }
}
