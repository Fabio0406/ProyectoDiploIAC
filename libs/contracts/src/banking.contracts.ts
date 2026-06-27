// ── Eventos que accounts publica en NATS ──────────────────────────────────

export const TRANSFER_REQUESTED = 'transfer.requested';
export const TRANSFER_COMPLETED = 'transfer.completed';
export const TRANSFER_FAILED    = 'transfer.failed';

// ── Payload que accounts envía al publicar transfer.requested ─────────────

export interface TransferRequestedPayload {
  transferId: string;
  fromAccountId: string;
  toAccountId: string;
  amount: number;
  requestedAt: string; // ISO 8601
}

// ── Payload que transactions responde (lo usa alerts, no accounts) ─────────

export interface TransferResultPayload {
  transferId: string;
  fromAccountId: string;
  toAccountId: string;
  amount: number;
  status: 'completed' | 'failed';
  reason?: string;
  processedAt: string;
}