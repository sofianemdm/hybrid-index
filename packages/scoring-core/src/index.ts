/**
 * @hybrid-index/scoring-core — logique PURE du HYBRID INDEX.
 * Chaîne : percentile → courbe f → sous-score → attribut (no-drop, D2/D3) → Index pondéré.
 */
export * from "./math/normal";
export * from "./curve";
export * from "./distribution";
export * from "./weights";
export * from "./attribute";
export * from "./index-score";
export * from "./population-norms";
