export interface HTTPEventBody {
  index: string;
  time: string;
  host: string;
  sourcetype: string;
  source: string;
  event: Object;
}

export interface HTTPEventResponse {
  text?: string;
  code: number;
}

const HEC_URL = process.env.SPLUNK_HEC_URL;
const HEC_TOKEN = process.env.SPLUNK_HEC_TOKEN;
const SPLUNK_HOST =
  process.env.WEBSITE_SITE_NAME ?? "test-webhooktosplunk.local";
const SPLUNK_SOURCETYPE = process.env.WEBHOOK_SENDER_SOURCETYPE;
const SPLUNK_SOURCE = process.env.WEBHOOK_SENDER_NAME;

/**
 * Sends a serializable JSON object as an event to Splunk HTTP Event Collector
 * @param {unknown} event - webhook event payload
 * @returns {Promise<Response>} Api response promise
 */
export const sendHttpEvent = (event: unknown): Promise<HTTPEventResponse> => {
  //assert HEC_URL & HEC_TOKEN are set in environment
  if (
    !HEC_URL ||
    !HEC_TOKEN ||
    !SPLUNK_HOST ||
    !SPLUNK_SOURCETYPE ||
    !SPLUNK_SOURCE
  ) {
    return Promise.reject(
      new Error("you must configure local.settings.json, see template"),
    );
  }

  //assert event is JSON
  if (typeof event !== "object") {
    return Promise.reject(new Error("event is not a JSON object!"));
  }

  //build HTTPEventBody
  const body: HTTPEventBody = {
    index: process.env.SPLUNK_INDEX,
    time: Math.floor(Date.now() / 1000).toString(), //current epoch time in seconds
    host: SPLUNK_HOST,
    sourcetype: SPLUNK_SOURCETYPE,
    source: SPLUNK_SOURCE,
    event,
  };

  //build webrequest object
  const webrequest: RequestInit = {
    method: "POST",
    headers: {
      Authorization: `Splunk ${HEC_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  };

  /*
  //fake api request
  console.log("simulated request: ", webrequest);
  return Promise.resolve({
    code: 0,
    text: "simulated request Ok",
  } as HTTPEventResponse);
  */

  //return HEC api request promise
  return fetch(HEC_URL, webrequest)
    .then((res) => res.json())
    .then((res) => res as HTTPEventResponse);
};
