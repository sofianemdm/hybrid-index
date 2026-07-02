import { Injectable, UnauthorizedException } from "@nestjs/common";
import { OAuth2Client } from "google-auth-library";

/**
 * Vérifie un ID token Google (signature + audience). Activé dès que `GOOGLE_CLIENT_ID` est défini.
 * Isolé derrière une classe pour pouvoir être mocké dans les tests.
 */
@Injectable()
export class GoogleTokenVerifier {
  private readonly clientId = process.env.GOOGLE_CLIENT_ID;
  private readonly client = new OAuth2Client(this.clientId);

  async verify(idToken: string): Promise<{ sub: string; email: string }> {
    if (!this.clientId) {
      throw new UnauthorizedException({
        code: "UNAUTHENTICATED",
        message: "Connexion Google non configurée (GOOGLE_CLIENT_ID manquant).",
      });
    }
    try {
      const ticket = await this.client.verifyIdToken({ idToken, audience: this.clientId });
      const payload = ticket.getPayload();
      if (!payload?.sub || !payload.email) throw new Error("payload incomplet");
      return { sub: payload.sub, email: payload.email };
    } catch (e) {
      // Diagnostic TEMPORAIRE : décode l'audience du token (sans vérifier la signature) pour repérer
      // un décalage `aud` (token) vs `GOOGLE_CLIENT_ID` (serveur). À retirer une fois Google OK.
      let aud = "?";
      try {
        const p = idToken.split(".")[1];
        aud = String(JSON.parse(Buffer.from(p, "base64").toString("utf8")).aud ?? "?");
      } catch {
        /* token illisible */
      }
      const reason = e instanceof Error ? e.message : String(e);
      throw new UnauthorizedException({
        code: "UNAUTHENTICATED",
        message: `Token Google invalide. [aud=${aud} | attendu=${this.clientId} | raison=${reason}]`,
      });
    }
  }
}
