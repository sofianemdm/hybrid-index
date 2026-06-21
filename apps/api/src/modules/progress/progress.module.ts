import { Global, Module } from "@nestjs/common";
import { ProgressService } from "./progress.service";
import { ProgressController } from "./progress.controller";

/** @Global : ProgressService est injecté par results/wods pour attribuer les EP au log. */
@Global()
@Module({
  controllers: [ProgressController],
  providers: [ProgressService],
  exports: [ProgressService],
})
export class ProgressModule {}
