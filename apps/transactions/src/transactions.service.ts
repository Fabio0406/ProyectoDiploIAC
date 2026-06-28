import { Injectable, Logger, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import {
  NATS_SERVICE,
  TRANSFER_COMPLETED_EVENT,
  TRANSFER_FAILED_EVENT,
  TransferRequestedEvent,
  TransferCompletedEvent,
  TransferFailedEvent,
} from '@app/contracts';
import { Account } from '../../accounts/src/account.entity';
import { TransferRecord } from './transfer-record.entity';

@Injectable()
export class TransactionsService {
  private readonly logger = new Logger(TransactionsService.name);

  constructor(
    @InjectRepository(Account)
    private readonly accountRepo: Repository<Account>,
    @InjectRepository(TransferRecord)
    private readonly recordRepo: Repository<TransferRecord>,
    @Inject(NATS_SERVICE)
    private readonly nats: ClientProxy,
    private readonly dataSource: DataSource,
  ) {}

  async handleTransferRequested(event: TransferRequestedEvent): Promise<void> {
    const { transferId, fromAccountId, toAccountId, amount } = event;
    this.logger.log(`Procesando transferencia ${transferId} — monto: $${amount}`);

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Leer cuenta origen con bloqueo pesimista para evitar race conditions
      const origin = await queryRunner.manager
        .getRepository(Account)
        .createQueryBuilder('account')
        .setLock('pessimistic_write')
        .where('account.id = :id', { id: fromAccountId })
        .getOne();

      // ── VALIDACIÓN CLAVE: rechazar si saldo insuficiente ─────────────────
      if (!origin) {
        throw new Error(`Cuenta de origen ${fromAccountId} no encontrada`);
      }
      if (Number(origin.balance) < amount) {
        throw new Error(
          `Saldo insuficiente. Disponible: $${origin.balance}, requerido: $${amount}`,
        );
      }

      const destination = await queryRunner.manager
        .getRepository(Account)
        .findOneBy({ id: toAccountId });

      if (!destination) {
        throw new Error(`Cuenta de destino ${toAccountId} no encontrada`);
      }

      // ── Mover fondos de forma atómica ────────────────────────────────────
      await queryRunner.manager
        .getRepository(Account)
        .update(fromAccountId, { balance: Number(origin.balance) - amount });

      await queryRunner.manager
        .getRepository(Account)
        .update(toAccountId, { balance: Number(destination.balance) + amount });

      // Registrar el movimiento exitoso
      await queryRunner.manager.getRepository(TransferRecord).save(
        queryRunner.manager.getRepository(TransferRecord).create({
          transferId,
          fromAccountId,
          toAccountId,
          amount,
          status: 'completed',
        }),
      );

      await queryRunner.commitTransaction();

      const completedEvent: TransferCompletedEvent = {
        transferId,
        originAccountId: fromAccountId,
        destinationAccountId: toAccountId,
        amount,
        completedAt: new Date().toISOString(),
      };
      this.nats.emit(TRANSFER_COMPLETED_EVENT, completedEvent);
      this.logger.log(`Transferencia ${transferId} COMPLETADA ✓`);

    } catch (err: unknown) {
      await queryRunner.rollbackTransaction();

      const reason = err instanceof Error ? err.message : 'Error interno';

      // Registrar el intento fallido (fuera de la transacción revertida)
      await this.recordRepo.save(
        this.recordRepo.create({
          transferId,
          fromAccountId,
          toAccountId,
          amount,
          status: 'failed',
          failReason: reason,
        }),
      );

      const failedEvent: TransferFailedEvent = {
        transferId,
        originAccountId: fromAccountId,
        amount,
        reason,
        failedAt: new Date().toISOString(),
      };
      this.nats.emit(TRANSFER_FAILED_EVENT, failedEvent);
      this.logger.warn(`Transferencia ${transferId} RECHAZADA: ${reason}`);

    } finally {
      await queryRunner.release();
    }
  }
}
