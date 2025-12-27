// Filename: ALNSpec.js
// Destination: /src/protocol/ALNSpec.js
// Description:
// Canonical ALN language specification, message surface, and validation/runtime
// utilities suitable for production-grade JS applications, including neuromorphic,
// BCI-device, nanoswarm, and augmented-user platforms integration surfaces.

// Core version identifier for this ALN spec module.
export const ALN_VERSION = "1.0.0";

// Primitive type identifiers for ALN payloads.
export const ALNPrimitives = Object.freeze({
  STRING: "aln::string",
  NUMBER: "aln::number",
  BOOLEAN: "aln::boolean",
  OBJECT: "aln::object",
  ARRAY: "aln::array",
  VIRTUAL_OBJECT: "aln::virtual_object",
  INTENT: "aln::intent",
  PLAN: "aln::plan",
  SIGNAL: "aln::signal"
});

// Message kind identifiers for ALN envelope-level messages.
export const ALNMessageKinds = Object.freeze({
  INTENT_REQUEST: "aln::intent_request",
  INTENT_PLAN: "aln::intent_plan",
  EXECUTION_RESULT: "aln::execution_result",
  ERROR: "aln::error",
  HEARTBEAT: "aln::heartbeat",
  SPEC_QUERY: "aln::spec_query",
  SPEC_RESPONSE: "aln::spec_response"
});

// Canonical intent specifications including input/output shapes.
export const ALNSpec = Object.freeze({
  version: ALN_VERSION,
  identity: {
    languageName: "Augmented Language Networks",
    shortName: "ALN",
    authority: "GoogolswarmAI Nanoswarm + Javaspectre Initiative"
  },
  primitives: ALNPrimitives,
  messages: ALNMessageKinds,
  intents: {
    "aln::define_virtual_object": {
      description: "Define or update a virtual-object in the global registry.",
      inputShape: {
        name: ALNPrimitives.STRING,
        description: ALNPrimitives.STRING,
        schema: ALNPrimitives.OBJECT,
        tags: ALNPrimitives.ARRAY
      },
      outputShape: {
        id: ALNPrimitives.STRING,
        name: ALNPrimitives.STRING
      }
    },
    "aln::plan_repository": {
      description: "Create a repository plan including files, workflows, and policies.",
      inputShape: {
        description: ALNPrimitives.STRING,
        constraints: ALNPrimitives.OBJECT
      },
      outputShape: {
        planId: ALNPrimitives.STRING,
        files: ALNPrimitives.ARRAY,
        workflows: ALNPrimitives.ARRAY
      }
    },
    "aln::interop_python": {
      description: "Request a Python operation compatible with ML systems and notebooks.",
      inputShape: {
        sessionId: ALNPrimitives.STRING,
        code: ALNPrimitives.STRING,
        ioContract: ALNPrimitives.OBJECT
      },
      outputShape: {
        sessionId: ALNPrimitives.STRING,
        stdout: ALNPrimitives.STRING,
        stderr: ALNPrimitives.STRING
      }
    }
  }
});

/**
 * Internal helper to get human-readable primitive name for error messages.
 * @param {string} primitive
 * @returns {string}
 */
function primitiveLabel(primitive) {
  switch (primitive) {
    case ALNPrimitives.STRING:
      return "string";
    case ALNPrimitives.NUMBER:
      return "number";
    case ALNPrimitives.BOOLEAN:
      return "boolean";
    case ALNPrimitives.OBJECT:
      return "object";
    case ALNPrimitives.ARRAY:
      return "array";
    case ALNPrimitives.VIRTUAL_OBJECT:
      return "virtual_object";
    case ALNPrimitives.INTENT:
      return "intent";
    case ALNPrimitives.PLAN:
      return "plan";
    case ALNPrimitives.SIGNAL:
      return "signal";
    default:
      return primitive;
  }
}

/**
 * Validate a JS value against an ALN primitive type.
 * This is intentionally strict and production-oriented.
 *
 * @param {any} value
 * @param {string} primitive - one of ALNPrimitives
 * @returns {{valid: boolean, error?: string}}
 */
export function validatePrimitive(value, primitive) {
  switch (primitive) {
    case ALNPrimitives.STRING: {
      const ok = typeof value === "string";
      return ok
        ? { valid: true }
        : { valid: false, error: `Expected string for ${primitive}, got ${typeof value}` };
    }
    case ALNPrimitives.NUMBER: {
      const ok = typeof value === "number" && Number.isFinite(value);
      return ok
        ? { valid: true }
        : { valid: false, error: `Expected finite number for ${primitive}, got ${String(value)}` };
    }
    case ALNPrimitives.BOOLEAN: {
      const ok = typeof value === "boolean";
      return ok
        ? { valid: true }
        : { valid: false, error: `Expected boolean for ${primitive}, got ${typeof value}` };
    }
    case ALNPrimitives.OBJECT: {
      const ok = typeof value === "object" && value !== null && !Array.isArray(value);
      return ok
        ? { valid: true }
        : { valid: false, error: `Expected object for ${primitive}, got ${Array.isArray(value) ? "array" : typeof value}` };
    }
    case ALNPrimitives.ARRAY: {
      const ok = Array.isArray(value);
      return ok
        ? { valid: true }
        : { valid: false, error: `Expected array for ${primitive}, got ${typeof value}` };
    }
    case ALNPrimitives.VIRTUAL_OBJECT:
    case ALNPrimitives.INTENT:
    case ALNPrimitives.PLAN:
    case ALNPrimitives.SIGNAL: {
      // For higher-level primitives, default to object shape and allow
      // additional semantic validation by higher layers.
      const ok = typeof value === "object" && value !== null;
      return ok
        ? { valid: true }
        : { valid: false, error: `Expected structured object for ${primitive}, got ${typeof value}` };
    }
    default:
      return { valid: false, error: `Unknown primitive type: ${primitive}` };
  }
}

/**
 * Validate a payload against a given ALN shape.
 * Shape is an object of { fieldName: ALNPrimitives.X }.
 *
 * @param {object} payload
 * @param {Record<string, string>} shape
 * @param {boolean} [allowExtraKeys=false]
 * @returns {{valid: boolean, errors: string[]}}
 */
export function validateShape(payload, shape, allowExtraKeys = false) {
  const errors = [];

  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    return {
      valid: false,
      errors: [`Payload must be an object, got ${Array.isArray(payload) ? "array" : typeof payload}`]
    };
  }

  // Validate required fields and types.
  for (const [field, primitive] of Object.entries(shape)) {
    if (!(field in payload)) {
      errors.push(`Missing required field "${field}" (expected ${primitiveLabel(primitive)})`);
      continue;
    }
    const result = validatePrimitive(payload[field], primitive);
    if (!result.valid) {
      errors.push(`Field "${field}" invalid: ${result.error}`);
    }
  }

  // Optionally disallow extra keys.
  if (!allowExtraKeys) {
    const allowedFields = new Set(Object.keys(shape));
    for (const key of Object.keys(payload)) {
      if (!allowedFields.has(key)) {
        errors.push(`Unexpected field "${key}" not defined in shape`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Validate an ALN intent payload against the intent specification.
 *
 * @param {string} intentName
 * @param {object} inputPayload
 * @param {boolean} [allowExtraKeys=false]
 * @returns {{valid: boolean, errors: string[]}}
 */
export function validateIntentInput(intentName, inputPayload, allowExtraKeys = false) {
  const intent = ALNSpec.intents[intentName];
  if (!intent) {
    return {
      valid: false,
      errors: [`Unknown intent "${intentName}"`]
    };
  }

  return validateShape(inputPayload, intent.inputShape, allowExtraKeys);
}

/**
 * Validate an ALN intent output payload against the intent specification.
 *
 * @param {string} intentName
 * @param {object} outputPayload
 * @param {boolean} [allowExtraKeys=false]
 * @returns {{valid: boolean, errors: string[]}}
 */
export function validateIntentOutput(intentName, outputPayload, allowExtraKeys = false) {
  const intent = ALNSpec.intents[intentName];
  if (!intent) {
    return {
      valid: false,
      errors: [`Unknown intent "${intentName}"`]
    };
  }

  return validateShape(outputPayload, intent.outputShape, allowExtraKeys);
}

/**
 * Canonical ALN message envelope for transport across neuromorphic,
 * nanoswarm, and conventional networks.
 *
 * @typedef {object} ALNMessageEnvelope
 * @property {string} id - Globally unique message identifier (e.g. UUIDv4, ULID).
 * @property {string} kind - One of ALNMessageKinds.
 * @property {string} [intent] - Optional intent name (for intent-bearing messages).
 * @property {number} timestamp - Unix epoch milliseconds.
 * @property {object} payload - Message-specific payload.
 * @property {object} [meta] - Optional metadata (routing, trace info, device IDs, BCI channel, etc.).
 */

/**
 * Validate an ALN message envelope for shape and semantic correctness.
 *
 * @param {ALNMessageEnvelope} message
 * @returns {{valid: boolean, errors: string[]}}
 */
export function validateMessageEnvelope(message) {
  const errors = [];

  if (typeof message !== "object" || message === null || Array.isArray(message)) {
    return {
      valid: false,
      errors: ["Message must be an object"]
    };
  }

  // id
  if (typeof message.id !== "string" || message.id.length === 0) {
    errors.push('Field "id" must be a non-empty string');
  }

  // kind
  const allowedKinds = new Set(Object.values(ALNMessageKinds));
  if (typeof message.kind !== "string" || !allowedKinds.has(message.kind)) {
    errors.push(`Field "kind" must be one of ${Array.from(allowedKinds).join(", ")}`);
  }

  // timestamp
  if (typeof message.timestamp !== "number" || !Number.isFinite(message.timestamp)) {
    errors.push('Field "timestamp" must be a finite number in epoch milliseconds');
  }

  // payload
  if (typeof message.payload !== "object" || message.payload === null) {
    errors.push('Field "payload" must be a non-null object');
  }

  // meta
  if ("meta" in message) {
    const meta = message.meta;
    if (typeof meta !== "object" || meta === null || Array.isArray(meta)) {
      errors.push('Field "meta", if present, must be a non-null object');
    }
  }

  // intent for intent-bearing messages
  const intentKinds = new Set([
    ALNMessageKinds.INTENT_REQUEST,
    ALNMessageKinds.INTENT_PLAN,
    ALNMessageKinds.EXECUTION_RESULT
  ]);

  if (intentKinds.has(message.kind)) {
    if (typeof message.intent !== "string" || message.intent.length === 0) {
      errors.push(`Field "intent" must be a non-empty string for kind ${message.kind}`);
    } else if (!ALNSpec.intents[message.intent]) {
      errors.push(`Unknown intent "${message.intent}" for message kind ${message.kind}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Create a strongly-typed ALN intent request message envelope.
 *
 * @param {string} id
 * @param {string} intentName
 * @param {object} inputPayload
 * @param {object} [meta]
 * @returns {ALNMessageEnvelope}
 * @throws {Error} when validation fails
 */
export function createIntentRequest(id, intentName, inputPayload, meta) {
  const inputValidation = validateIntentInput(intentName, inputPayload);
  if (!inputValidation.valid) {
    throw new Error(
      `Invalid input for intent "${intentName}": ${inputValidation.errors.join("; ")}`
    );
  }

  const envelope = {
    id,
    kind: ALNMessageKinds.INTENT_REQUEST,
    intent: intentName,
    timestamp: Date.now(),
    payload: inputPayload,
    ...(meta ? { meta } : {})
  };

  const envelopeValidation = validateMessageEnvelope(envelope);
  if (!envelopeValidation.valid) {
    throw new Error(`Invalid envelope: ${envelopeValidation.errors.join("; ")}`);
  }

  return envelope;
}

/**
 * Create a canonical ALN execution result envelope, including validation
 * of the output payload against the intent spec.
 *
 * @param {string} id
 * @param {string} intentName
 * @param {object} outputPayload
 * @param {object} [meta]
 * @returns {ALNMessageEnvelope}
 * @throws {Error} when validation fails
 */
export function createExecutionResult(id, intentName, outputPayload, meta) {
  const outputValidation = validateIntentOutput(intentName, outputPayload);
  if (!outputValidation.valid) {
    throw new Error(
      `Invalid output for intent "${intentName}": ${outputValidation.errors.join("; ")}`
    );
  }

  const envelope = {
    id,
    kind: ALNMessageKinds.EXECUTION_RESULT,
    intent: intentName,
    timestamp: Date.now(),
    payload: outputPayload,
    ...(meta ? { meta } : {})
  };

  const envelopeValidation = validateMessageEnvelope(envelope);
  if (!envelopeValidation.valid) {
    throw new Error(`Invalid envelope: ${envelopeValidation.errors.join("; ")}`);
  }

  return envelope;
}

/**
 * Create a heartbeat message for liveness, nanoswarm-node status, or
 * neuromorphic BCI-link health monitoring.
 *
 * @param {string} id
 * @param {object} [payload]
 * @param {object} [meta]
 * @returns {ALNMessageEnvelope}
 */
export function createHeartbeat(id, payload = {}, meta) {
  const envelope = {
    id,
    kind: ALNMessageKinds.HEARTBEAT,
    timestamp: Date.now(),
    payload,
    ...(meta ? { meta } : {})
  };

  const envelopeValidation = validateMessageEnvelope(envelope);
  if (!envelopeValidation.valid) {
    throw new Error(`Invalid heartbeat envelope: ${envelopeValidation.errors.join("; ")}`);
  }

  return envelope;
}

/**
 * Create an error message envelope that adheres to ALN messaging guidelines.
 *
 * @param {string} id
 * @param {string} code
 * @param {string} messageText
 * @param {object} [details]
 * @param {object} [meta]
 * @returns {ALNMessageEnvelope}
 */
export function createErrorMessage(id, code, messageText, details = {}, meta) {
  const payload = {
    code,
    message: messageText,
    details
  };

  const envelope = {
    id,
    kind: ALNMessageKinds.ERROR,
    timestamp: Date.now(),
    payload,
    ...(meta ? { meta } : {})
  };

  const envelopeValidation = validateMessageEnvelope(envelope);
  if (!envelopeValidation.valid) {
    throw new Error(`Invalid error envelope: ${envelopeValidation.errors.join("; ")}`);
  }

  return envelope;
}

/**
 * Describe the ALN specification for introspection, tooling, and
 * meta-programming across IDEs, swarm controllers, or BCI research rigs.
 *
 * @returns {{
 *   version: string,
 *   languageName: string,
 *   shortName: string,
 *   supportedIntents: string[]
 * }}
 */
export function describeALN() {
  return {
    version: ALNSpec.version,
    languageName: ALNSpec.identity.languageName,
    shortName: ALNSpec.identity.shortName,
    supportedIntents: Object.keys(ALNSpec.intents)
  };
}

// Default export for convenience in existing codebases.
export default ALNSpec;
