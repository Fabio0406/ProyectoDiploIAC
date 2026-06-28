import { Injectable, Logger } from '@nestjs/common';
import { TransferCompletedEvent, TransferFailedEvent } from '@app/contracts';

const HIGH_AMOUNT_THRESHOLD = 10000;

@Injectable()
export class AlertsService {
  private readonly logger = new Logger(AlertsService.name);

  handleTransferCompleted(event: TransferCompletedEvent): void {
    this.logger.log('──────────────────────────────────────────');
    this.logger.log('TRANSFERENCIA COMPLETADA');
    this.logger.log(`  ID:      ${event.transferId}`);
    this.logger.log(`  Desde:   ${event.originAccountId}`);
    this.logger.log(`  Hacia:   ${event.destinationAccountId}`);
    this.logger.log(`  Monto:   $${event.amount}`);
    this.logger.log(`  Fecha:   ${event.completedAt}`);
    this.logger.log('──────────────────────────────────────────');

    if (Number(event.amount) >= HIGH_AMOUNT_THRESHOLD) {
      this.emitHighAmountAlert(event);
    }
  }

  handleTransferFailed(event: TransferFailedEvent): void {
    this.logger.warn('──────────────────────────────────────────');
    this.logger.warn('TRANSFERENCIA RECHAZADA');
    this.logger.warn(`  ID:      ${event.transferId}`);
    this.logger.warn(`  Desde:   ${event.originAccountId}`);
    this.logger.warn(`  Monto:   $${event.amount}`);
    this.logger.warn(`  Motivo:  ${event.reason}`);
    this.logger.warn(`  Fecha:   ${event.failedAt}`);
    this.logger.warn('──────────────────────────────────────────');
  }

  private emitHighAmountAlert(event: TransferCompletedEvent): void {
    this.logger.warn('');
    this.logger.warn('  *** ALERTA: MONTO ELEVADO ***');
    this.logger.warn(`  Transferencia ${event.transferId} por $${event.amount} supera el umbral de $${HIGH_AMOUNT_THRESHOLD}`);
    this.logger.warn(`  Cuenta origen: ${event.originAccountId}`);
    this.logger.warn('');
    // En producción: SES (email) / SNS (push) / tabla de auditoría
    // Para el proyecto, los logs de CloudWatch son suficientes
  }
}
