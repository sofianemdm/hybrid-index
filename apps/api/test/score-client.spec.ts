import "reflect-metadata";
import { ScoreClient } from "../src/infra/score-client/score-client.service";

describe("ScoreClient (gestion d'erreur)", () => {
  it("renvoie 503 SCORE_SERVICE_UNAVAILABLE si le service est injoignable", async () => {
    // Port volontairement inutilisé → fetch échoue.
    const client = new ScoreClient("http://127.0.0.1:59999");
    await expect(
      client.computeProfile({ sex: "male", goal: "all_round", efforts: [] }),
    ).rejects.toMatchObject({ status: 503 });
  });
});
