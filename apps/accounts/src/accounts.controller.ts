import { Controller, Get, Post, Put, Delete, Body, Param } from '@nestjs/common';
import { AccountsService } from './accounts.service';
import { CreateAccountDto,UpdateAccountDto,TransferDto } from './account.dto';


@Controller('accounts')
export class AccountsController {
  constructor(private readonly service: AccountsService) {}

  @Get('health')
  health() {
    return { status: 'ok' };
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateAccountDto) {
    return this.service.create(dto);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateAccountDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }

  // ── Inicia una transferencia (publica evento en NATS) ───────────────────
  @Post('transfer')
  transfer(@Body() dto: TransferDto) {
    return this.service.initiateTransfer(dto);
  }
}