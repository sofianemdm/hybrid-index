import { serializeAvatar, avatarMapByUserId, type AvatarView } from "../src/common/avatar.serializer";
import type { Avatar } from "@prisma/client";

/**
 * Sérialiseur d'avatar — SOURCE UNIQUE de la forme JSON exposée (profil public, /me/avatar, et
 * désormais chaque ligne de classement). On verrouille ici la forme exacte et le décodage de
 * `diceOptions` (chaîne JSON en base → objet en sortie), pour que le mobile décode toujours pareil.
 */
function makeAvatar(over: Partial<Avatar> = {}): Avatar {
  return {
    userId: "u1",
    skinTone: 3,
    hairStyle: 2,
    hairColor: 4,
    beardStyle: 1,
    accessory: 0,
    background: 5,
    photoData: null,
    diceStyle: "adventurer",
    diceSeed: "seed-xyz",
    diceOptions: JSON.stringify({ skinColor: "f2d3b1", hair: "long01" }),
    equippedCosmetics: {},
    unlockedCosmetics: {},
    updatedAt: new Date(),
    ...over,
  } as Avatar;
}

describe("avatar.serializer — forme JSON publique stable", () => {
  it("mappe tous les champs et décode diceOptions (JSON string → objet)", () => {
    const view = serializeAvatar(makeAvatar());
    const expected: AvatarView = {
      skinTone: 3,
      hairStyle: 2,
      hairColor: 4,
      beardStyle: 1,
      accessory: 0,
      background: 5,
      photoData: null,
      diceStyle: "adventurer",
      diceSeed: "seed-xyz",
      diceOptions: { skinColor: "f2d3b1", hair: "long01" },
    };
    expect(view).toEqual(expected);
  });

  it("diceOptions null en base → null en sortie", () => {
    const view = serializeAvatar(makeAvatar({ diceOptions: null }));
    expect(view?.diceOptions).toBeNull();
  });

  it("beardStyle nullable préservé", () => {
    const view = serializeAvatar(makeAvatar({ beardStyle: null }));
    expect(view?.beardStyle).toBeNull();
  });

  it("avatar absent (null/undefined) → null (repli mobile)", () => {
    expect(serializeAvatar(null)).toBeNull();
    expect(serializeAvatar(undefined)).toBeNull();
  });

  it("avatarMapByUserId : une seule liste batch → map userId -> vignette, sans entrée fantôme", () => {
    const map = avatarMapByUserId([makeAvatar({ userId: "a" }), makeAvatar({ userId: "b", diceSeed: "b-seed" })]);
    expect(map.size).toBe(2);
    expect(map.get("a")?.diceSeed).toBe("seed-xyz");
    expect(map.get("b")?.diceSeed).toBe("b-seed");
    expect(map.get("c")).toBeUndefined(); // utilisateur sans avatar → absent → l'appelant met null
  });

  it("avatarMapByUserId : liste vide → map vide", () => {
    expect(avatarMapByUserId([]).size).toBe(0);
  });
});
