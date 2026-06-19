import { Module } from "@nestjs/common";
import { MeController } from "./me.controller";
import { ProfileModule } from "../profile/profile.module";

@Module({
  imports: [ProfileModule],
  controllers: [MeController],
})
export class MeModule {}
