import { createSign } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { EnvService } from '../../../config/env.service';
import { PushMessage, PushSender } from '../domain/notifications.types';

/**
 * FCM HTTP v1 göndericisi — YENİ BAĞIMLILIK YOK (bilinçli karar 2026-10-27):
 * firebase-admin paketi ~40MB çeker ve tek işimiz OAuth jetonu + bir POST.
 * Jeton, servis hesabının özel anahtarıyla imzalı JWT'nin Google'ın jeton
 * ucuna takasıyla alınır (RFC 7523) ve süresi dolana dek önbellekte tutulur.
 *
 * Servis hesabı verilmemişse `configured=false`: tüm gönderimler sessiz
 * geçer — testler ve yerel geliştirme ağ erişimi olmadan koşar.
 */
@Injectable()
export class FcmSender implements PushSender {
  private readonly logger = new Logger(FcmSender.name);
  private readonly sa: { projectId: string; clientEmail: string; privateKey: string } | null;

  private cachedToken: { value: string; expiresAtMs: number } | null = null;

  constructor(env: EnvService) {
    this.sa = env.firebasePush;
  }

  get configured(): boolean {
    return this.sa !== null;
  }

  async send(token: string, message: PushMessage): Promise<'ok' | 'gone' | 'error'> {
    if (!this.sa) return 'error'; // servis çağırmadan önce configured'a bakar
    try {
      const accessToken = await this.accessToken();
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${this.sa.projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${accessToken}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: message.title, body: message.body },
              data: message.data,
              apns: { payload: { aps: { sound: 'default' } } },
            },
          }),
        },
      );
      if (res.ok) return 'ok';
      const text = await res.text();
      // 404/NOT_FOUND ve UNREGISTERED: token ölü (uygulama silinmiş/tazelenmiş)
      // → çağıran veritabanından temizler. Diğer her şey geçici sayılır.
      if (res.status === 404 || text.includes('UNREGISTERED')) return 'gone';
      this.logger.warn(
        { event: 'push_send_failed', status: res.status, body: text.slice(0, 300) },
        'FCM gönderimi başarısız',
      );
      return 'error';
    } catch (err) {
      this.logger.warn({ event: 'push_send_failed', err: String(err) }, 'FCM gönderimi başarısız');
      return 'error';
    }
  }

  /** OAuth erişim jetonu — dolana 60 sn kala tazelenir. */
  private async accessToken(): Promise<string> {
    if (this.cachedToken && Date.now() < this.cachedToken.expiresAtMs - 60_000) {
      return this.cachedToken.value;
    }
    const sa = this.sa!;
    const iat = Math.floor(Date.now() / 1000);
    const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = b64url(
      JSON.stringify({
        iss: sa.clientEmail,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat,
        exp: iat + 3600,
      }),
    );
    const signingInput = `${header}.${claims}`;
    const signature = createSign('RSA-SHA256')
      .update(signingInput)
      .sign(sa.privateKey, 'base64url');
    const assertion = `${signingInput}.${signature}`;

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }).toString(),
    });
    if (!res.ok) {
      throw new Error(
        `OAuth jetonu alınamadı (${res.status}): ${(await res.text()).slice(0, 200)}`,
      );
    }
    const body = (await res.json()) as { access_token: string; expires_in: number };
    this.cachedToken = {
      value: body.access_token,
      expiresAtMs: Date.now() + body.expires_in * 1000,
    };
    return body.access_token;
  }
}

function b64url(s: string): string {
  return Buffer.from(s, 'utf8').toString('base64url');
}
