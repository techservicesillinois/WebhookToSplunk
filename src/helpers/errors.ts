import { HttpResponseInit } from "@azure/functions";

export const HTTPInternalError: HttpResponseInit = {
  status: 500,
  body: "Internal Error",
};

export const HTTPUnauthorizedError: HttpResponseInit = {
  status: 403,
  body: "Invalid webhook URL",
};

export const HTTPBadRequestError: HttpResponseInit = {
  status: 400,
  body: "Invalid webhook payload",
};
