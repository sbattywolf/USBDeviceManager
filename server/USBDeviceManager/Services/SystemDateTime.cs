using System;

namespace USBDeviceManager.Services
{
    /// <summary>
    /// Production implementation of <see cref="IDateTime"/>.
    /// </summary>
    public class SystemDateTime : IDateTime
    {
        public DateTime UtcNow => DateTime.UtcNow;
        public DateTime Now => DateTime.Now;
    }
}
