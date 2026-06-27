import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors(); // necesario para que el frontend (S3) pueda llamarlo
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));

  const port = process.env.ACCOUNTS_HTTP_PORT ?? 3000;
  await app.listen(port);
  console.log(`accounts corriendo en puerto ${port}`);
}
bootstrap();