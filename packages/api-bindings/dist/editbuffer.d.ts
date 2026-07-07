import { EditBufferChangedNotification } from "@tine/proto/fig";
import { NotificationResponse } from "./notifications.js";
export declare function subscribe(handler: (notification: EditBufferChangedNotification) => NotificationResponse | undefined): Promise<import("./notifications.js").Subscription> | undefined;
