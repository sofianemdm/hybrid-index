import { describe, expect, it } from "vitest";
import { type ScoredEffort, attributeScore, computeRadar } from "./attribute";

const eff = (subScore: number, ageWeeks: number, tags: ScoredEffort["tags"]): ScoredEffort => ({
  subScore,
  ageWeeks,
  tags,
});

describe("attributeScore — no-drop (D3)", () => {
  it("prend le MEILLEUR effort, pas le dernier", () => {
    const efforts = [
      eff(800, 2, [{ attribute: "engine", estimated: false }]),
      eff(600, 1, [{ attribute: "engine", estimated: false }]), // plus récent mais moins bon
    ];
    const r = attributeScore("engine", efforts);
    expect(r.score).toBe(800);
    expect(r.unlocked).toBe(true);
  });

  it("un effort moins bon ajouté ne fait jamais baisser l'attribut", () => {
    const before = attributeScore("engine", [eff(800, 2, [{ attribute: "engine", estimated: false }])]);
    const after = attributeScore("engine", [
      eff(800, 2, [{ attribute: "engine", estimated: false }]),
      eff(500, 0, [{ attribute: "engine", estimated: false }]),
    ]);
    expect(after.score).toBe(before.score);
  });

  it("hors fenêtre 26 sem, conserve la dernière valeur connue + isStale", () => {
    const r = attributeScore("engine", [eff(700, 40, [{ attribute: "engine", estimated: false }])]);
    expect(r.unlocked).toBe(true);
    expect(r.score).toBe(700);
    expect(r.isStale).toBe(true);
  });

  it("isStale dès que le meilleur effort dépasse 10 sem", () => {
    expect(attributeScore("engine", [eff(700, 4, [{ attribute: "engine", estimated: false }])]).isStale).toBe(false);
    expect(attributeScore("engine", [eff(700, 12, [{ attribute: "engine", estimated: false }])]).isStale).toBe(true);
  });
});

describe("attributeScore — unlocked", () => {
  it("verrouillé si aucun effort ne tague l'attribut", () => {
    const r = attributeScore("hybrid", [eff(900, 1, [{ attribute: "engine", estimated: false }])]);
    expect(r.unlocked).toBe(false);
    expect(r.score).toBe(0);
  });
});

describe("attributeScore — proxy Force (D2)", () => {
  it("un test chargé réel fait autorité : le proxy ne le surclasse pas", () => {
    // Grace (réel) 76 sur strength ; pompes (proxy) 958 sur strength.
    const r = attributeScore("strength", [
      eff(76, 1, [{ attribute: "strength", estimated: false }]),
      eff(958, 1, [{ attribute: "strength", estimated: true }]),
    ]);
    expect(r.score).toBe(76);
    expect(r.isEstimated).toBe(false);
  });

  it("sans test chargé, le proxy est utilisé et l'attribut est estimé", () => {
    const r = attributeScore("strength", [eff(871, 1, [{ attribute: "strength", estimated: true }])]);
    expect(r.score).toBe(871);
    expect(r.isEstimated).toBe(true);
  });

  it("les pompes alimentent légitimement l'endurance musculaire (non estimée)", () => {
    const r = attributeScore("muscular_endurance", [eff(958, 1, [{ attribute: "muscular_endurance", estimated: false }])]);
    expect(r.score).toBe(958);
    expect(r.isEstimated).toBe(false);
  });
});

describe("computeRadar", () => {
  it("calcule les attributs demandés", () => {
    const radar = computeRadar(["engine", "strength"], [
      eff(800, 1, [{ attribute: "engine", estimated: false }]),
    ]);
    expect(radar).toHaveLength(2);
    expect(radar.find((a) => a.attribute === "engine")?.unlocked).toBe(true);
    expect(radar.find((a) => a.attribute === "strength")?.unlocked).toBe(false);
  });
});
