/**
 * Static file server for Therapy.jl E2E testing.
 * Serves docs/dist at /Therapy.jl/ to match the production base path.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const distDir = path.join(__dirname, '..', '..', 'docs', 'dist');
const port = parseInt(process.env.PORT || '8081', 10);
const basePath = '/Therapy.jl';

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  let url = req.url.split('?')[0];

  // Strip base path prefix
  if (url.startsWith(basePath)) {
    url = url.slice(basePath.length) || '/';
  } else if (url === '/') {
    // Redirect root to base path
    res.writeHead(302, { Location: basePath + '/' });
    res.end();
    return;
  }

  // Default to index.html for directory paths
  if (url.endsWith('/')) url += 'index.html';

  const filePath = path.join(distDir, url);
  const ext = path.extname(filePath);
  const contentType = mimeTypes[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      // Try with .html extension for extensionless paths
      if (!ext) {
        fs.readFile(filePath + '.html', (err2, data2) => {
          if (err2) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('Not found: ' + url);
          } else {
            res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
            res.end(data2);
          }
        });
        return;
      }
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found: ' + url);
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
});

server.listen(port, () => {
  console.log(`Serving docs/dist at http://localhost:${port}${basePath}/`);
});
