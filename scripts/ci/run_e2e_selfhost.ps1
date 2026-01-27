New-Item -ItemType Directory -Force -Path .\artifacts\test-results | Out-Null

# Build (no restore; restore handled earlier)
dotnet build server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Release --no-restore

# Run tests and write TRX into artifacts/test-results
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Debug --logger "trx;LogFileName=AgentE2E.selfhost.trx" --results-directory .\artifacts\test-results
