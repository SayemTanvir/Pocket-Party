# Put private multiplayer rooms online

This deploys the Dart room server. The Flutter app connects to the resulting HTTPS address. GitHub stores your source; Render runs the server.

## Deploy the demo on Render

1. Push the updated project, including `Dockerfile`, `.dockerignore`, `render.yaml`, and `server/pubspec.yaml`, to your GitHub repository.
2. Sign in to https://dashboard.render.com/ .
3. Choose **New → Blueprint**, connect GitHub, and select `SayemTanvir/Pocket-Party`.
4. Review the Blueprint. It defines one Docker web service, `pocket-party-rooms`, with the **Free** plan and Singapore region. Keep the plan free for this demo.
5. Deploy and wait for the service to become **Live**. Copy its HTTPS service URL; the exact URL is assigned by Render.
6. Open `YOUR_SERVICE_URL/health`. It should return `{"status":"ok"}`.

If you use **New → Web Service** instead, select the same repository, Docker runtime, repository root as the Docker build context, `./Dockerfile`, Free plan, and `/health` as the health-check path. Set `HOST=0.0.0.0` and `PORT=10000`.

## Connect the phone

In **Play with friends**, enter the HTTPS service URL as the game server address. All participants must use the same server URL. USB routing is no longer needed when using that hosted URL.

To build an APK with that server as the default:

```powershell
.\tool.ps1 apk -ServerUrl 'https://YOUR_SERVICE_NAME.onrender.com'
```

Send the real URL to Codex and we can verify it, build the APK, and install the update on the connected phone. Do not send passwords or API tokens.

## Demo behavior

- The Free service can sleep after inactivity and take time to start again. The app first checks `/health` for up to 75 seconds, then sends the create/join request once.
- Rooms are held in memory. Deployments, server restarts, and free-service shutdowns can clear them. This demo does not provide durable matches.
- Keep each match screen open. Player sessions do not survive leaving the screen or restarting the app.
- The server validates player tokens, turns, moves, and board revisions. Request bodies are capped at 4 KiB and time out after ten seconds without data.
- Requests are limited to 1,200 per minute per directly connected address, and room creation to 40 per minute. Reverse proxies may make multiple users share the same address and limit. These are basic demo limits, not a distributed anti-abuse system.
- The Docker runtime runs as an unprivileged user and handles SIGTERM shutdowns. Render terminates HTTPS; the container listens internally on the configured port.

Before a larger release, add durable room/session storage, account recovery, production access controls, stronger abuse controls, and operational monitoring.

Official references: https://render.com/docs/blueprint-spec , https://render.com/docs/docker , https://render.com/docs/free .
