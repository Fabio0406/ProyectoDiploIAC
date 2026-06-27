import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { NATS_SERVICE, DEFAULT_NATS_URL } from '@app/contracts';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { Account } from '../../accounts/src/account.entity';

@Module({
  imports: [
    // Misma DB que accounts — transactions lee y actualiza saldos
    TypeOrmModule.forRootAsync({
      useFactory: () => ({
        type: 'postgres',
        url: process.env.DATABASE_URL,
        entities: [Account],
        synchronize: false,  // accounts ya crea la tabla, transactions solo la usa
        ssl: { rejectUnauthorized: false },
      }),
    }),
    TypeOrmModule.forFeature([Account]),
    // Cliente NATS para emitir transfer.completed / transfer.failed
    ClientsModule.register([
      {
        name: NATS_SERVICE,
        transport: Transport.NATS,
        options: {
          servers: [process.env.NATS_URL ?? DEFAULT_NATS_URL],
        },
      },
    ]),
  ],
  controllers: [TransactionsController],
  providers: [TransactionsService],
})
export class TransactionsModule {}