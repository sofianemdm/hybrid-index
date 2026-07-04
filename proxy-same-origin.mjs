// TEST LOCAL : sert l'app (build/web-proxy) ET proxifie /v1, /health vers le backend :3000,
// le tout sur LA MÊME origine http://localhost:8093 -> aucune requête cross-origin côté navigateur.
// VERSION DIAGNOSTIC :
//  - journal d'accès de CHAQUE requête dans proxy-access.log (methode, url, statut) ;
//  - POST /diag-report : collecteur — le corps JSON est ajouté à diag-report.jsonl (une ligne/événement).
//    Utilisé par diag.html (batterie de tests navigateur) et par le beacon temporaire de l'app Flutter.
import { createServer, request as httpRequest } from "node:http";
import { readFile, appendFile } from "node:fs/promises";
import { join, extname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL(".", import.meta.url));
// Paramétrable pour lancer une 2e instance (ex. repro diagnostic sur 8094) : DIAG_PORT + DIAG_ROOT.
const ROOT = process.env.DIAG_ROOT ? join(HERE, process.env.DIAG_ROOT) : join(HERE, "apps", "mobile", "build", "web-proxy");
const PORT = Number(process.env.DIAG_PORT || 8093);
const ACCESS_LOG = join(HERE, "proxy-access.log");
const REPORT_LOG = join(HERE, "diag-report.jsonl");
const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8", ".json": "application/json; charset=utf-8", ".wasm": "application/wasm", ".css": "text/css; charset=utf-8", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif", ".svg": "image/svg+xml", ".ico": "image/x-icon", ".ttf": "font/ttf", ".otf": "font/otf", ".woff": "font/woff", ".woff2": "font/woff2", ".bin": "application/octet-stream", ".map": "application/json" };

function log(line) {
  appendFile(ACCESS_LOG, `${new Date().toISOString()} ${line}\n`).catch(() => {});
}

const server = createServer(async (req, res) => {
  const url = req.url ?? "/";

  // Collecteur de diagnostic : consigne le corps JSON tel quel.
  if (url === "/diag-report" && req.method === "POST") {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const body = Buffer.concat(chunks).toString("utf8");
      appendFile(REPORT_LOG, `${new Date().toISOString()} ${body}\n`).catch(() => {});
      log(`DIAG-REPORT ${body.slice(0, 160)}`);
      res.writeHead(204);
      res.end();
    });
    return;
  }

  if (url.startsWith("/v1/") || url.startsWith("/health")) {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const body = Buffer.concat(chunks);
      const p = httpRequest(
        { host: "127.0.0.1", port: 3000, method: req.method, path: url, headers: { ...req.headers, host: "127.0.0.1:3000" } },
        (pr) => {
          log(`API ${req.method} ${url} -> ${pr.statusCode}`);
          res.writeHead(pr.statusCode ?? 502, pr.headers);
          pr.pipe(res);
        },
      );
      p.on("error", (e) => {
        log(`API ${req.method} ${url} -> PROXY-ERR ${e.message}`);
        res.writeHead(502, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: { code: "PROXY", message: e.message } }));
      });
      if (body.length) p.write(body);
      p.end();
    });
    return;
  }

  let rel = url.split("?")[0].replace(/^\/+/, "");
  if (rel === "") rel = "index.html";
  try {
    const data = await readFile(join(ROOT, rel));
    log(`STATIC ${req.method} ${url} -> 200`);
    res.writeHead(200, { "Content-Type": MIME[extname(rel).toLowerCase()] ?? "application/octet-stream", "Cache-Control": "no-store" });
    res.end(data);
  } catch {
    const data = await readFile(join(ROOT, "index.html"));
    log(`STATIC ${req.method} ${url} -> 200 (fallback index)`);
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
    res.end(data);
  }
});
server.listen(PORT, () => console.log(`proxy same-origin (diag) sur http://localhost:${PORT}`));
