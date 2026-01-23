using Microsoft.AspNetCore.Mvc;
using USBDeviceManager.Controllers;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    public class AgentControllerTests
    {
        [Fact]
        public void Download_Returns_Ok_With_Message()
        {
            var controller = new AgentController();
            var res = controller.Download() as OkObjectResult;
            Assert.NotNull(res);
            Assert.Equal(200, res.StatusCode);
            Assert.Contains("agent download", res.Value.ToString());
        }
    }
}
