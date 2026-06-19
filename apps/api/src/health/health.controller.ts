import { Controller, Get } from "@nestjs/common";

@Controller("health")
export class HealthController {
  @Get()
  health(): { service: string; status: "ok" } {
    return { service: "api", status: "ok" };
  }
}
