import { Injectable } from '@nestjs/common';
import { Env, validateEnv } from './env.schema';

/** Tipli, salt-okunur yapılandırma erişimi (docs/24 §16). */
@Injectable()
export class EnvService {
  private readonly env: Env;

  constructor() {
    this.env = validateEnv(process.env);
  }

  get<K extends keyof Env>(key: K): Env[K] {
    return this.env[key];
  }

  get isProduction(): boolean {
    return this.env.NODE_ENV === 'production';
  }

  /** DERİA doluluk entegrasyonu açık mı? (panelden 'false' ile kapatılır) */
  get deriaEnabled(): boolean {
    return this.env.DERIA_ENABLED;
  }

  /** Premium detay kilidi zorlanıyor mu? (lansmanda panelden 'true' yapılır) */
  get premiumEnforce(): boolean {
    return this.env.PREMIUM_ENFORCE;
  }

  /**
   * Apple App Store Server API yapılandırması — dördü birden yoksa null
   * (abonelik uçları 503 döner; şema kısmi yapılandırmayı zaten reddeder).
   */
  get appleIap(): {
    issuerId: string;
    keyId: string;
    privateKeyP8: string;
    bundleId: string;
    environment: 'sandbox' | 'production';
  } | null {
    const { APPLE_IAP_ISSUER_ID, APPLE_IAP_KEY_ID, APPLE_IAP_PRIVATE_KEY_P8, APPLE_IAP_BUNDLE_ID } =
      this.env;
    if (
      !APPLE_IAP_ISSUER_ID ||
      !APPLE_IAP_KEY_ID ||
      !APPLE_IAP_PRIVATE_KEY_P8 ||
      !APPLE_IAP_BUNDLE_ID
    ) {
      return null;
    }
    return {
      issuerId: APPLE_IAP_ISSUER_ID,
      keyId: APPLE_IAP_KEY_ID,
      privateKeyP8: APPLE_IAP_PRIVATE_KEY_P8,
      bundleId: APPLE_IAP_BUNDLE_ID,
      environment: this.env.APPLE_IAP_ENVIRONMENT,
    };
  }
}
