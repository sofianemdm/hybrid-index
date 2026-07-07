// Défauts avataaars par sexe — PORT EXACT de `avataaarsDefaultsFor` (apps/mobile/lib/data/dicebear.dart).
// Utilisé par les scripts one-off (backfill, seed) pour produire le même rendu que l'éditeur mobile.
export function avataaarsDefaultsFor(sex: "male" | "female"): Record<string, string> {
  const female = sex === "female";
  return {
    skinColor: "edb98a",
    top: female ? "longButNotTooLong" : "shortFlat",
    hairColor: "2c1b18",
    facialHair: "none",
    facialHairColor: "2c1b18",
    accessories: "none",
    eyes: "default",
    mouth: "smile",
    eyebrows: "default",
  };
}
