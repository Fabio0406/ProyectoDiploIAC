// app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { AccountsModule } from './accounts.module';
import { Account } from './account.entity';
import { NATS_SERVICE } from '@app/contracts/nats.constants';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),

    // ← forRootAsync garantiza que ConfigModule ya cargó el .env
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.get<string>('DATABASE_URL'),
        entities: [Account],
        synchronize: true,
      }),
    }),

    ClientsModule.register([
      {
        name: NATS_SERVICE,
        transport: Transport.NATS,
        options: {
          servers: [process.env.NATS_URL ?? 'nats://localhost:4222'],
        },
      },
    ]),

    AccountsModule,
  ],
})
export class AppModule {}