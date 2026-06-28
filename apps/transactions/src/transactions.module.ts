import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { NATS_SERVICE, DEFAULT_NATS_URL } from '@app/contracts';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { TransferRecord } from './transfer-record.entity';
import { Account } from '../../accounts/src/account.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Account, TransferRecord]),
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
