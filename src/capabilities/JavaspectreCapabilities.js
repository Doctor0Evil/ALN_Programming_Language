// Path: src/capabilities/JavaspectreCapabilities.js
// Central registry describing Javaspectre's spectral capabilities for AI chats and tools.

export const JavaspectreCapabilities = [
  {
    id: "zero-config-repo-blueprinting",
    index: 1,
    name: "Zero-Config Repo Blueprinting",
    category: "scaffolding",
    summary:
      "Analyzes a single prompt or code fragment and generates complete repository structures ready for git push in under 60 seconds.",
    entryModule: "src/blueprints/RepoBlueprint.js",
    primaryCli: "javaspectre make",
    inputs: ["prompt", "code-fragment"],
    outputs: ["repo-structure", "package-json", "tests", "ci-config"],
    guarantees: [
      "No manual configuration required.",
      "Valid package.json with scripts, license, and README stubs.",
      "Initial tests and CI prepared for immediate use."
    ],
    spectralTags: ["automation", "bootstrap", "repo", "blueprint"],
    sustainabilityImpact: {
      dimension: "developer-time",
      notes:
        "Reduces repetitive boilerplate work and misconfigured projects, lowering wasted compute from failed pipelines."
    },
    heuristicScore: 0.7
  },
  {
    id: "live-virtual-object-harvesting",
    index: 2,
    name: "Live Virtual-Object Harvesting",
    category: "introspection",
    summary:
      "Scans webpages, API responses, or DOM trees in real time, extracting hidden data shapes and emitting reusable type definitions and API wrappers.",
    entryModule: "src/core/VirtualObjectExcavator.js",
    primaryCli: "javaspectre inspect",
    inputs: ["url", "html-fragment", "json-response"],
    outputs: ["virtual-object-catalog", "type-definitions", "api-wrappers"],
    guarantees: [
      "No manual schema writing.",
      "Stable structural signatures for reuse.",
      "Supports DOM, JSON, and mixed payloads when integrated with a browser runner."
    ],
    spectralTags: ["dom", "api", "virtual-object", "schema"],
    sustainabilityImpact: {
      dimension: "data-efficiency",
      notes:
        "Encourages selective, schema-aware data access, reducing over-fetching and redundant API calls."
    },
    heuristicScore: 0.6
  },
  {
    id: "one-command-spectral-refinement",
    index: 3,
    name: "One-Command Spectral Refinement",
    category: "refinement",
    summary:
      "Transforms partial or rough code into production-grade modules with tests, docs, and performance optimizations via a single command.",
    entryModule: "src/capabilities/SpectralRefiner.js",
    primaryCli: "javaspectre refine",
    inputs: ["source-file", "repo-path"],
    outputs: ["refined-modules", "tests", "docs"],
    guarantees: [
      "Refined code remains compatible with original intent.",
      "Adds tests and basic documentation automatically.",
      "Targets idiomatic, modern JavaScript patterns."
    ],
    spectralTags: ["refactor", "optimization", "upgrade"],
    sustainabilityImpact: {
      dimension: "runtime-efficiency",
      notes:
        "Removes dead code and improves complexity to reduce CPU and memory waste."
    },
    heuristicScore: 0.8
  },
  {
    id: "sustainability-impact-calculator",
    index: 9,
    name: "Sustainability Impact Calculator",
    category: "sustainability",
    summary:
      "Embeds carbon footprint metrics, energy scores, and green-hosting suggestions into generated systems.",
    entryModule: "src/core/SustainabilityCore.js",
    primaryCli: "javaspectre impact",
    inputs: ["project-metadata", "estimated-usage"],
    outputs: ["impact-report", "optimization-recommendations"],
    guarantees: [
      "Uses transparent, documented estimation models.",
      "Highlights levers like hosting choice, caching, and data minimization.",
      "Exports impact snapshots for audits and reporting."
    ],
    spectralTags: ["sustainability", "carbon", "optimization"],
    sustainabilityImpact: {
      dimension: "planetary-impact",
      notes:
        "Encourages greener design choices and highlights optimization opportunities from inception."
    },
    heuristicScore: 0.9
  }
];

export function getCapabilityById(id) {
  return JavaspectreCapabilities.find((c) => c.id === id) || null;
}

export function listCapabilities() {
  return [...JavaspectreCapabilities];
}

export default JavaspectreCapabilities;
