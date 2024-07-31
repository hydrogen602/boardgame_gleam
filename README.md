# boardgame

Features
- Server can handle many games at once
- Networked: players can together over the internet
- Each game has a unique game token to make it easy to invite friends but keeps games private
- Players can reload the page without losing their seat in the game: game tokens and a unique player token are stored in localStorage
- Players can't play opponents pieces

Start backend:
```bash
gleam run
```

Start frontend
```bash
cd game-ui
npm start
```

