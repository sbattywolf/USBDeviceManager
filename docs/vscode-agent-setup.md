Guida: sostituire Copilot/ChatGPT con un agente custom definito in `.continue/config.agent`

Scopo
- Usare un agente locale o specificato nel repository come fonte principale per automazioni/assistente in VS Code invece delle estensioni remoti (es. Copilot/ChatGPT).

Limitazioni
- VS Code non "sostituisce" direttamente Copilot con un file di configurazione; occorre installare/configurare un'estensione che esponga un endpoint o punti ad uno script/servizio locale.
- Questa guida mostra come configurare una soluzione basata su uno script locale (`.continue/agent-runner.ps1`) e come collegare VS Code ad essa usando impostazioni ed eventualmente estensioni che supportino endpoint locali.

Passi raccomandati
1) Definire l'agente repository-local
- File: `.continue/config.agent` (esempio incluso)
- Campo `entry` indica il runner (es. `.continue/agent-runner.ps1`) che riceve richieste e risponde.

2) Creare un semplice runner (opzionale)
- Esempio minimale: `.continue/agent-runner.ps1` che legge stdin e stampa una risposta JSON (non incluso automaticamente; posso generarlo se vuoi).

3) Configurare VS Code
- Se usi un'estensione che può chiamare un endpoint locale (es. "Local AI" o "REST Client"), configura l'URL o il comando per eseguire lo script.
- Alternativa semplice: usare un task o una command palette entry che invoca lo script locale e mostra output.

Esempi aggiuntivi inclusi nel repository:
- `.continue/agent-runner.ps1`: stub minimale che legge un prompt e risponde in JSON.
- `.vscode/tasks.example.json`: task di esempio per eseguire il runner locale dalla palette dei task.

Per provare localmente:
1. Copia `docs/vscode-workspace-settings.example.json` → `.vscode/settings.json` per disabilitare telemetria in workspace.
2. Apri la Command Palette → `Tasks: Run Task` → scegli `Run local agent` e inserisci il prompt.

Se vuoi, posso implementare una versione che invia richieste al tuo server LLM locale (es. `ollama` REST) invece di rispondere con un echo.

Esempio: aggiungere snippet in `.vscode/settings.json` per una estensione che supporta `localAgent.command`

{
  "localAgent.command": "powershell -NoProfile -ExecutionPolicy Bypass -File ${workspaceFolder}/.continue/agent-runner.ps1"
}

4) Disabilitare/sovrascrivere Copilot/ChatGPT (opzionale)
- Per Copilot: disabilitare l'estensione o impostare `github.copilot.enable": false` in `.vscode/settings.json` per questo workspace.
- Per ChatGPT/Chat extensions: rimuovere la key dell'endpoint o disabilitare l'estensione se desideri usare solo il runner locale.

5) Uso
- Lancia il runner tramite la palette o come task; i comandi che vogliono l'agente invocano il runner locale.

Sicurezza e segreti
- Se l'agente richiede segreti (API keys), non salvarli nel repository. Usa il Bitwarden CLI o variabili d'ambiente.

Esempio: leggere segreto da Bitwarden (se `bw` installato e autenticato)

$secret = bw get password <item-id> --raw

Se preferisci, posso generare automaticamente:
- `.continue/agent-runner.ps1` (minimal stub)
- `.vscode/settings.json` snippet e task
- istruzioni passo-passo in italiano e PowerShell one-liners per abilitare/disabilitare Copilot

Dimmi quali di questi vuoi che crei e committi sulla branch `feature/interactive-ci-mock`.
