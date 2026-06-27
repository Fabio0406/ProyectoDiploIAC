export const TRANSFER_REQUESTED_EVENT  = 'transfer.requested';
export const TRANSFER_COMPLETED_EVENT  = 'transfer.completed';
export const TRANSFER_FAILED_EVENT     = 'transfer.failed';

export interface TransferRequestedEvent {
  transferId: string;
  originAccountId: string;
  destinationAccountId: string;
  amount: number;
  requestedAt: string;
}

export interface TransferCompletedEvent {
  transferId: string;
  originAccountId: string;
  destinationAccountId: string;
  amount: number;
  completedAt: string;
}

export interface TransferFailedEvent {
  transferId: string;
  originAccountId: string;
  amount: number;
  reason: string;
  failedAt: string;
}