# JadeMirror Frontend

Vue 3 + Vite frontend for the JadeMirror interactive jade-culture project.

## Install

```bash
npm install
```

## Run (development)

```bash
npm run dev
```

Default frontend URL: `http://localhost:5173`

The frontend proxies `/api/*` requests to Flask backend (`http://127.0.0.1:5000`) in development.

## Build

```bash
npm run build
```

## Routes

- `/` homepage with Three.js jade mirror
- `/test` psychology test
- `/result` matched jade result
- `/chat` jade personality chat
- `/generate` image generation + emotion + audio
- `/gallery` localStorage gallery

## Notes

- Face emotion detection expects model files under `public/models/`.
- Without backend API keys, Flask returns mock results so the frontend flow still works.
