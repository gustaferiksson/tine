import { GetPlatformInfoResponse } from "@tine/proto/fig";
import { AppBundleType, DesktopEnvironment, DisplayServerProtocol, Os } from "@tine/proto/fig";
export { AppBundleType, DesktopEnvironment, DisplayServerProtocol, Os };
export declare function getPlatformInfo(): Promise<GetPlatformInfoResponse>;
