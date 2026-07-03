import { Injectable, Logger } from "@nestjs/common";

/**
 * Envoi d'emails transactionnels via Resend (https://resend.com — API HTTP simple, 3000
 * emails/mois gratuits). Configuration par variables d'environnement :
 *  - RESEND_API_KEY : clé API (absente ⇒ MODE DEV : l'email est loggé au lieu d'être envoyé,
 *    aucune erreur — le flux « mot de passe oublié » reste testable en local/e2e) ;
 *  - MAIL_FROM : expéditeur (défaut : domaine de test Resend, à remplacer par un domaine vérifié).
 * Best-effort : un échec d'envoi est loggé, jamais propagé (on ne révèle pas au client si
 * l'email existe, et une panne du fournisseur ne doit pas casser l'API).
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  async send(to: string, subject: string, html: string): Promise<void> {
    const apiKey = process.env.RESEND_API_KEY;
    const from = process.env.MAIL_FROM ?? "Athlete League <onboarding@resend.dev>";
    if (!apiKey) {
      this.logger.log(`[MODE DEV — pas de RESEND_API_KEY] Email non envoyé à ${to} : ${subject}`);
      return;
    }
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to: [to], subject, html }),
      });
      if (!res.ok) {
        this.logger.error(`Envoi email échoué (${res.status}) vers ${to} : ${await res.text()}`);
      }
    } catch (e) {
      this.logger.error(`Envoi email échoué vers ${to} : ${String(e)}`);
    }
  }

  /** Email du code de réinitialisation de mot de passe (6 chiffres, 15 minutes). */
  async sendPasswordResetCode(to: string, code: string): Promise<void> {
    const html = `<div style="font-family:-apple-system,'Segoe UI',Roboto,sans-serif;max-width:480px;margin:0 auto;padding:24px">
      <h2 style="margin:0 0 12px">Réinitialisation du mot de passe</h2>
      <p>Voici ton code de réinitialisation Athlete League :</p>
      <p style="font-size:32px;font-weight:800;letter-spacing:6px;margin:16px 0">${code}</p>
      <p>Il expire dans <strong>15 minutes</strong>. Si tu n'es pas à l'origine de cette demande,
      ignore simplement cet email : ton mot de passe reste inchangé.</p>
    </div>`;
    await this.send(to, "Ton code Athlete League", html);
  }
}
