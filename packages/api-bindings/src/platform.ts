import { GetPlatformInfoResponse } from "@tine/proto/fig";
import { sendGetPlatformInfoRequest } from "./requests.js";
import {
  AppBundleType,
  DesktopEnvironment,
  DisplayServerProtocol,
  Os,
} from "@tine/proto/fig";

export { AppBundleType, DesktopEnvironment, DisplayServerProtocol, Os };

export function getPlatformInfo(): Promise<GetPlatformInfoResponse> {
  return sendGetPlatformInfoRequest({});
}
