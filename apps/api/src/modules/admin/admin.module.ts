import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminController } from './presentation/admin.controller';
import { AdminService } from './application/admin.service';
import { ADMIN_REPOSITORY } from './domain/admin.repository';
import { PrismaAdminRepository } from './persistence/prisma-admin.repository';

@Module({
  imports: [AuthModule],
  controllers: [AdminController],
  providers: [AdminService, { provide: ADMIN_REPOSITORY, useClass: PrismaAdminRepository }],
})
export class AdminModule {}
