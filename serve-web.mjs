// Petit serveur statique (Node, sans dépendance) pour servir le build RELEASE de l'app Flutter Web
// (apps/mobile/build/web) sur http://localhost:8080/. Contrairement à `flutter run -d chrome`
// (build DEBUG lié à une seule fenêtre Chrome → écran blanc ailleurs), ceci marche dans TOUS les
// navigateurs du PC. Utilisé par demarrer-app.ps1.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { join, extname, normalize, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { exec } from "node:child_process";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const ROOT = join(HERE, "apps", "mobile", "build", "web");
const PORT = 8080; // fixe : requis comme origine JavaScript autorisée pour la connexion Google.

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".map": "application/json; charset=utf-8",
  ".bin": "application/octet-stream",
  ".txt": "text/plain; charset=utf-8",
};

async function send(res, filePath, status = 200) {
  const data = await readFile(filePath);
  res.writeHead(status, {
    "Content-Type": MIME[extname(filePath).toLowerCase()] ?? "application/octet-stream",
    // Pas de cache : un rebuild est pris en compte immédiatement (évite les écrans blancs « stale »).
    "Cache-Control": "no-cache, no-store, must-revalidate",
  });
  res.end(data);
}

const server = createServer(async (req, res) => {
  try {
    const urlPath = decodeURIComponent((req.url ?? "/").split("?")[0]);
    let rel = normalize(urlPath).replace(/^[/\\]+/, "");
    if (rel === "" || urlPath.endsWith("/")) rel = join(rel, "index.html");
    const filePath = join(ROOT, rel);
    if (filePath !== ROOT && !filePath.startsWith(ROOT + sep)) {
      res.writeHead(403);
      res.end("Forbidden");
      return;
    }
    try {
      const s = await stat(filePath);
      await send(res, s.isDirectory() ? join(filePath, "index.html") : filePath);
    } catch {
      // Fallback SPA : un chemin inconnu SANS extension → index.html (routage côté client).
      if (!extname(filePath)) {
        await send(res, join(ROOT, "index.html"));
        return;
      }
      res.writeHead(404);
      res.end("Not found");
    }
  } catch {
    res.writeHead(500);
    res.end("Server error");
  }
});

server.on("error", (e) => {
  if (e.code === "EADDRINUSE") {
    console.error(`Le port ${PORT} est déjà utilisé. Ferme l'autre serveur (ou la fenêtre précédente) puis réessaie.`);
  } else {
    console.error(e.message);
  }
  process.exit(1);
});

server.listen(PORT, () => {
  const url = `http://localhost:${PORT}/`;
  console.log(`\nHYBRID INDEX (build release) servi sur ${url}`);
  console.log("Marche dans TOUS les navigateurs du PC. Laisse cette fenêtre ouverte. Ctrl+C pour arrêter.\n");
  if (process.platform === "win32" && !process.env.NO_OPEN) exec(`start "" "${url}"`); // navigateur par défaut
});
