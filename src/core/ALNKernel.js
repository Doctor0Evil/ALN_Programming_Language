// File: src/core/ALNKernel.js
// Destination: /src/core/ALNKernel.js
//
// Production-ready ALNKernel implementation for ALN planning and compliance-aware
// reasoning pipelines. Includes deterministic ID generation, structured logging hooks,
// validation, and extension points suitable for enterprise runtimes. [file:2]

import crypto from "crypto";
import { ALNSpec } from "../protocol/ALNSpec.js"; // Must expose { intents: { [id]: { description?: string } } } [file:2]

/**
 * @typedef {Object} ALNKernelOptions
 * @property {string} [modelId]
 * @property {number} [maxReplicationHours]
 * @property {(event: string, payload: unknown) => void} [logger]
 */

/**
 * @typedef {Object} ALNConstraintSet
 * @property {string} language
 * @property {boolean} requireCompleteness
 * @property {boolean} forbidPlaceholders
 * @property {number} maxReplicationTimeHours
 * @property {string[]} jurisdictions
 * @property {string[]} providerPolicies
 * @property {string|null} dataResidency
 */

/**
 * @typedef {Object} ALNPlanStep
 * @property {string} id
 * @property {string} description
 * @property {Record<string, unknown>} output
 * @property {"low"|"medium"|"high"} [priority]
 */

/**
 * @typedef {Object} ALNTransparencyTrail
 * @property {string} planId
 * @property {string} modelId
 * @property {string} intentText
 * @property {string} intentType
 * @property {ALNConstraintSet} constraints
 * @property {string} createdAt
 * @property {string[]} assumptions
 * @property {string[]} risks
 * @property {string[]} tradeoffs
 */

/**
 * @typedef {Object} ALNPlanResult
 * @property {string} planId
 * @property {ALNPlanStep[]} steps
 * @property {ALNTransparencyTrail} transparencyTrail
 */

export class ALNKernel {
  /**
   * @param {ALNKernelOptions} [options]
   */
  constructor(options = {}) {
    /** @type {string} */
    this.modelId = options.modelId || "aln-runtime-v1"; // [file:2]
    /** @type {number} */
    this.maxReplicationHours = Number.isFinite(options.maxReplicationHours)
      ? options.maxReplicationHours
      : 24;

    /**
     * Optional structured logger hook, e.g. pino/winston wrapper. [file:2]
     * @type {(event: string, payload: unknown) => void}
     */
    this.logger =
      typeof options.logger === "function"
        ? options.logger
        : () => {
            /* no-op */
          };
  }

  /**
   * Generate a plan for the given intent. [file:2]
   *
   * @param {string} intentText
   * @param {string} [intentType]
   * @param {Partial<ALNConstraintSet>} [constraints]
   * @param {Record<string, unknown>} [context]
   * @returns {ALNPlanResult}
   */
  reason(intentText, intentType, constraints = {}, context = {}) {
    if (!intentText || typeof intentText !== "string") {
      throw new Error("ALNKernel.reason: intentText must be a non-empty string.");
    }

    const timestamp = new Date().toISOString();
    const planId = this._generatePlanId(intentText, timestamp);

    const normalized = this._normalizeConstraints(constraints);
    const resolvedIntentType = intentType || this._inferIntentType(intentText);
    const steps = this._synthesizeSteps(
      intentText,
      resolvedIntentType,
      normalized,
      context || {}
    );

    const transparencyTrail = /** @type {ALNTransparencyTrail} */ ({
      planId,
      modelId: this.modelId,
      intentText,
      intentType: resolvedIntentType,
      constraints: normalized,
      createdAt: timestamp,
      assumptions: this._deriveAssumptions(intentText, normalized),
      risks: this._deriveRisks(intentText),
      tradeoffs: this._deriveTradeoffs()
    });

    this._log("aln.plan.generated", {
      planId,
      modelId: this.modelId,
      stepCount: steps.length,
      intentType: resolvedIntentType,
      createdAt: timestamp
    });

    return { planId, steps, transparencyTrail };
  }

  /**
   * Deterministic plan ID generator using SHA-256. [file:2]
   *
   * @param {string} intentText
   * @param {string} timestamp
   * @returns {string}
   */
  _generatePlanId(intentText, timestamp) {
    const hash = crypto
      .createHash("sha256")
      .update(`${intentText}::${timestamp}::${this.modelId}`)
      .digest("hex");
    return hash.slice(0, 16);
  }

  /**
   * Apply defaults and validate constraints. [file:2]
   *
   * @param {Partial<ALNConstraintSet>} constraints
   * @returns {ALNConstraintSet}
   */
  _normalizeConstraints(constraints) {
    const defaults = {
      language: "JavaScript",
      requireCompleteness: true,
      forbidPlaceholders: true,
      maxReplicationTimeHours: this.maxReplicationHours,
      jurisdictions: [],
      providerPolicies: [],
      dataResidency: null
    };

    const merged = { ...defaults, ...(constraints || {}) };

    if (!Number.isFinite(merged.maxReplicationTimeHours) || merged.maxReplicationTimeHours <= 0) {
      merged.maxReplicationTimeHours = this.maxReplicationHours;
    }

    if (!Array.isArray(merged.jurisdictions)) {
      merged.jurisdictions = [];
    }
    if (!Array.isArray(merged.providerPolicies)) {
      merged.providerPolicies = [];
    }

    merged.language = typeof merged.language === "string" && merged.language.trim()
      ? merged.language.trim()
      : "JavaScript";

    merged.requireCompleteness = Boolean(merged.requireCompleteness);
    merged.forbidPlaceholders = Boolean(merged.forbidPlaceholders);

    this._log("aln.constraints.normalized", merged);
    return merged;
  }

  /**
   * Build execution steps with compliance and context awareness. [file:2]
   *
   * @param {string} intentText
   * @param {string} intentType
   * @param {ALNConstraintSet} constraints
   * @param {Record<string, unknown>} context
   * @returns {ALNPlanStep[]}
   */
  _synthesizeSteps(intentText, intentType, constraints, context) {
    /** @type {ALNPlanStep[]} */
    const steps = [];

    steps.push({
      id: "analyze-intent",
      description: "Classify intent and map to ALN intents.",
      output: {
        intentType: intentType || this._inferIntentType(intentText),
        matchedALNIntents: this._matchALNIntents(intentText)
      },
      priority: "high"
    });

    steps.push({
      id: "design-structure",
      description: "Design structures (files, workflows, compliance hooks).",
      output: {
        requiresRepoPlan: true,
        language: constraints.language,
        replicationHours: constraints.maxReplicationTimeHours
      },
      priority: "high"
    });

    if (constraints.jurisdictions.length || constraints.providerPolicies.length) {
      steps.push({
        id: "compliance-alignment",
        description: "Align plan with declared jurisdictions and policies.",
        output: {
          jurisdictions: constraints.jurisdictions,
          providerPolicies: constraints.providerPolicies,
          dataResidency: constraints.dataResidency
        },
        priority: "high"
      });
    }

    steps.push({
      id: "enforce-integrity",
      description: "Require complete, placeholder-free code outputs.",
      output: {
        requireCompleteness: constraints.requireCompleteness,
        forbidPlaceholders: constraints.forbidPlaceholders,
        validationRules: this._buildIntegrityValidationRules(constraints)
      },
      priority: "medium"
    });

    if (Object.keys(context || {}).length > 0) {
      steps.push({
        id: "context-alignment",
        description: "Align plan with host system context (chat, CI, runtime).",
        output: {
          contextKeys: Object.keys(context),
          environmentHints: this._inferEnvironmentHints(context)
        },
        priority: "medium"
      });
    }

    steps.push({
      id: "replication-strategy",
      description: "Guarantee 24-hour replication for a motivated developer.",
      output: {
        replicationGuaranteeHours: constraints.maxReplicationTimeHours,
        assumptions: [
          "Node.js LTS and Git available.",
          "GitHub or equivalent git host accessible."
        ],
        developerProfile: "motivated_single_developer"
      },
      priority: "medium"
    });

    this._log("aln.steps.synthesized", { count: steps.length });
    return steps;
  }

  /**
   * Infer coarse intent type. [file:2]
   *
   * @param {string} text
   * @returns {string}
   */
  _inferIntentType(text) {
    const lower = text.toLowerCase();
    if (lower.includes("workflow") || lower.includes("github")) return "ci_workflow";
    if (lower.includes("repo") || lower.includes("repository")) return "repository_plan";
    if (lower.includes("python") || lower.includes("notebook")) return "python_interop";
    if (lower.includes("policy") || lower.includes("compliance")) return "policy_plan";
    return "general_plan";
  }

  /**
   * Map free-text to ALN intents defined in ALNSpec. [file:2]
   *
   * @param {string} text
   * @returns {string[]}
   */
  _matchALNIntents(text) {
    const specIntents = ALNSpec && ALNSpec.intents ? ALNSpec.intents : {};
    const keys = Object.keys(specIntents);
    const lower = text.toLowerCase();

    /** @type {string[]} */
    const matched = [];

    for (const id of keys) {
      const intent = specIntents[id] || {};
      const description = (intent.description || "").toLowerCase();

      if (description.includes("repository") && lower.includes("repo")) {
        matched.push(id);
        continue;
      }
      if (id.includes("interop_python") && lower.includes("python")) {
        matched.push(id);
        continue;
      }
      if (id.includes("define_virtual_object") && lower.includes("virtual")) {
        matched.push(id);
        continue;
      }
      if (description.includes("policy") && lower.includes("policy")) {
        matched.push(id);
        continue;
      }
    }

    this._log("aln.intents.matched", { matchedCount: matched.length });
    return matched;
  }

  /**
   * Derive high-level assumptions for the plan. [file:3]
   *
   * @param {string} intentText
   * @param {ALNConstraintSet} constraints
   * @returns {string[]}
   */
  _deriveAssumptions(intentText, constraints) {
    const a = [];
    a.push("Outputs are intended for open-source or auditable environments.");
    a.push(`Target implementation language is ${constraints.language}.`);
    if (constraints.maxReplicationTimeHours <= 24) {
      a.push("A motivated developer can reproduce outputs within 24 hours.");
    }
    if (constraints.jurisdictions.length) {
      a.push("Plans must satisfy the strictest overlapping jurisdictional constraints.");
    }
    if (intentText.toLowerCase().includes("github")) {
      a.push("GitHub Actions or compatible CI is available.");
    }
    return a;
  }

  /**
   * Derive domain risks from text. [file:3]
   *
   * @param {string} intentText
   * @returns {string[]}
   */
  _deriveRisks(intentText) {
    const r = ["Risk of over-engineering structure for simple tasks."];
    const lower = intentText.toLowerCase();
    if (lower.includes("neuro") || lower.includes("bci") || lower.includes("eeg")) {
      r.push("Neurotech contexts require medical, ethical, and privacy reviews.");
    }
    if (lower.includes("pii") || lower.includes("personal data")) {
      r.push("Personal data processing must follow privacy and data protection rules.");
    }
    if (lower.includes("safety") || lower.includes("critical")) {
      r.push("Safety-critical systems require independent validation and redundancy.");
    }
    return r;
  }

  /**
   * List key tradeoffs of the ALN planning approach. [file:3]
   *
   * @returns {string[]}
   */
  _deriveTradeoffs() {
    return [
      "Favor explicit compliance boundaries over opaque behavior.",
      "Prefer auditability and reproducibility over micro-optimizations.",
      "Prioritize cross-environment determinism over environment-specific hacks."
    ];
  }

  /**
   * Build integrity validation rules for downstream execution engines. [file:3]
   *
   * @param {ALNConstraintSet} constraints
   * @returns {Record<string, unknown>}
   */
  _buildIntegrityValidationRules(constraints) {
    return {
      requireCompleteness: constraints.requireCompleteness,
      forbidPlaceholders: constraints.forbidPlaceholders,
      disallowedPatterns: [
        "TODO",
        "FIXME",
        "placeholder",
        "lorem ipsum",
        "<insert",
        "stub only"
      ],
      minLinesOfCode: 1
    };
  }

  /**
   * Infer runtime environment hints from context. [file:4]
   *
   * @param {Record<string, unknown>} context
   * @returns {Record<string, unknown>}
   */
  _inferEnvironmentHints(context) {
    const hints = {
      hasCI: false,
      hasKubernetes: false,
      hasNeuromorphicHardware: false,
      ciProvider: null,
      runtime: null
    };

    const ctxString = JSON.stringify(context).toLowerCase();

    if (ctxString.includes("github") || ctxString.includes("gitlab") || ctxString.includes("ci")) {
      hints.hasCI = true;
      if (ctxString.includes("github")) hints.ciProvider = "github_actions";
      else if (ctxString.includes("gitlab")) hints.ciProvider = "gitlab_ci";
      else hints.ciProvider = "generic_ci";
    }

    if (ctxString.includes("kubernetes") || ctxString.includes("k8s")) {
      hints.hasKubernetes = true;
    }

    if (
      ctxString.includes("neuromorphic") ||
      ctxString.includes("bci") ||
      ctxString.includes("eeg")
    ) {
      hints.hasNeuromorphicHardware = true;
    }

    if (ctxString.includes("node.js") || ctxString.includes("nodejs") || ctxString.includes("node")) {
      hints.runtime = "node";
    } else if (ctxString.includes("browser")) {
      hints.runtime = "browser";
    }

    return hints;
  }

  /**
   * Structured logging wrapper. [file:4]
   *
   * @param {string} event
   * @param {unknown} payload
   * @private
   */
  _log(event, payload) {
    try {
      this.logger(event, payload);
    } catch {
      // Never throw from logging path
    }
  }
}

export default ALNKernel;
