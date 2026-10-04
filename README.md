# Pocket Party

A cross-platform Flutter collection of small multiplayer games.

Five playable games, each with local play, a bot, private online rooms, series records and result celebrations:

- Dots and Boxes: a 7 × 7 dot board with 36 boxes and 84 lines, local 2–4 players, a tactical two-player bot, and private online rooms. Capturing boxes keeps your turn, allowing long chains and late swings in the score.
- Chess: local two-player matches, a beginner bot, and private online rooms. Includes legal move highlights, castling, en passant, promotion, checkmate, draws, move history, and board flipping.
- Darts: 2–4 players, three darts per turn and five rounds. Drag to aim and release the moving sight to throw; highest total wins. Singles, doubles, triples, 25/50 bulls and misses are scored from the hit location.
- Word Grid: 2–4 players take turns placing one letter on a shared 5 × 5 board. New 3–5 letter words across or down score their length, once per distinct word. Crossing words can score together. The board ends after 25 placements. A dictionary lookup is available during play.
- Connect Four: two players drop discs into seven columns, aiming for a horizontal, vertical or diagonal line of four. The bot takes immediate wins and blocks immediate threats.

The refreshed library has category filters, game-specific colors, consistent controls, built-in rules and animated turn feedback. Timed chess caches board calculations, and Darts repaints its moving sight separately from the static board.

Word Grid bundles 19,492 words of 3–5 letters from the [Letterpress word list](https://github.com/lorenbrichter/Words), dedicated under CC0. See [the included license](third_party/LETTERPRESS-LICENSE.txt). This is the game's fixed English dictionary, including US, UK and Australian spellings; no network dictionary call is needed.

See [GETTING_STARTED.md](GETTING_STARTED.md) for run commands, code explanations, and Android setup.

Private rooms default to the hosted demo server at `https://pocket-party-rooms.onrender.com`. The included development server can also be used locally. Durable matches and additional games are future milestones.

For chess, White is the host and Black is the guest. Tap a piece and then a highlighted destination. The bot plays Black and searches two moves ahead; it is intended for beginner practice. Completed online matches can be restarted by the host. Joining a room automatically opens its game, regardless of which game card you used.

The home screen opens a separate setup page for each game. Chess supports untimed play or 1, 3, 5, and 10 minutes per player, without increments. Local clocks start when the board opens and continue while the app is in the background. Online clocks start when both seats are filled, run on the server, and continue during disconnections. Running out of time ends the game.

Both games show wins, losses and draws for the current series. Only completed games count; Play again preserves the record and resets the board and clocks. Leaving a local match starts a new series next time. Online records stay with the room until it expires or the server restarts. These are series records, not account-wide lifetime statistics.

Completed games show a result celebration with a trophy, confetti, a brief shake and haptic feedback for wins. Reduced-motion settings disable animation and vibration. Draws show a quieter result screen.
