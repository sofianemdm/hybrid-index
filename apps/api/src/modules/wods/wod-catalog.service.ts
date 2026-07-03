import { Injectable, NotFoundException } from "@nestjs/common";
import type { AttributeKey, Sex } from "@prisma/client";
import type { internalScore } from "@hybrid-index/contracts";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { WOD_PRESCRIPTIONS } from "./wod-prescriptions.data";
import { isScalable, type WodPrescription } from "./wod-prescription.types";
import { WOD_REFERENCES } from "./wod-references.data";
import { FLAGSHIP_WOD_IDS, HIDDEN_WOD_IDS, OTHER_WOD_IDS, ovrSub } from "./wod-constants";

/** Attributs qu'un WOD ne donne qu'en ESTIMÉ (proxy poids du corps, ou séance d'estimation
 *  globale) : ils ne « comptent » donc PAS pour préciser cette qualité dans le plan de complétion
 *  (sinon on re-proposerait à l'infini une séance qui ne mesure pas vraiment l'attribut). */
const ESTIMATED_COVERAGE: Record<string, string[]> = {
  max_pushups: ["strength"],
  max_air_squats: ["strength"],
  profil_express: ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"],
};

/**
 * LECTURE du domaine WOD — extrait de l'ex-wods.service (752 lignes) au découpage du 03/07 :
 * catalogue, fiche détaillée, mouvements, plan de complétion, prédiction, classement.
 * L'ÉCRITURE vit ailleurs : création/édition (WodBuilderService), log de résultat (WodsService).
 */
@Injectable()
export class WodCatalogService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
  ) {}

  movements(): Promise<internalScore.MovementSummary[]> {
    return this.scoreClient.getMovements();
  }

  /** Séances minimales (set cover glouton) couvrant les attributs encore NON débloqués, afin de
   *  révéler l'Index complet. Exclut les épreuves « Autre » et les WODs custom ; privilégie le
   *  sans-matériel à couverture égale. */
  async completionPlan(
    userId: string,
  ): Promise<{ missing: string[]; sessions: Array<{ wodId: string; name: string; requiresEquipment: boolean; covers: string[] }> }> {
    const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];
    const attrs = await this.prisma.attributeScore.findMany({ where: { userId }, select: { attribute: true, unlocked: true, isEstimated: true } });
    // « À faire » = attribut verrouillé OU encore ESTIMÉ (ex. après Profil Express) : on propose des
    // séances ciblées pour le mesurer pour de vrai et préciser la note.
    const done = new Set(attrs.filter((a) => a.unlocked && !a.isEstimated).map((a) => a.attribute));
    const remaining = new Set<string>(ATTRS.filter((a) => !done.has(a)));
    const missing = [...remaining];
    if (remaining.size === 0) return { missing: [], sessions: [] };

    const wods = await this.prisma.wod.findMany({
      // On exclut « Autre », masqués, ET profil_express (il ne donne que de l'ESTIMÉ → ne précise rien).
      where: { isCustom: false, id: { notIn: [...OTHER_WOD_IDS, ...HIDDEN_WOD_IDS, "profil_express"] } },
      select: { id: true, name: true, requiresEquipment: true, targetAttributes: true },
      orderBy: { requiresEquipment: "asc" }, // à couverture égale, le sans-matériel d'abord
    });

    const sessions: Array<{ wodId: string; name: string; requiresEquipment: boolean; covers: string[] }> = [];
    const chosen = new Set<string>();
    // Nouvel arrivant : radar encore LARGEMENT incomplet (≥ 3 des 6 qualités non mesurées pour de
    // vrai) ET « Profil Express » pas encore fait → on le conseille EN PREMIER : une seule séance
    // sans matériel qui estime les 6 qualités, pour un Index de départ plus complet/fin. On ne le
    // re-propose plus une fois fait (il ne donne que de l'ESTIMÉ → resterait sinon dans `remaining`).
    if (remaining.size >= 3) {
      const alreadyDone = await this.prisma.wodResult.findFirst({
        where: { userId, wodId: "profil_express" },
        select: { id: true },
      });
      if (!alreadyDone) {
        const pe = await this.prisma.wod.findUnique({
          where: { id: "profil_express" },
          select: { id: true, name: true, requiresEquipment: true },
        });
        if (pe) {
          // Nouvel arrivant : on propose UNIQUEMENT le Profil Express d'abord (1 séance qui estime
          // les 6 qualités → Index complet estimé). Les séances de PRÉCISION viennent APRÈS l'avoir fait.
          return {
            missing,
            sessions: [{ wodId: pe.id, name: pe.name, requiresEquipment: pe.requiresEquipment, covers: [...remaining] }],
          };
        }
      }
    }
    while (remaining.size > 0) {
      let best: (typeof wods)[number] | null = null;
      let bestCover: string[] = [];
      for (const w of wods) {
        if (chosen.has(w.id)) continue;
        const estOnly = ESTIMATED_COVERAGE[w.id] ?? [];
        const cover = (w.targetAttributes as string[]).filter((t) => remaining.has(t) && !estOnly.includes(t));
        if (cover.length > bestCover.length) {
          best = w;
          bestCover = cover;
        }
      }
      if (!best || bestCover.length === 0) break;
      chosen.add(best.id);
      sessions.push({ wodId: best.id, name: best.name, requiresEquipment: best.requiresEquipment, covers: bestCover });
      bestCover.forEach((c) => remaining.delete(c));
    }
    return { missing, sessions };
  }

  /** Reconstruit l'énoncé (« déroulé ») d'un WOD communautaire à partir de ses mouvements stockés,
   *  pour que les autres utilisateurs voient comment le faire. */
  private async buildCustomPrescription(wod: {
    type: string;
    rounds: number | null;
    timeCapSec: number | null;
    scoreType: string;
    movements: unknown;
  }): Promise<WodPrescription> {
    const movements = await this.scoreClient.getMovements();
    const nameById = new Map(movements.map((m) => [m.id, m.name]));
    const FMT: Record<string, string> = {
      for_time: "Pour le temps",
      amrap: "AMRAP",
      emom: "EMOM",
      chipper: "Pour le temps",
      interval: "Intervalles",
      tabata: "Tabata",
      strength: "Force",
      distance: "Distance / temps",
    };
    const roundsPrefix = wod.rounds && wod.rounds > 1 ? `${wod.rounds} tours · ` : "";
    const capSuffix = wod.timeCapSec ? ` · cap ${Math.round(wod.timeCapSec / 60)} min` : "";
    const blocks = (wod.movements as Array<{ movementId: string; reps?: number; distanceMeters?: number; calories?: number; durationSec?: number; loadKg?: number }>).map((b) => {
      const reps =
        b.distanceMeters != null ? `${b.distanceMeters} m` : b.calories != null ? `${b.calories} cal` : b.durationSec != null ? `${b.durationSec} s` : `${b.reps ?? 0}`;
      return { reps, movement: nameById.get(b.movementId) ?? b.movementId, detail: b.loadKg ? `${b.loadKg} kg` : undefined };
    });
    const scoringNote =
      wod.scoreType === "time"
        ? "Tu enregistres ton temps total."
        : wod.scoreType === "load"
          ? "Tu enregistres la charge (kg)."
          : wod.scoreType === "distance"
            ? "Tu enregistres la distance / le temps."
            : "Tu enregistres ton nombre total de répétitions.";
    return {
      summary: `Séance créée par la communauté${wod.rounds && wod.rounds > 1 ? `, ${wod.rounds} tours` : ""}. Enchaîne les mouvements ci-dessous.`,
      format: `${roundsPrefix}${FMT[wod.type] ?? wod.type}${capSuffix}`,
      timeCapSec: wod.timeCapSec ?? undefined,
      blocks,
      weights: [],
      scoringNote,
    };
  }

  /**
   * Bloc « guidé » dérivé pour le LECTEUR de séance (Mode guidé), exposé à TOUS (énoncé public,
   * non sensible). Aucune migration : tout vient de `wod.type` / `wod.rounds` / `timeCapSec` et des
   * `blocks` de la prescription. La structure work/rest n'étant PAS stockée en base, `work[]` n'est
   * rempli QUE pour Tabata (constantes canoniques 20/10) ; les autres formats à fenêtres (EMOM/
   * intervalles) sont reconstruits côté client à partir de `rounds`/`capSec`. C'est l'ajout API
   * minimal du plan : il garantit que le client dispose toujours de `format` + `rounds` + `capSec`.
   */
  private buildGuided(
    wod: { type: string; rounds: number | null; timeCapSec: number | null },
    prescription: WodPrescription | null,
  ): {
    format: string;
    rounds: number | null;
    capSec: number | null;
    work: Array<{ kind: "work" | "rest"; durationSec: number }>;
    cues: string[];
  } {
    const capSec = prescription?.timeCapSec ?? wod.timeCapSec ?? null;
    // Consignes = chaque ligne de l'énoncé, « reps mouvement (détail) », pour l'affichage au repos.
    const cues = (prescription?.blocks ?? []).map((b) => {
      const head = [b.reps, b.movement].filter((s) => s && s.trim().length > 0).join(" ").trim();
      return b.detail && b.detail.trim().length > 0 ? `${head} (${b.detail.trim()})` : head;
    });
    // work[] : uniquement les fenêtres CANONIQUES connues sans donnée structurée (Tabata 20/10).
    const work: Array<{ kind: "work" | "rest"; durationSec: number }> = [];
    if (wod.type === "tabata") {
      work.push({ kind: "work", durationSec: 20 }, { kind: "rest", durationSec: 10 });
    }
    return { format: wod.type, rounds: wod.rounds ?? null, capSec, work, cues };
  }

  async catalog(): Promise<unknown[]> {
    const wods = await this.prisma.wod.findMany({
      where: { id: { notIn: HIDDEN_WOD_IDS } },
      orderBy: [{ requiresEquipment: "asc" }, { name: "asc" }],
    });
    return wods.map((w) => ({
      id: w.id,
      name: w.name,
      type: w.type,
      scoreType: w.scoreType,
      requiresEquipment: w.requiresEquipment,
      targetAttributes: w.targetAttributes,
      isBenchmark: w.isBenchmark,
      isFlagship: FLAGSHIP_WOD_IDS.includes(w.id),
      isOther: OTHER_WOD_IDS.includes(w.id),
      isCustom: w.isCustom,
    }));
  }

  /** Fiche détaillée : métadonnées + paliers de référence (score-service) + ton meilleur effort. */
  async detail(id: string, userId?: string): Promise<unknown> {
    const wod = await this.prisma.wod.findUnique({ where: { id } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });
    // IDENTIFIANTS CANONIQUES des mouvements de la séance, dans l'ordre et sans doublon. Le guide des
    // mouvements (mobile) s'en sert pour NE PLUS deviner par le nom FR de la prescription.
    //  - WOD CUSTOM   → movementId des blocs enregistrés (wod.movements jsonb), ordonnés/dédupliqués ;
    //  - benchmark/Ligue → movementIds du blueprint, fournis par le score-service (cf. plus bas) ;
    //  - sinon (course pure, max-reps…) → [].
    let movementIds: string[] = [];
    if (wod.isCustom) {
      const seen = new Set<string>();
      for (const b of (wod.movements as Array<{ movementId?: unknown }>) ?? []) {
        const id = typeof b?.movementId === "string" ? b.movementId : null;
        if (id && !seen.has(id)) {
          seen.add(id);
          movementIds.push(id);
        }
      }
    }

    // Toujours assigné ci-dessous (try/catch des DEUX branches) → pas d'initialiseur (lint no-useless-assignment).
    let levels: unknown;
    if (wod.isCustom) {
      // WOD communautaire : pas de barème officiel → on REJOUE l'estimation (par sexe) à partir des
      // mouvements enregistrés pour fournir les paliers champion / intermédiaire / débutant
      // (cohérent avec l'aperçu du constructeur).
      try {
        const base = {
          scoreType: wod.scoreType,
          wodType: wod.type,
          timeCapSec: wod.timeCapSec ?? undefined,
          rounds: wod.rounds ?? undefined,
          blocks: wod.movements as internalScore.WodBlockInput[],
        };
        const [m, f] = await Promise.all([
          this.scoreClient.computeEstimate({ ...base, sex: "male" }),
          this.scoreClient.computeEstimate({ ...base, sex: "female" }),
        ]);
        const triple = (refs: internalScore.ComputeEstimateResponse["references"]) => {
          const get = (lvl: string) => Math.round(refs.find((r) => r.level === lvl)?.rawResult ?? 0);
          return { champion: get("champion"), intermediate: get("intermediate"), occasional: get("occasional") };
        };
        const ml = triple(m.references);
        const fl = triple(f.references);
        // Estimation NON disponible (ex. charge sans mouvement chargé) → paliers à 0 des deux côtés :
        // on n'affiche AUCUN palier plutôt qu'un « 0 kg » trompeur (cf. §A « Création de séance AAA »).
        const allZero = (l: { champion: number; intermediate: number; occasional: number }) =>
          l.champion <= 0 && l.intermediate <= 0 && l.occasional <= 0;
        levels = allZero(ml) && allZero(fl) ? null : { male: ml, female: fl };
      } catch {
        levels = null;
      }
    } else {
      try {
        const wodLevels = await this.scoreClient.getWodLevels(id);
        levels = wodLevels;
        // movementIds canoniques du blueprint, transportés par la même réponse (pas de round-trip
        // supplémentaire). Absents (back ancien) ⇒ [] (course pure / WOD sans blueprint).
        movementIds = wodLevels.movementIds ?? [];
      } catch {
        levels = null; // barème indisponible (score-service down) → movementIds reste []
      }
    }

    let myBest: unknown = null;
    let myHistory: unknown[] = [];
    if (userId) {
      const baseWhere = { userId, wodId: id, review: "ok" as const, subScore: { not: null } };
      const [best, mine] = await Promise.all([
        // Meilleur effort sur TOUT l'historique (la donnée de fierté ne doit jamais régresser).
        this.prisma.wodResult.findFirst({ where: baseWhere, orderBy: { subScore: "desc" } }),
        // Les 30 prestations les plus récentes (affichage de l'historique).
        this.prisma.wodResult.findMany({ where: baseWhere, orderBy: { performedAt: "desc" }, take: 30 }),
      ]);
      myHistory = mine.map((r) => ({
        rawResult: Number(r.rawResult),
        subScore: ovrSub(r.subScore),
        rxCompliant: r.rxCompliant,
        performedAt: r.performedAt.toISOString(),
      }));
      if (best) {
        myBest = {
          rawResult: Number(best.rawResult),
          subScore: ovrSub(best.subScore),
          performedAt: best.performedAt.toISOString(),
        };
      }
    }

    // Énoncé concret : barème de référence, ou reconstruit pour un WOD communautaire.
    const prescription: WodPrescription | null =
      WOD_PRESCRIPTIONS[wod.id] ?? (wod.isCustom ? await this.buildCustomPrescription(wod).catch(() => null) : null);

    return {
      id: wod.id,
      name: wod.name,
      type: wod.type,
      scoreType: wod.scoreType,
      requiresEquipment: wod.requiresEquipment,
      targetAttributes: wod.targetAttributes,
      isBenchmark: wod.isBenchmark,
      isFlagship: FLAGSHIP_WOD_IDS.includes(wod.id),
      isCustom: wod.isCustom,
      // Vrai uniquement si l'utilisateur connecté est le créateur d'un WOD communautaire : le mobile
      // n'affiche les actions Éditer/Supprimer QUE dans ce cas (mêmes garde-fous que PATCH/DELETE).
      isMine: wod.isCustom && userId != null && wod.createdById === userId,
      levels,
      // IDs canoniques des mouvements (blueprint pour benchmark/Ligue, blocs pour custom, [] sinon) :
      // le guide des mouvements du mobile les résout directement, sans deviner par le nom.
      movementIds,
      myBest,
      myHistory, // mes prestations passées sur cette séance (récent → ancien)
      // Énoncé concret de la séance (mouvements + poids) : barème de référence, ou reconstruit
      // depuis les mouvements enregistrés pour un WOD communautaire (« comment faire la séance »).
      prescription,
      // Bloc dérivé pour le LECTEUR de séance guidée (format + rounds + cap + cues + fenêtres
      // canoniques). Exposé à TOUS (énoncé public). Le client construit son `GuidedPlan` dessus,
      // avec repli sur `type`/`timeCapSec` si ce bloc venait à manquer (vieux back).
      guided: this.buildGuided(wod, prescription),
      // Source unique de vérité pour le toggle Rx/Allégé côté mobile : un WOD n'est
      // « scalable » que s'il porte au moins une charge adaptable (isScalable de la prescription).
      scalable: prescription ? isScalable(prescription) : false,
      // Cibles « Référence Pro » (données publiques) à viser sur cette séance.
      references: WOD_REFERENCES[wod.id] ?? [],
      // Payload BRUT pour ré-ouvrir le constructeur pré-rempli (mêmes champs que CreateWodRequest).
      // Fourni UNIQUEMENT au créateur d'un WOD custom (sinon inutile, et on ne divulgue pas les blocs
      // d'édition d'autrui). `movements` est déjà au format des blocs du builder.
      editPayload:
        wod.isCustom && userId != null && wod.createdById === userId
          ? {
              name: wod.name,
              type: wod.type,
              scoreType: wod.scoreType,
              requiresEquipment: wod.requiresEquipment,
              timeCapSec: wod.timeCapSec,
              rounds: wod.rounds,
              blocks: wod.movements,
            }
          : null,
    };
  }

  /**
   * Prédiction « d'après ton niveau, tu ferais ~X » sur un WOD de référence, pour la fiche du WOD.
   * Charge les scores d'attribut + le sexe de l'utilisateur, délègue l'inversion au score-service.
   * WOD introuvable → 404. `predictedRaw` peut être `null` (aucun attribut cible débloqué, ou WOD
   * non prédictible côté score-service : custom/free-run) — le mobile affiche alors un état neutre.
   */
  async prediction(id: string, userId: string): Promise<internalScore.PredictResultResponse> {
    const wod = await this.prisma.wod.findUnique({ where: { id }, select: { id: true, scoreType: true } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });

    const profile = await this.prisma.profile.findUnique({ where: { userId }, select: { sex: true } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    // Pas d'estimation « pour toi » tant que l'Index n'est pas COMPLET : prédire depuis des attributs
    // estimés/incomplets ne serait pas crédible. Même définition de « complet » que reveal_screen.dart :
    // ni provisoire, ni estimé, radar 6/6. Tant que ce n'est pas le cas → predictedRaw null (le mobile
    // masque la carte). L'utilisateur doit d'abord se construire un Index complet (~quelques séances).
    const idx = await this.prisma.hybridIndex.findUnique({
      where: { userId },
      select: { isProvisional: true, isEstimated: true, radarCoverage: true },
    });
    const indexComplete = idx != null && !idx.isProvisional && !idx.isEstimated && idx.radarCoverage >= 6;
    if (!indexComplete) {
      return { predictedRaw: null, scoreType: wod.scoreType as internalScore.PredictResultResponse["scoreType"] };
    }

    const scores = await this.prisma.attributeScore.findMany({
      where: { userId },
      select: { attribute: true, score: true, unlocked: true },
    });

    return this.scoreClient.predictResult({
      wodId: id,
      sex: profile.sex,
      attributeScores: scores.map((s) => ({ attribute: s.attribute, score: s.score, unlocked: s.unlocked })),
    });
  }

  /** Classement d'un WOD (meilleur effort par utilisateur, par sexe, variante Rx ou Scaled). */
  async leaderboard(id: string, sex: string, rx: boolean, userId?: string, memberIds?: string[]): Promise<unknown> {
    // Classement par PERFORMANCE RÉELLE (même WOD, même sexe, même variante) : le temps le plus bas
    // gagne pour un WOD chronométré, le plus de reps/charge sinon. On NE trie PAS sur subScore : il
    // peut diverger du temps réel pour les comptes de démonstration → l'ordre paraîtrait incohérent
    // avec les temps affichés. Le tri sur la perf brute est toujours cohérent avec l'affichage.
    const wod = await this.prisma.wod.findUnique({ where: { id }, select: { scoreType: true } });
    const better: "asc" | "desc" = wod?.scoreType === "time" ? "asc" : "desc";
    const rows = await this.prisma.wodResult.findMany({
      where: {
        wodId: id,
        sex: sex as Sex,
        review: "ok",
        subScore: { not: null },
        rxCompliant: rx,
        ...(memberIds ? { userId: { in: memberIds } } : {}), // filtre « Mon club » (C3)
      },
      // Tie-break déterministe : à perf égale, le plus petit userId. MÊME règle que le calcul de
      // « ma position » (`me` ci-dessous) → liste et position ne divergent jamais (audit BUG-007/008).
      orderBy: [{ rawResult: better }, { userId: "asc" }],
      distinct: ["userId"], // meilleur effort par utilisateur (premier dans l'ordre = sa meilleure perf)
      take: 100,
      select: { userId: true, subScore: true, rawResult: true },
    });
    const userIds = rows.map((r) => r.userId);
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, displayName: true, rank: true },
    });
    const names = new Map(profiles.map((p) => [p.userId, p]));
    // OVR /100 global de chaque athlète → grade affiché (cohérence du score, IC-01).
    const indices = await this.prisma.hybridIndex.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, value: true },
    });
    const ovrByUser = new Map(indices.map((h) => [h.userId, Math.round(ratingFromInternal(h.value))]));

    // « Ma position » sur ce WOD, MÊME hors top 100 (Strava/Garmin l'épinglent toujours). On la
    // calcule sur le meilleur effort par utilisateur, avec le même tie-break que la liste.
    let me: { position: number; rawResult: number; subScore: number | null } | null = null;
    if (userId) {
      const baseWhere = { wodId: id, sex: sex as Sex, review: "ok" as const, subScore: { not: null }, rxCompliant: rx };
      const myBest = await this.prisma.wodResult.findFirst({
        where: { ...baseWhere, userId },
        orderBy: [{ rawResult: better }, { performedAt: "asc" }],
        select: { rawResult: true, subScore: true },
      });
      if (myBest) {
        // Meilleur effort de chaque utilisateur (min pour le temps, max sinon), puis on compte ceux
        // STRICTEMENT devant moi. On agrège les deux (_min/_max) pour éviter une clé undefined.
        const groups = await this.prisma.wodResult.groupBy({
          by: ["userId"],
          where: baseWhere,
          _min: { rawResult: true },
          _max: { rawResult: true },
        });
        const myVal = Number(myBest.rawResult);
        const isBetter = (v: number) => (better === "asc" ? v < myVal : v > myVal);
        let above = 0;
        for (const g of groups) {
          if (g.userId === userId) continue;
          const v = Number((better === "asc" ? g._min.rawResult : g._max.rawResult) ?? myVal);
          if (isBetter(v)) above++;
          else if (v === myVal && g.userId < userId) above++; // ex æquo → tie-break userId asc
        }
        me = { position: above + 1, rawResult: myVal, subScore: ovrSub(myBest.subScore) };
      }
    }

    return {
      wodId: id,
      sex,
      me,
      entries: rows.map((r, i) => ({
        position: i + 1,
        userId: r.userId,
        displayName: names.get(r.userId)?.displayName ?? "—",
        rank: names.get(r.userId)?.rank ?? "rookie",
        index: ovrByUser.get(r.userId) ?? null,
        rawResult: Number(r.rawResult),
        subScore: ovrSub(r.subScore),
        isMe: r.userId === userId,
      })),
    };
  }
}
