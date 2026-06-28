import {
  withinQuietHours,
  underDailyCap,
  cooldownElapsed,
  prefEnabled,
} from "../src/modules/engagement/notification-gating";

/** Construit une Date locale au jour fixe avec l'heure HH:MM (les helpers lisent l'heure locale). */
function at(hh: number, mm: number): Date {
  return new Date(2026, 5, 28, hh, mm, 0, 0);
}

describe("withinQuietHours", () => {
  it("fenêtre normale (08:00→18:00) : silence pendant, pas avant/après", () => {
    const qh = { start: "08:00", end: "18:00" };
    expect(withinQuietHours(at(7, 59), qh)).toBe(false);
    expect(withinQuietHours(at(8, 0), qh)).toBe(true); // borne start incluse
    expect(withinQuietHours(at(12, 0), qh)).toBe(true);
    expect(withinQuietHours(at(17, 59), qh)).toBe(true);
    expect(withinQuietHours(at(18, 0), qh)).toBe(false); // borne end exclue
  });

  it("fenêtre enjambant minuit (22:00→07:00) : silence le soir ET le matin", () => {
    const qh = { start: "22:00", end: "07:00" };
    expect(withinQuietHours(at(22, 0), qh)).toBe(true); // début du soir
    expect(withinQuietHours(at(23, 30), qh)).toBe(true);
    expect(withinQuietHours(at(0, 0), qh)).toBe(true); // minuit
    expect(withinQuietHours(at(6, 59), qh)).toBe(true); // juste avant la fin
    expect(withinQuietHours(at(7, 0), qh)).toBe(false); // borne end exclue
    expect(withinQuietHours(at(12, 0), qh)).toBe(false); // milieu de journée
    expect(withinQuietHours(at(21, 59), qh)).toBe(false); // juste avant le début
  });

  it("fenêtre nulle (start == end) : jamais de silence", () => {
    expect(withinQuietHours(at(9, 0), { start: "09:00", end: "09:00" })).toBe(false);
  });

  it("absente ou bornes invalides : pas de silence (fail-open)", () => {
    expect(withinQuietHours(at(23, 0), null)).toBe(false);
    expect(withinQuietHours(at(23, 0), undefined)).toBe(false);
    expect(withinQuietHours(at(23, 0), { start: "nope", end: "07:00" })).toBe(false);
    expect(withinQuietHours(at(23, 0), { start: "25:00", end: "07:00" })).toBe(false);
  });
});

describe("underDailyCap", () => {
  it("autorise tant que countToday < dailyCap", () => {
    expect(underDailyCap(0, 2)).toBe(true);
    expect(underDailyCap(1, 2)).toBe(true);
  });
  it("bloque une fois le plafond atteint ou dépassé", () => {
    expect(underDailyCap(2, 2)).toBe(false);
    expect(underDailyCap(3, 2)).toBe(false);
  });
  it("cap <= 0 ou invalide : aucun envoi autorisé", () => {
    expect(underDailyCap(0, 0)).toBe(false);
    expect(underDailyCap(0, -1)).toBe(false);
    expect(underDailyCap(0, NaN)).toBe(false);
  });
});

describe("cooldownElapsed", () => {
  const now = at(12, 0);
  it("jamais envoyé (lastSentAt null) : écoulé", () => {
    expect(cooldownElapsed(null, now, 3600)).toBe(true);
    expect(cooldownElapsed(undefined, now, 3600)).toBe(true);
  });
  it("cooldown nul ou négatif : toujours écoulé", () => {
    expect(cooldownElapsed(at(11, 59), now, 0)).toBe(true);
    expect(cooldownElapsed(at(11, 59), now, -10)).toBe(true);
  });
  it("écoulé : délai dépassé", () => {
    // dernier envoi il y a 2h, cooldown 1h → écoulé
    expect(cooldownElapsed(at(10, 0), now, 3600)).toBe(true);
  });
  it("pas écoulé : délai non atteint", () => {
    // dernier envoi il y a 30min, cooldown 1h → pas écoulé
    expect(cooldownElapsed(at(11, 30), now, 3600)).toBe(false);
  });
  it("borne exacte (elapsed == cooldown) : écoulé", () => {
    expect(cooldownElapsed(at(11, 0), now, 3600)).toBe(true);
  });
});

describe("prefEnabled (opt-out)", () => {
  it("absent des prefs : activé par défaut", () => {
    expect(prefEnabled({}, "rank-overtaken")).toBe(true);
    expect(prefEnabled(null, "rank-overtaken")).toBe(true);
    expect(prefEnabled(undefined, "rank-overtaken")).toBe(true);
  });
  it("explicitement false : désactivé", () => {
    expect(prefEnabled({ "rank-overtaken": false }, "rank-overtaken")).toBe(false);
  });
  it("explicitement true : activé", () => {
    expect(prefEnabled({ "rank-overtaken": true }, "rank-overtaken")).toBe(true);
  });
});
