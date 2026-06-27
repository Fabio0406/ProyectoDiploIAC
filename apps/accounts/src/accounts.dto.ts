export class CreateAccountDto {
  owner: string | undefined;
  initialBalance?: number;
}

export class RequestTransferDto {
  originAccountId: string | undefined;
  destinationAccountId: string | undefined;
  amount: number | undefined;
}