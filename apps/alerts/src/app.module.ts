import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AlertsModule } from './alerts.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    AlertsModule,
  ],
})
export class AppModule {}
