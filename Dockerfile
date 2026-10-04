FROM dart:3.13.4 AS build
WORKDIR /app/server
COPY server/pubspec.yaml ./
RUN dart pub get
COPY server/main.dart server/room_server.dart ./
COPY lib/games/dots_game.dart /app/lib/games/dots_game.dart
RUN dart compile exe main.dart -o /app/room-server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/room-server /app/room-server
ENV HOST=0.0.0.0 PORT=10000
USER 10001:10001
EXPOSE 10000
ENTRYPOINT ["/app/room-server"]
