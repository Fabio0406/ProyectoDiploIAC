import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { AccountsService } from './accounts.service';
import { CreateAccountDto, RequestTransferDto } from './accounts.dto';

@Controller('accounts')
export class AccountsController {
  constructor(private readonly accountsService: AccountsService) {}

  // ── Health check (lo usa el ALB) ─────────────────────────────────────────
  @Get('health')
  health() {
    return this.accountsService.health();
  }

  // ── CRUD de cuentas ───────────────────────────────────────────────────────
  @Post()
  create(@Body() dto: CreateAccountDto) {
    return this.accountsService.create(dto);
  }

  @Get()
  findAll() {
    return this.accountsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.accountsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: Partial<CreateAccountDto>) {
    return this.accountsService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.accountsService.remove(id);
  }

  // ── Transferencias ────────────────────────────────────────────────────────
  @Post('transfers')
  requestTransfer(@Body() dto: RequestTransferDto) {
    return this.accountsService.requestTransfer(dto);
  }
}