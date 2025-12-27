// Path: src/cli/javaspectre-knowledge.js
#!/usr/bin/env node

import { KnowledgeCatalog } from "../core/KnowledgeCatalog.js";
import { VirtualObjectExcavator } from "../core/VirtualObjectExcavator.js";

async function main() {
  const [, , command, ...rest] = process.argv;
  const catalog = new KnowledgeCatalog();

  if (command === "list-sources") {
    const list = catalog.listSources({});
    process.stdout.write(JSON.stringify(list, null, 2));
    return;
  }

  if (command === "list-virtual-objects") {
    const list = catalog.listVirtualObjects({});
    process.stdout.write(JSON.stringify(list, null, 2));
    return;
  }

  if (command === "excavate-json") {
    const json = rest.join(" ").trim();
    if (!json) {
      process.stderr.write("Usage: javaspectre-knowledge excavate-json '<json>'\n");
      process.exit(1);
    }
    const value = JSON.parse(json);
    const excavator = new VirtualObjectExcavator();
    const result = excavator.excavate(value, null);
    result.virtualObjects.forEach((vo) => {
      catalog.addVirtualObject({
        name: vo.id,
        signature: vo.signature || "",
        category: vo.category || "unknown",
        fields: vo.fields || {},
        relationships: vo.relationships || [],
        tags: ["json-excavation"]
      });
    });
    process.stdout.write(JSON.stringify(result.summary, null, 2));
    return;
  }

  process.stderr.write(
    "Usage:\n" +
      "  javaspectre-knowledge list-sources\n" +
      "  javaspectre-knowledge list-virtual-objects\n" +
      "  javaspectre-knowledge excavate-json '<json>'\n"
  );
  process.exit(1);
}

main();
