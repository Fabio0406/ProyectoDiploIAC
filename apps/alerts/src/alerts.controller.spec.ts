import { Test, TestingModule } from '@nestjs/testing';
import { AlertsController } from './alerts.controller';
import { AlertsService } from './alerts.service';
import { TransferCompletedEvent, TransferFailedEvent } from '@app/contracts';

describe('AlertsController', () => {
  let controller: AlertsController;
  let service: AlertsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AlertsController],
      providers: [AlertsService],
    }).compile();

    controller = module.get<AlertsController>(AlertsController);
    service    = module.get<AlertsService>(AlertsService);
  });

  it('debería estar definido', () => {
    expect(controller).toBeDefined();
  });

  it('onTransferCompleted delega al service', () => {
    const spy = jest.spyOn(service, 'handleTransferCompleted').mockImplementation(() => {});
    const event: TransferCompletedEvent = {
      transferId:          'tx-001',
      originAccountId:     'acc-a',
      destinationAccountId:'acc-b',
      amount:              500,
      completedAt:         new Date().toISOString(),
    };
    controller.onTransferCompleted(event);
    expect(spy).toHaveBeenCalledWith(event);
  });

  it('onTransferFailed delega al service', () => {
    const spy = jest.spyOn(service, 'handleTransferFailed').mockImplementation(() => {});
    const event: TransferFailedEvent = {
      transferId:      'tx-002',
      originAccountId: 'acc-a',
      amount:          200,
      reason:          'Saldo insuficiente',
      failedAt:        new Date().toISOString(),
    };
    controller.onTransferFailed(event);
    expect(spy).toHaveBeenCalledWith(event);
  });
});
