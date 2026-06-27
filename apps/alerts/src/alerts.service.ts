import { Injectable, Logger } from '@nestjs/common';
import { TransferCompletedEvent, TransferFailedEvent } from '@app/contracts';

const HIGH_AMOUNT_THRESHOLD = 1000;

@Injectable()
export class AlertsService {
  private readonly logger = new Logger(AlertsService.name);

  handleTransferCompleted(event: TransferCompletedEvent): void {
    this.logger.log(
      `✓ Transferencia ${event.transferId} completada: ` +
      `$${event.amount} de ${event.originAccountId} → ${event.destinationAccountId}`,
    );

    // Alerta adicional para montos elevados
    if (event.amount >= HIGH_AMOUNT_THRESHOLD) {
      this.logger.warn(
        `⚠ ALERTA MONTO ELEVADO: transferencia ${event.transferId} por $${event.amount}`,
      );
    }
  }

  handleTransferFailed(event: TransferFailedEvent): void {
    this.logger.warn(
      `✗ Transferencia ${event.transferId} FALLIDA: ${event.reason} ` +
      `(cuenta origen: ${event.originAccountId}, monto: $${event.amount})`,
    );
  }
}