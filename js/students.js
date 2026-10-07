const Students = {
  PAGE: 25,
  csv(rows) { return rows.map(r => r.map(v => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",")).join("\n"); },
  download(name, text) { const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([text], { type: "text/csv" })); a.download = name; a.click(); URL.revokeObjectURL(a.href); },
  parseCSV(t) { // handles quoted fields
    const out = []; let row = [], f = "", q = false;
    for (let i = 0; i < t.length; i++) { const c = t[i];
      if (q) { if (c === '"' && t[i + 1] === '"') { f += '"'; i++; } else if (c === '"') q = false; else f += c; }
      else if (c === '"') q = true; else if (c === ",") { row.push(f); f = ""; }
      else if (c === "\n" || c === "\r") { if (c === "\r" && t[i + 1] === "\n") i++; row.push(f); f = ""; if (row.some(x => x.trim())) out.push(row); row = []; }
      else f += c; }
    row.push(f); if (row.some(x => x.trim())) out.push(row); return out; },
  safe: s => s.replace(/[,()%*]/g, " ").trim()
};
