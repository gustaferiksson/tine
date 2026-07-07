export declare function isValidFrame(frame: {
    width: number;
    height: number;
    anchorX: number;
}): Promise<import("@tine/proto/fig").PositionWindowResponse>;
export declare function setFrame(frame: {
    width: number;
    height: number;
    anchorX: number;
    offsetFromBaseline: number | undefined;
}): Promise<import("@tine/proto/fig").PositionWindowResponse>;
export declare function dragWindow(): Promise<void>;
