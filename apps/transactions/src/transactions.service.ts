import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import { Inject } from '@nestjs/common';
import {
  NATS_SERVICE,
  TRANSFER_COMPLETED_EVENT,
  TRANSFER_FAILED_EVENT,
  TransferRequestedEvent,
  TransferCompletedEvent,
  TransferFailedEvent,
} from '@app/contracts';
import { Account } from '../../accounts/src/account.entity';

@Injectable()
export class TransactionsService {
  private readonly logger = new Logger(TransactionsService.name);

  constructor(
    @InjectRepository(Account)
    private readonly repo: Repository<Account>,
    @Inject(NATS_SERVICE)
    private readonly nats: ClientProxy,
    private readonly dataSource: DataSource,
  ) {}

  async handleTransferRequested(event: TransferRequestedEvent): Promise<void> {
    this.logger.log(`Procesando transferencia ${event.transferId} por $${event.amount}`);

    // Usamos una transacción DB para que el débito y crédito sean atómicos
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const origin = await queryRunner.manager.findOneBy(Account, { id: event.originAccountId });
      const destination = await queryRunner.manager.findOneBy(Account, { id: event.destinationAccountId });

      // ── Validación clave: saldo suficiente ───────────────────────────────
      if (!origin || Number(origin.balance) < event.amount) {
        await queryRunner.rollbackTransaction();

        const failedEvent: TransferFailedEvent = {
          transferId: event.transferId,
          originAccountId: event.originAccountId,
          amount: event.amount,
          reason: !origin
            ? 'Cuenta de origen no encontrada'
            : `Saldo insuficiente. Disponible: $${origin.balance}`,
          failedAt: new Date().toISOString(),
        };

        this.nats.emit(TRANSFER_FAILED_EVENT, failedEvent);
        this.logger.warn(`Transferencia ${event.transferId} RECHAZADA: ${failedEvent.reason}`);
        return;
      }

      if (!destination) {
        await queryRunner.rollbackTransaction();
        const failedEvent: TransferFailedEvent = {
          transferId: event.transferId,
          originAccountId: event.originAccountId,
          amount: event.amount,
          reason: 'Cuenta de destino no encontrada',
          failedAt: new Date().toISOString(),
        };
        this.nats.emit(TRANSFER_FAILED_EVENT, failedEvent);
        this.logger.warn(`Transferencia ${event.transferId} RECHAZADA: cuenta destino no existe`);
        return;
      }

      // ── Mover fondos ─────────────────────────────────────────────────────
      origin.balance = Number(origin.balance) - event.amount;
      destination.balance = Number(destination.balance) + event.amount;

      await queryRunner.manager.save(origin);
      await queryRunner.manager.save(destination);
      await queryRunner.commitTransaction();

      const completedEvent: TransferCompletedEvent = {
        transferId: event.transferId,
        originAccountId: event.originAccountId,
        destinationAccountId: event.destinationAccountId,
        amount: event.amount,
        completedAt: new Date().toISOString(),
      };

      this.nats.emit(TRANSFER_COMPLETED_EVENT, completedEvent);
      this.logger.log(`Transferencia ${event.transferId} COMPLETADA ✓`);

    } catch (err) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Error en transferencia ${event.transferId}`, err);

      const failedEvent: TransferFailedEvent = {
        transferId: event.transferId,
        originAccountId: event.originAccountId,
        amount: event.amount,
        reason: 'Error interno al procesar la transferencia',
        failedAt: new Date().toISOString(),
      };
      this.nats.emit(TRANSFER_FAILED_EVENT, failedEvent);
    } finally {
      await queryRunner.release();
    }
  }
}