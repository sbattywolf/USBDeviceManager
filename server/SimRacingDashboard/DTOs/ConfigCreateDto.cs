namespace SimRacingDashboard.DTOs;

public class ConfigCreateDto
{
    public string? deviceId { get; set; }
    public string? friendlyName { get; set; }
    public string? usbPort { get; set; }
    public string? vendorId { get; set; }
    public string? productId { get; set; }

    // Software/run settings
    public string? triggerPath { get; set; }
    public string? softwareName { get; set; }
    public string? triggerParams { get; set; }
    public string? workingDirectory { get; set; }

    public bool? isEnabled { get; set; }
}
