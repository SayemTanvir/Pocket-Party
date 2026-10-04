# Pocket Party

A cross-platform Flutter collection of small multiplayer games.

Two playable games:

- Dots and Boxes: a 7 × 7 dot board with 36 boxes and 84 lines, local 2–4 players, a tactical two-player bot, and private online rooms. Capturing boxes keeps your turn, allowing long chains and late swings in the score.
- Chess: local two-player matches, a beginner bot, and private online rooms. Includes legal move highlights, castling, en passant, promotion, checkmate, draws, move history, and board flipping.

See [GETTING_STARTED.md](GETTING_STARTED.md) for run commands, code explanations, and Android setup.

Private rooms default to the hosted demo server at `https://pocket-party-rooms.onrender.com`. The included development server can also be used locally. Durable matches and additional games are future milestones.

For chess, White is the host and Black is the guest. Tap a piece and then a highlighted destination. The bot plays Black and searches two moves ahead; it is intended for beginner practice. Completed online matches can be restarted by the host. Joining a room automatically opens its game, regardless of which game card you used.
