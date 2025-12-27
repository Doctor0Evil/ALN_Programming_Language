// Path: src/core/ALNEngineManifest.js
// Engine-manifest generation for ALN-driven Javaspectre runs.

import { describeALN } from "aln-language-runtime/src/protocol/ALNSpec.js";
import { listCapabilities } from "../capabilities/JavaspectreCapabilities.js";

export function buildEngineManifest(context = {}) {
  const aln = describeALN();
  const capabilities = listCapabilities();

  return {
    engineId: "javaspectre-core",
    version: "1.0.0",
    aln: {
      version: aln.version,
      languageName: aln.languageName,
      shortName: aln.shortName,
      supportedIntents: aln.supportedIntents
    },
    capabilities: capabilities.map((c) => ({
      id: c.id,
      name: c.name,
      category: c.category,
      summary: c.summary,
      primaryCli: c.primaryCli,
      entryModule: c.entryModule
    })),
    policies: {
      codePurity: "JavaScript-only outputs, no placeholders.",
      replicationGuaranteeHours: 24
    },
    hostContext: context
  };
}

export default buildEngineManifest;
