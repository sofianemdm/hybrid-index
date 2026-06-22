import { Controller, Get } from "@nestjs/common";
import { OTHER_WORKOUTS } from "./other-workouts.data";

/** Catalogue « Autre » : épreuves réelles (HYROX, WODs de compét, courses) + vrais temps pros. */
@Controller("v1/other-workouts")
export class OtherWorkoutsController {
  @Get()
  list(): unknown[] {
    return OTHER_WORKOUTS;
  }
}
