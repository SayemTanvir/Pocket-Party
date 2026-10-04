# Pocket Party

A Flutter game collection, starting with Dots and Boxes.

## Run the first game

Open PowerShell in `D:\Random_Project\pocket_party`:

```powershell
$env:PUB_CACHE = 'D:\Random_Project\.tools\pub-cache'
..\.tools\flutter\bin\flutter.bat run -d chrome
```

If Chrome isn't available, use `-d edge`. Choose 2–4 players sharing the device, or enable the two-player bot. Tap a line between dots. Completing a box earns a point and another turn.

## Understand the code

- `lib/main.dart`: home screen, board, touch input, and bot scheduling.
- `lib/games/dots_game.dart`: legal moves, turns, box ownership, scores, and game completion.
- `test/dots_game_test.dart`: checks important game rules.

The bot completes available boxes and avoids giving boxes away when a safe move exists.

## Private multiplayer rooms

The app now defaults to the live demo server at `https://pocket-party-rooms.onrender.com`. Players can create and join rooms over the internet without USB routing. Render's free service may take about a minute to wake after inactivity; rooms can disappear when it restarts.

For local development instead:

Start the room server in a separate terminal:

```powershell
.\tool.ps1 server
```

It listens at `http://127.0.0.1:8787`. In the app, select **Play with friends**, choose a player count, and create a room. Other players enter the same server address and six-character room code. The match starts when all seats are filled.

For a phone connected by USB, route its local port to this computer:

```powershell
..\.tools\android-sdk\platform-tools\adb.exe reverse tcp:8787 tcp:8787
```

Enter `http://127.0.0.1:8787` as the server address on the phone. A browser on the computer can join the same room as a second player. Each connected Android phone needs its own reverse mapping.

For same-Wi-Fi testing instead, start the server with `$env:HOST = '0.0.0.0'` before running the helper, and use the computer's LAN address on each device. The Windows firewall and Wi-Fi network must permit that connection. The development APK permits HTTP; published builds should use a hosted HTTPS server.

The server validates player identity, whose turn it is, legal moves, and the board revision. It shares the exact game rules used by local play. Clients fetch updates every second and reconnect automatically after temporary connection loss while the match screen stays open. Only the host can restart, after the match finishes.

Development limitations: rooms live in server memory, expire after two hours without activity, and disappear if the server restarts. Returning to the home screen or restarting the app does not preserve your player session. There is no public internet endpoint yet. Production hosting needs HTTPS, persistent sessions, room storage, and rate limits.

## Android setup

The local toolchain is installed under `D:\Random_Project\.tools`. Use the helper script so Flutter finds the SDK and keeps build caches in the workspace:

```powershell
.\tool.ps1 doctor
.\tool.ps1 devices
.\tool.ps1 apk
.\tool.ps1 run -Device YOUR_DEVICE_ID
```

The development APK is written to `build\app\outputs\flutter-apk\app-debug.apk`. This is a test build, not a Play Store release.

For a physical Android phone, enable Developer options, enable USB debugging, connect by USB, and accept the computer authorization prompt on the phone. Some devices also need a manufacturer USB driver.

Install Android Studio and its SDK using https://docs.flutter.dev/platform-integration/android/setup . Run Flutter doctor to check requirements:

```powershell
..\.tools\flutter\bin\flutter.bat doctor
```

Once an Android device or emulator is connected, run `flutter.bat devices`, then `flutter.bat run -d DEVICE_ID` using the same SDK path above.

Native iOS builds require macOS and Xcode. The generated iOS project is included for that later step.
