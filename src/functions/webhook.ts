import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from "@azure/functions";
import { matchesWebhookUrlSecrets } from "../helpers/secrets";
import {
  HTTPBadRequestError,
  HTTPInternalError,
  HTTPUnauthorizedError,
} from "../helpers/errors";
import {
  HTTPEventResponse,
  sendHttpEvent,
} from "../helpers/httpEventCollector";

/** handle an incoming webhook
 * @param {HttpRequest} request - Incoming HTTP request
 * @param {InvocationContext} context - Azure invocation context metadata
 * @returns {Promise<HttpResponseInit>} Promise of an HTTP response object with a status and body
 */
export const webhook = (
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> => {
  return matchesWebhookUrlSecrets(request)
    .then(
      () => request.json(),
      (e) => {
        //reject early if matchesWebhookUrlSecrets fails
        context.error(e);
        return Promise.reject(HTTPUnauthorizedError);
      },
    )
    .then(
      (bodyJson) => sendHttpEvent(bodyJson),
      (e) => {
        //reject early if body isn't JSON
        context.error(e);
        return Promise.reject(HTTPBadRequestError);
      },
    )
    .then(
      (splunkRes: HTTPEventResponse) => {
        //reject if splunk returns any error code or no code
        if (splunkRes.code !== 0) {
          context.error(
            `bad event payload, cannot be ingested by splunk, code ${splunkRes.code}`,
          );
          return Promise.reject(HTTPBadRequestError);
        }
        //successful event
        context.info(`event successfully sent to splunk`);
        return Promise.resolve({ status: 200, body: "Ok" } as HttpResponseInit);
      },
      (e) => {
        //reject early if fetch request fails
        context.error(e);
        return Promise.reject(HTTPInternalError);
      },
    )
    .catch((errorResponse) => errorResponse as HttpResponseInit);
};

app.http("webhook", {
  methods: ["POST"],
  authLevel: "anonymous",
  handler: webhook,
});
