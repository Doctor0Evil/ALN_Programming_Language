// Path: src/core/KnowledgeCatalog.js
// Lightweight, file-backed catalog of knowledge sources and virtual-objects for easy lookup.

import fs from "fs";
import path from "path";

export class KnowledgeCatalog {
  constructor(options = {}) {
    this.baseDir = options.baseDir || path.resolve(".javaspectre");
    this.sourcesFile = path.join(this.baseDir, "sources.json");
    this.virtualObjectsFile = path.join(this.baseDir, "virtual-objects.json");
    this._ensureBase();
  }

  _ensureBase() {
    if (!fs.existsSync(this.baseDir)) {
      fs.mkdirSync(this.baseDir, { recursive: true });
    }
    if (!fs.existsSync(this.sourcesFile)) {
      fs.writeFileSync(this.sourcesFile, JSON.stringify([], null, 2), "utf8");
    }
    if (!fs.existsSync(this.virtualObjectsFile)) {
      fs.writeFileSync(this.virtualObjectsFile, JSON.stringify([], null, 2), "utf8");
    }
  }

  _readJson(file) {
    const raw = fs.readFileSync(file, "utf8");
    return JSON.parse(raw);
  }

  _writeJson(file, data) {
    fs.writeFileSync(file, JSON.stringify(data, null, 2), "utf8");
  }

  addSource(source) {
    const all = this._readJson(this.sourcesFile);
    const entry = {
      id: source.id || `src-${Date.now().toString(16)}`,
      uri: source.uri || "",
      kind: source.kind || "unknown",
      description: source.description || "",
      tags: Array.isArray(source.tags) ? source.tags : [],
      createdAt: new Date().toISOString()
    };
    all.push(entry);
    this._writeJson(this.sourcesFile, all);
    return entry;
  }

  listSources(filter = {}) {
    const all = this._readJson(this.sourcesFile);
    if (!filter || Object.keys(filter).length === 0) return all;
    return all.filter((s) => {
      if (filter.kind && s.kind !== filter.kind) return false;
      if (filter.tag && !s.tags.includes(filter.tag)) return false;
      return true;
    });
  }

  addVirtualObject(vo) {
    const all = this._readJson(this.virtualObjectsFile);
    const entry = {
      id: vo.id || `vo-${Date.now().toString(16)}`,
      name: vo.name || "unnamed",
      signature: vo.signature || "",
      category: vo.category || "unknown",
      sourceId: vo.sourceId || null,
      fields: vo.fields || {},
      relationships: vo.relationships || [],
      tags: Array.isArray(vo.tags) ? vo.tags : [],
      createdAt: new Date().toISOString()
    };
    all.push(entry);
    this._writeJson(this.virtualObjectsFile, all);
    return entry;
  }

  listVirtualObjects(filter = {}) {
    const all = this._readJson(this.virtualObjectsFile);
    if (!filter || Object.keys(filter).length === 0) return all;
    return all.filter((v) => {
      if (filter.category && v.category !== filter.category) return false;
      if (filter.tag && !v.tags.includes(filter.tag)) return false;
      return true;
    });
  }
}

export default KnowledgeCatalog;
