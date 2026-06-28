// ── Nombres de eventos NATS ───────────────────────────────────────────────

export const TRANSFER_REQUESTED = 'transfer.requested';
export const TRANSFER_COMPLETED = 'transfer.completed';
export const TRANSFER_FAILED    = 'transfer.failed';

// Aliases estilo *_EVENT usados por transactions y alerts
export const TRANSFER_REQUESTED_EVENT = TRANSFER_REQUESTED;
export const TRANSFER_COMPLETED_EVENT = TRANSFER_COMPLETED;
export const TRANSFER_FAILED_EVENT    = TRANSFER_FAILED;

// ── Payload que accounts publica en transfer.requested ────────────────────

export interface TransferRequestedPayload {
  transferId: string;
  fromAccountId: string;
  toAccountId: string;
  amount: number;
  requestedAt: string; // ISO 8601
}

// Alias para que transactions lo consuma con nombre semántico de evento
export type TransferRequestedEvent = TransferRequestedPayload;

// ── Eventos que transactions publica (consumidos por alerts) ──────────────

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

// ── Payload genérico de resultado (compatibilidad con guía) ───────────────

export interface TransferResultPayload {
  transferId: string;
  fromAccountId: string;
  toAccountId: string;
  amount: number;
  status: 'completed' | 'failed';
  reason?: string;
  processedAt: string;
}