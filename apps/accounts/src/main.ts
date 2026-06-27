import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { AccountsModule } from './accounts.module';

async function bootstrap() {
  const app = await NestFactory.create(AccountsModule);

  
  app.enableCors();

  const port = Number(process.env.ACCOUNTS_HTTP_PORT ?? 3000);
  await app.listen(port);
  Logger.log(`accounts HTTP escuchando en http://localhost:${port}`, 'Bootstrap');
}

bootstrap();