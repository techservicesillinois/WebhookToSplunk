import { timingSafeEqual } from "crypto";
import { HttpRequest } from "@azure/functions";
import { HTTPInternalError, HTTPUnauthorizedError } from "./errors";

export const matchesWebhookUrlSecrets = (
  request: HttpRequest,
): Promise<void> => {
  const secret = process.env.WEBHOOK_URL_SECRET;

  if (!secret) {
    return Promise.reject(HTTPInternalError);
  }

  const key = request.query.get("key") ?? "";

  // Use timing-safe comparison to prevent timing attacks
  const keyBuf = Buffer.from(key);
  const secretBuf = Buffer.from(secret);
  if (
    keyBuf.length !== secretBuf.length ||
    !timingSafeEqual(keyBuf, secretBuf)
  ) {
    return Promise.reject(HTTPUnauthorizedError);
  }

  return Promise.resolve();
};
