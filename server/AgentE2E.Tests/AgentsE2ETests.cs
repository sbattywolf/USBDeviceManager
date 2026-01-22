using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

public class AgentsE2ETests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> factory;

    public AgentsE2ETests(WebApplicationFactory<Program> factory)
    {
        this.factory = factory;
    }

    [Fact]
    public async Task Heartbeat_ReturnsOk()
    {
        using var client = factory.CreateClient();
        var id = Guid.NewGuid();
        var res = await client.PostAsync($"/api/agents/{id}/heartbeat", null);
        res.EnsureSuccessStatusCode();
        var s = await res.Content.ReadAsStringAsync();
        Assert.Contains("\"status\":\"ok\"", s);
    }
}
