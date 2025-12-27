// Path: src/core/VirtualObjectExcavator.js
// Deep virtual-object excavation for JS values and DOM trees.

export class VirtualObjectExcavator {
  constructor(options = {}) {
    this.maxDepth = typeof options.maxDepth === "number" ? options.maxDepth : 6;
    this.maxArraySample =
      typeof options.maxArraySample === "number" ? options.maxArraySample : 10;
    this.includeDom = options.includeDom !== false;
    this.includeFunctions = options.includeFunctions === true;
  }

  excavate(value, domRoot = null) {
    const virtualObjects = [];
    const relationships = [];
    const domSheets = [];
    const visited = new WeakSet();

    const rootId = "root";
    const valueDef = this.inspectValue(
      value,
      rootId,
      0,
      visited,
      virtualObjects,
      relationships
    );

    if (this.includeDom && domRoot && typeof domRoot.querySelectorAll === "function") {
      const domResult = this.inspectDom(domRoot);
      domSheets.push(...domResult.domSheets);
      virtualObjects.push(...domResult.virtualObjects);
      relationships.push(...domResult.relationships);
    }

    return {
      root: valueDef,
      virtualObjects,
      relationships,
      domSheets,
      summary: this.buildSummary(virtualObjects, relationships, domSheets)
    };
  }

  inspectValue(value, id, depth, visited, virtualObjects, relationships) {
    if (depth > this.maxDepth) {
      return { id, kind: "depth-limit", valueType: null, example: null, note: "Max depth" };
    }

    if (value === null || value === undefined) {
      return { id, kind: "nullish", valueType: null, example: value, note: null };
    }

    if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
      const primitiveDef = {
        id,
        kind: "primitive",
        valueType: typeof value,
        example: value,
        note: null
      };
      virtualObjects.push({
        id,
        category: "primitive",
        signature: `${typeof value}`,
        meta: { example: value }
      });
      return primitiveDef;
    }

    if (Array.isArray(value)) {
      return this._inspectArray(value, id, depth, visited, virtualObjects, relationships);
    }

    if (typeof value === "function" && this.includeFunctions) {
      const funcDef = {
        id,
        kind: "function",
        valueType: "function",
        example: value.name || "anonymous",
        note: null
      };
      virtualObjects.push({
        id,
        category: "function",
        signature: value.name || "anonymous",
        meta: {}
      });
      return funcDef;
    }

    if (typeof value === "object") {
      if (visited.has(value)) {
        return { id, kind: "circular", valueType: "object", example: null, note: "Circular ref" };
      }
      visited.add(value);
      return this._inspectObject(value, id, depth, visited, virtualObjects, relationships);
    }

    return {
      id,
      kind: "unknown",
      valueType: typeof value,
      example: String(value),
      note: "Unhandled type"
    };
  }

  _inspectArray(arr, id, depth, visited, virtualObjects, relationships) {
    const sampleSize = Math.min(this.maxArraySample, arr.length);
    const samples = arr.slice(0, sampleSize);
    const elementDefs = [];
    const elementKinds = new Set();

    samples.forEach((item, index) => {
      const elementId = `${id}[${index}]`;
      const def = this.inspectValue(
        item,
        elementId,
        depth + 1,
        visited,
        virtualObjects,
        relationships
      );
      elementDefs.push(def);
      elementKinds.add(def.kind);
    });

    const arrayDef = {
      id,
      kind: "array",
      length: arr.length,
      sampled: sampleSize,
      elementKinds: Array.from(elementKinds),
      elementSamples: elementDefs
    };

    virtualObjects.push({
      id,
      category: "collection",
      signature: `Array<${Array.from(elementKinds).join(" | ")}>`,
      meta: { sampled: sampleSize, total: arr.length }
    });

    return arrayDef;
  }

  _inspectObject(obj, id, depth, visited, virtualObjects, relationships) {
    const ctorName =
      obj && obj.constructor && obj.constructor.name ? obj.constructor.name : "Object";
    const fields = {};
    const fieldDescriptions = {};

    Object.keys(obj).forEach((key) => {
      const fieldId = `${id}.${key}`;
      const value = obj[key];
      const childDef = this.inspectValue(
        value,
        fieldId,
        depth + 1,
        visited,
        virtualObjects,
        relationships
      );
      fields[key] = childDef;
      fieldDescriptions[key] = {
        kind: childDef.kind,
        valueType: childDef.valueType || null,
        example: childDef.example !== undefined ? childDef.example : undefined,
        note: childDef.note || null
      };
      relationships.push({ from: id, to: childDef.id, relation: "field", field: key });
    });

    const objDef = {
      id,
      kind: "object",
      ctor: ctorName,
      fields
    };

    virtualObjects.push({
      id,
      category: "struct",
      signature: `${ctorName}{...}`,
      fields: fieldDescriptions
    });

    return objDef;
  }

  inspectDom(domRoot) {
    const virtualObjects = [];
    const relationships = [];
    const domSheets = [];

    const all = Array.from(domRoot.querySelectorAll("*"));
    const byTag = new Map();
    const byClass = new Map();

    all.forEach((el) => {
      const tag = el.tagName.toLowerCase();
      const classList = Array.from(el.classList);
      if (!byTag.has(tag)) byTag.set(tag, []);
      byTag.get(tag).push(el);
      classList.forEach((cls) => {
        const key = `.${cls}`;
        if (!byClass.has(key)) byClass.set(key, []);
        byClass.get(key).push(el);
      });
    });

    const domSheet = {
      tagSummaries: [],
      classSummaries: [],
      totalNodes: all.length
    };

    byTag.forEach((elements, tag) => {
      const selector = tag;
      const sample = elements[0] || null;
      const id = `dom:tag:${selector}`;
      const attrs = sample ? this.extractAttributes(sample) : {};
      domSheet.tagSummaries.push({
        selector,
        count: elements.length,
        attributesExample: attrs
      });
      virtualObjects.push({
        id,
        category: "dom-tag",
        selector,
        count: elements.length,
        attributesExample: attrs
      });
    });

    byClass.forEach((elements, clsSelector) => {
      const selector = clsSelector;
      const sample = elements[0] || null;
      const id = `dom:class:${selector}`;
      const attrs = sample ? this.extractAttributes(sample) : {};
      domSheet.classSummaries.push({
        selector,
        count: elements.length,
        attributesExample: attrs
      });
      virtualObjects.push({
        id,
        category: "dom-class",
        selector,
        count: elements.length,
        attributesExample: attrs
      });
    });

    domSheets.push(domSheet);
    return { domSheets, virtualObjects, relationships };
  }

  extractAttributes(el) {
    const attrs = {};
    if (!el || !el.attributes) return attrs;
    Array.from(el.attributes).forEach((a) => {
      attrs[a.name] = a.value;
    });
    return attrs;
  }

  buildSummary(virtualObjects, relationships, domSheets) {
    return {
      totalVirtualObjects: virtualObjects.length,
      totalRelationships: relationships.length,
      hasDomSheets: domSheets.length > 0
    };
  }
}

export default VirtualObjectExcavator;
