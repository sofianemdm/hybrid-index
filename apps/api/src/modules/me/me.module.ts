import { Module } from "@nestjs/common";
import { MeController } from "./me.controller";
import { MeService } from "./me.service";
import { ProfileModule } from "../profile/profile.module";

@Module({
  imports: [ProfileModule],
  controllers: [MeController],
  providers: [MeService],
})
export class MeModule {}
