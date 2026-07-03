import { Controller, Get } from "@nestjs/common";

/**
 * Métadonnées de l'app pour les clients installés — pilotées par variables d'environnement
 * (AUCUN redéploiement mobile nécessaire pour agir sur le parc) :
 *  - APP_MIN_BUILD    : numéro de build MINIMUM supporté. Un client plus vieux affiche un écran
 *                       bloquant « Mets à jour l'app » (changement d'API cassant, faille…).
 *  - APP_STORE_URL    : où envoyer l'utilisateur pour la mise à jour (fiche Play Store).
 * Défauts inoffensifs : minBuild=0 → aucun client n'est jamais bloqué tant qu'on n'a pas
 * explicitement posé la variable. Public et sans auth : consulté AVANT toute session.
 */
@Controller("v1/meta")
export class MetaController {
  @Get("app")
  app(): { minBuild: number; storeUrl: string } {
    return {
      minBuild: Number(process.env.APP_MIN_BUILD ?? 0) || 0,
      storeUrl: process.env.APP_STORE_URL ?? "https://play.google.com/store/apps/details?id=app.hybridindex",
    };
  }
}
