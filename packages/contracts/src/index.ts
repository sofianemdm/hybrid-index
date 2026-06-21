/**
 * @hybrid-index/contracts — source de vérité des contrats partagés.
 * Réexporte enums, helpers de score purs, codes d'erreur et contrats internes.
 */
export * from "./enums";
export * from "./errors";
export * from "./domain/age-gating";
export * from "./domain/dm-age";
export * from "./scoring/rank";
export * as internalScore from "./internal/score";
export * as onboardingDto from "./dto/onboarding";
