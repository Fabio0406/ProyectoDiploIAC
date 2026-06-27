import { IsString, IsNotEmpty, IsNumber, Min, IsUUID, IsOptional } from 'class-validator';

export class CreateAccountDto {
  @IsString()
  @IsNotEmpty()
  owner!: string;

  @IsNumber()
  @Min(0)
  balance!: number;
}



export class UpdateAccountDto {
  @IsOptional()
  @IsString()
  owner?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  balance?: number;
}

export class TransferDto {
  @IsUUID()
  fromAccountId!: string;

  @IsUUID()
  toAccountId!: string;

  @IsNumber()
  @Min(0.01)
  amount!: number;
}