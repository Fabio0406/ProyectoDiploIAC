import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import { Account } from './account.entity';
import { CreateAccountDto,UpdateAccountDto,TransferDto } from './account.dto';
import { NATS_SERVICE } from '@app/contracts/nats.constants';
import { TRANSFER_REQUESTED, TransferRequestedPayload } from '@app/contracts/banking.contracts';
import { randomUUID } from 'crypto';

@Injectable()
export class AccountsService {
  constructor(
    @InjectRepository(Account)
    private readonly repo: Repository<Account>,
    @Inject(NATS_SERVICE)
    private readonly natsClient: ClientProxy,
  ) {}

  findAll() {
    return this.repo.find();
  }

  async findOne(id: string) {
    const account = await this.repo.findOneBy({ id });
    if (!account) throw new NotFoundException(`Cuenta ${id} no encontrada`);
    return account;
  }

  create(dto: CreateAccountDto) {
    const account = this.repo.create(dto);
    return this.repo.save(account);
  }

  async update(id: string, dto: UpdateAccountDto) {
    await this.findOne(id); // valida que existe
    await this.repo.update(id, dto);
    return this.findOne(id);
  }

  async remove(id: string) {
    const account = await this.findOne(id);
    return this.repo.remove(account);
  }

  async initiateTransfer(dto: TransferDto) {
    // Valida que ambas cuentas existen antes de publicar
    await this.findOne(dto.fromAccountId);
    await this.findOne(dto.toAccountId);

    const payload: TransferRequestedPayload = {
      transferId:    randomUUID(),
      fromAccountId: dto.fromAccountId,
      toAccountId:   dto.toAccountId,
      amount:        dto.amount,
      requestedAt:   new Date().toISOString(),
    };

    // Publica el evento — transactions lo procesará de forma asíncrona
    this.natsClient.emit(TRANSFER_REQUESTED, payload);

    return {
      message:    'Transferencia iniciada',
      transferId: payload.transferId,
      status:     'processing',
    };
  }
}