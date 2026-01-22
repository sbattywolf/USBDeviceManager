namespace USBDeviceManager.Services
{
    public class ServiceConfig
    {
        public int ServerPort { get; set; } = 5000;
        public int AgentPort { get; set; } = 5001;
        public bool AutostartServer { get; set; } = false;
        public bool AutostartAgent { get; set; } = false;
        // Agent mode: "External" means an external agent will connect to this server.
        // "Embedded" means the server may launch and host an agent process as a child.
        // "Disabled" prevents the server from starting or hosting an agent.
        public string AgentMode { get; set; } = "External";
    }
}
