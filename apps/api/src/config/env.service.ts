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
}
