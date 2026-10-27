import { Global, Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsService } from './application/notifications.service';
import { NOTIFICATIONS_REPOSITORY, PUSH_SENDER } from './domain/notifications.types';
import { FcmSender } from './infrastructure/fcm.sender';
import { PrismaNotificationsRepository } from './persistence/prisma-notifications.repository';
import { NotificationsController } from './presentation/notifications.controller';

/**
 * Push bildirimleri modülü (kurucu onayı 2026-10-27).
 *
 * @Global BİLİNÇLİ: tetikleyiciler dört ayrı modülün servislerinden (qa,
 * community, events, routes) ateşlenir; her birine import eklemek yerine
 * NotificationsService her yerden @Optional() enjekte edilir — birim testleri
 * servisi vermeden kurulur, bildirim yolu o zaman sessizce atlanır.
 */
@Global()
@Module({
  imports: [AuthModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    { provide: NOTIFICATIONS_REPOSITORY, useClass: PrismaNotificationsRepository },
    { provide: PUSH_SENDER, useClass: FcmSender },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
