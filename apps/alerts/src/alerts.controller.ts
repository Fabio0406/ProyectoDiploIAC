import { Controller, Logger } from '@nestjs/common';
import { EventPattern, Payload } from '@nestjs/microservices';
import {
  TRANSFER_COMPLETED_EVENT,
  TRANSFER_FAILED_EVENT,
  TransferCompletedEvent,
  TransferFailedEvent,
} from '@app/contracts';
import { AlertsService } from './alerts.service';

@Controller()
export class AlertsController {
  private readonly logger = new Logger(AlertsController.name);

  constructor(private readonly alertsService: AlertsService) {}

  @EventPattern(TRANSFER_COMPLETED_EVENT)
  onTransferCompleted(@Payload() event: TransferCompletedEvent): void {
    this.logger.log(`Evento recibido: ${TRANSFER_COMPLETED_EVENT} → ${event.transferId}`);
    this.alertsService.handleTransferCompleted(event);
  }

  @EventPattern(TRANSFER_FAILED_EVENT)
  onTransferFailed(@Payload() event: TransferFailedEvent): void {
    this.logger.log(`Evento recibido: ${TRANSFER_FAILED_EVENT} → ${event.transferId}`);
    this.alertsService.handleTransferFailed(event);
  }
}