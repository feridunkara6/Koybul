import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import * as Sentry from '@sentry/node';
import { Request, Response } from 'express';
import { ZodError } from 'zod';
import { currentRequestId } from '../context/request-context';
import { AppProblem, PROBLEM_BASE, ProblemBody } from './problem';

const PROBLEM_CONTENT_TYPE = 'application/problem+json';

/**
 * Tek çıkış kapısı (docs/24 §14): her istisna RFC 9457 Problem'a dönüşür.
 * Beklenmeyen hatalar 500 `internal` olarak maskelenir; detay yalnız loga gider.
 */
@Catch()
export class GlobalProblemFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalProblemFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const requestId = currentRequestId();
    const instance = req.originalUrl?.split('?')[0];

    if (exception instanceof AppProblem && exception.headers) {
      for (const [name, value] of Object.entries(exception.headers)) {
        res.setHeader(name, value);
      }
    }
    const body = this.toProblem(exception, instance, requestId);
    if (body.status >= 500) {
      const err = exception instanceof Error ? exception.stack : String(exception);
      // `event: 'server_error'` sabit etiketi log-tabanlı alarm içindir (Faz A.6 ara çözüm):
      // Sentry SDK bağlanana dek hosting log alarmı bu satırı yakalar
      // (docs/implementation/monitoring-kurulum-rehberi.md).
      this.logger.error(
        { event: 'server_error', status: body.status, requestId, instance, err },
        'Sunucu hatası',
      );
      // Sentry (FAZ 0 K5, 2026-09): DSN tanımlıysa beklenmeyen 5xx Sentry'ye de
      // gider — log etiketi `server_error` yerinde kalır, iki kanal birlikte
      // çalışır. DSN yoksa bu satır tamamen sessizdir.
      if (process.env.SENTRY_DSN) {
        Sentry.captureException(
          exception instanceof Error ? exception : new Error(String(exception)),
        );
      }
    }
    res.status(body.status).type(PROBLEM_CONTENT_TYPE).json(body);
  }

  private toProblem(exception: unknown, instance?: string, requestId?: string): ProblemBody {
    if (exception instanceof AppProblem) {
      return exception.toBody(instance, requestId);
    }
    if (exception instanceof ZodError) {
      return new AppProblem(
        'validation-error',
        'İstek gövdesi doğrulanamadı.',
        exception.issues.map((i) => ({
          field: i.path.join('.') || '(root)',
          code: i.code,
          message: i.message,
        })),
      ).toBody(instance, requestId);
    }
    if (exception instanceof HttpException) {
      // Framework istisnaları (404, 503-readiness vb.) kendi status'larıyla,
      // kataloglu değilse jenerik "about:blank" type'ıyla Problem'a çevrilir (RFC 9457 §4).
      const status = exception.getStatus();
      const type = status === HttpStatus.NOT_FOUND ? `${PROBLEM_BASE}not-found` : 'about:blank';
      return {
        type,
        title: exception.message,
        status,
        ...(instance ? { instance } : {}),
        ...(requestId ? { requestId } : {}),
      };
    }
    return new AppProblem('internal').toBody(instance, requestId);
  }
}
