import { Controller, Logger } from '@nestjs/common';
import { EventPattern, Payload } from '@nestjs/microservices';
import { TRANSFER_REQUESTED_EVENT, TransferRequestedEvent } from '@app/contracts';
import { TransactionsService } from './transactions.service';

@Controller()
export class TransactionsController {
  private readonly logger = new Logger(TransactionsController.name);

  constructor(private readonly transactionsService: TransactionsService) {}

  @EventPattern(TRANSFER_REQUESTED_EVENT)
  onTransferRequested(@Payload() event: TransferRequestedEvent): void {
    this.logger.log(`Evento recibido: ${TRANSFER_REQUESTED_EVENT} → ${event.transferId}`);
    this.transactionsService.handleTransferRequested(event);
  }
}