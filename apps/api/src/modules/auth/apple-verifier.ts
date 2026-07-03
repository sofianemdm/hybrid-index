import { createPublicKey, verify as cryptoVerify, type KeyObject } from "node:crypto";
import { Injectable, UnauthorizedException } from "@nestjs/common";

/** Clé publique du JWKS Apple (format JWK RSA). */
interface AppleJwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
}

/**
 * Vérifie un identityToken « Sign in with Apple » (JWT RS256) SANS dépendance externe :
 *  - signature contre le JWKS public d'Apple (https://appleid.apple.com/auth/keys, importé via
 *    `crypto.createPublicKey({ format: "jwk" })`, cache mémoire 24 h) ;
 *  - émetteur `https://appleid.apple.com`, expiration, audience = APPLE_BUNDLE_ID (l'app iOS).
 * Particularité Apple : l'email n'est présent que dans le token (jamais côté serveur ensuite) et
 * peut être un relais privé @privaterelay.appleid.com — on le stocke tel quel.
 * Isolé derrière une classe pour être mocké dans les tests (comme GoogleTokenVerifier).
 */
@Injectable()
export class AppleTokenVerifier {
  static readonly ISSUER = "https://appleid.apple.com";
  static readonly JWKS_URL = "https://appleid.apple.com/auth/keys";
  private static readonly JWKS_TTL_MS = 24 * 60 * 60 * 1000;

  private jwksCache: { keys: AppleJwk[]; fetchedAt: number } | null = null;

  private get audience(): string | undefined {
    return process.env.APPLE_BUNDLE_ID;
  }

  /** JWKS Apple (protégé + caché pour être substituable en test). */
  protected async fetchJwks(): Promise<AppleJwk[]> {
    const res = await fetch(AppleTokenVerifier.JWKS_URL);
    if (!res.ok) throw new Error(`JWKS Apple indisponible (${res.status})`);
    const body = (await res.json()) as { keys: AppleJwk[] };
    return body.keys;
  }

  private async keyFor(kid: string): Promise<KeyObject | null> {
    const fresh = this.jwksCache && Date.now() - this.jwksCache.fetchedAt < AppleTokenVerifier.JWKS_TTL_MS;
    if (!fresh) {
      this.jwksCache = { keys: await this.fetchJwks(), fetchedAt: Date.now() };
    }
    let jwk = this.jwksCache!.keys.find((k) => k.kid === kid);
    // Rotation de clés Apple : kid inconnu avec un cache encore « frais » → re-fetch une fois.
    if (!jwk && fresh) {
      this.jwksCache = { keys: await this.fetchJwks(), fetchedAt: Date.now() };
      jwk = this.jwksCache.keys.find((k) => k.kid === kid);
    }
    if (!jwk) return null;
    return createPublicKey({ key: jwk as unknown as Record<string, string>, format: "jwk" });
  }

  async verify(identityToken: string): Promise<{ sub: string; email: string | null }> {
    if (!this.audience) {
      throw new UnauthorizedException({
        code: "UNAUTHENTICATED",
        message: "Connexion Apple non configurée (APPLE_BUNDLE_ID manquant).",
      });
    }
    try {
      const [h, p, sig] = identityToken.split(".");
      if (!h || !p || !sig) throw new Error("format JWT invalide");
      const header = JSON.parse(Buffer.from(h, "base64url").toString("utf8")) as { kid?: string; alg?: string };
      if (header.alg !== "RS256" || !header.kid) throw new Error("en-tête inattendu");
      const key = await this.keyFor(header.kid);
      if (!key) throw new Error("clé Apple inconnue");
      const ok = cryptoVerify("RSA-SHA256", Buffer.from(`${h}.${p}`), key, Buffer.from(sig, "base64url"));
      if (!ok) throw new Error("signature invalide");

      const payload = JSON.parse(Buffer.from(p, "base64url").toString("utf8")) as {
        iss?: string;
        aud?: string;
        exp?: number;
        sub?: string;
        email?: string;
      };
      if (payload.iss !== AppleTokenVerifier.ISSUER) throw new Error("émetteur invalide");
      if (payload.aud !== this.audience) throw new Error("audience invalide");
      if (!payload.exp || payload.exp * 1000 < Date.now()) throw new Error("token expiré");
      if (!payload.sub) throw new Error("sub manquant");
      return { sub: payload.sub, email: payload.email?.toLowerCase().trim() ?? null };
    } catch {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token Apple invalide." });
    }
  }
}
