import "reflect-metadata";
import { createSign, generateKeyPairSync } from "node:crypto";
import { UnauthorizedException } from "@nestjs/common";
import { AppleTokenVerifier } from "../src/modules/auth/apple-verifier";

/**
 * Vérificateur Apple : VRAIE crypto (paire RSA générée + JWT RS256 signé localement), seul le
 * fetch du JWKS est substitué. Couvre : token valide, mauvaise signature, mauvais émetteur,
 * mauvaise audience, expiration, kid inconnu, configuration absente.
 */
const AUD = "app.hybridindex.test";

const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const { publicKey: otherPub, privateKey: otherPriv } = generateKeyPairSync("rsa", { modulusLength: 2048 });
void otherPub;

const jwk = publicKey.export({ format: "jwk" }) as { kty: string; n: string; e: string };

class TestVerifier extends AppleTokenVerifier {
  protected override async fetchJwks() {
    return [{ kid: "test-kid", kty: jwk.kty, n: jwk.n, e: jwk.e }];
  }
}

function signToken(
  payload: Record<string, unknown>,
  opts: { kid?: string; key?: typeof privateKey } = {},
): string {
  const header = { alg: "RS256", kid: opts.kid ?? "test-kid" };
  const h = Buffer.from(JSON.stringify(header)).toString("base64url");
  const p = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signer = createSign("RSA-SHA256");
  signer.update(`${h}.${p}`);
  const sig = signer.sign(opts.key ?? privateKey).toString("base64url");
  return `${h}.${p}.${sig}`;
}

const validPayload = () => ({
  iss: "https://appleid.apple.com",
  aud: AUD,
  exp: Math.floor(Date.now() / 1000) + 600,
  sub: "001234.abcdef",
  email: "Athlete@PrivateRelay.appleid.com",
});

describe("AppleTokenVerifier — vérification JWT RS256 contre le JWKS", () => {
  let verifier: TestVerifier;

  beforeEach(() => {
    process.env.APPLE_BUNDLE_ID = AUD;
    verifier = new TestVerifier();
  });

  afterAll(() => {
    delete process.env.APPLE_BUNDLE_ID;
  });

  it("accepte un token valide et normalise l'email en minuscules", async () => {
    const res = await verifier.verify(signToken(validPayload()));
    expect(res).toEqual({ sub: "001234.abcdef", email: "athlete@privaterelay.appleid.com" });
  });

  it("accepte un token de reconnexion sans email (email: null)", async () => {
    const { email: _omit, ...noEmail } = validPayload();
    void _omit;
    const res = await verifier.verify(signToken(noEmail));
    expect(res.email).toBeNull();
  });

  it("refuse une signature d'une AUTRE clé (401)", async () => {
    await expect(verifier.verify(signToken(validPayload(), { key: otherPriv }))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it("refuse un émetteur qui n'est pas Apple (401)", async () => {
    await expect(verifier.verify(signToken({ ...validPayload(), iss: "https://evil.example" }))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it("refuse une audience différente du bundle id (401)", async () => {
    await expect(verifier.verify(signToken({ ...validPayload(), aud: "autre.app" }))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it("refuse un token expiré (401)", async () => {
    await expect(
      verifier.verify(signToken({ ...validPayload(), exp: Math.floor(Date.now() / 1000) - 10 })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("refuse un kid inconnu du JWKS (401)", async () => {
    await expect(verifier.verify(signToken(validPayload(), { kid: "ghost-kid" }))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it("refuse net si APPLE_BUNDLE_ID n'est pas configuré (401 explicite)", async () => {
    delete process.env.APPLE_BUNDLE_ID;
    await expect(verifier.verify(signToken(validPayload()))).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
