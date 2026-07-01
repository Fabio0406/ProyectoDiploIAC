import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Account } from '../../accounts/src/account.entity';
import { TransferRecord } from './transfer-record.entity';
import { TransactionsModule } from './transactions.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),

    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.get<string>('DATABASE_URL'),
        entities: [Account, TransferRecord],
        // synchronize crea transfer_records automáticamente; accounts ya gestiona accounts
        synchronize: true,
        ssl: config.get('NODE_ENV') === 'production'
          ? { rejectUnauthorized: false }
          : false,
        retryAttempts: 10,
        retryDelay: 3000,
      }),
    }),

    TransactionsModule,
  ],
})
export class AppModule {}
