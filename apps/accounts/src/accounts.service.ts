import { BadRequestException, Inject, Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import { randomUUID } from 'node:crypto';
import {
  NATS_SERVICE,
  TRANSFER_REQUESTED_EVENT,
  TransferRequestedEvent,
} from '@app/contracts';
import { Account } from './account.entity';
import { CreateAccountDto, RequestTransferDto } from './accounts.dto';

@Injectable()
export class AccountsService implements OnModuleInit {
  private readonly logger = new Logger(AccountsService.name);

  constructor(
    @InjectRepository(Account)
    private readonly repo: Repository<Account>,
    @Inject(NATS_SERVICE)
    private readonly nats: ClientProxy,
  ) {}

  async onModuleInit() {
    await this.nats.connect();
    this.logger.log('Conectado al broker NATS');
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  async create(dto: CreateAccountDto): Promise<Account> {
    const account = this.repo.create({
      owner: dto.owner,
      balance: dto.initialBalance ?? 0,
    });
    const saved = await this.repo.save(account);
    this.logger.log(`Cuenta creada: ${saved.id} (${saved.owner})`);
    return saved;
  }

  async findAll(): Promise<Account[]> {
    return this.repo.find({ order: { createdAt: 'DESC' } });
  }

  async findOne(id: string): Promise<Account> {
    const account = await this.repo.findOneBy({ id });
    if (!account) throw new NotFoundException(`Cuenta ${id} no encontrada`);
    return account;
  }

  async update(id: string, dto: Partial<CreateAccountDto>): Promise<Account> {
    const account = await this.findOne(id);
    if (dto.owner) account.owner = dto.owner;
    return this.repo.save(account);
  }

  async remove(id: string): Promise<void> {
    const account = await this.findOne(id);
    await this.repo.remove(account);
    this.logger.log(`Cuenta eliminada: ${id}`);
  }

  // ── Transferencias ────────────────────────────────────────────────────────

  async requestTransfer(dto: RequestTransferDto): Promise<{ transferId: string; message: string }> {
  const { originAccountId, destinationAccountId, amount } = dto;

  if (!originAccountId || !destinationAccountId) {
    throw new BadRequestException('originAccountId and destinationAccountId are required');
  }

  await this.findOne(originAccountId);
  await this.findOne(destinationAccountId);

  const event: TransferRequestedEvent = {
    transferId: randomUUID(),
    originAccountId,
    destinationAccountId,
    amount: amount ?? 0,
    requestedAt: new Date().toISOString(),
  };

  this.nats.emit<void, TransferRequestedEvent>(TRANSFER_REQUESTED_EVENT, event);
  this.logger.log(`Publicado ${TRANSFER_REQUESTED_EVENT} → transferId: ${event.transferId}`);
  
    return {
      transferId: event.transferId,
      message: 'Transferencia en proceso. Recibirá una notificación con el resultado.',
    };
  }

  // ── Health ────────────────────────────────────────────────────────────────
  health(): { status: string } {
    return { status: 'ok' };
  }
}