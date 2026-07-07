import { SpecLocation } from "@tine/shared/internal";
import { SpecFileImport } from "./loadHelpers.js";
export declare const tryResolveSpecToSubcommand: (spec: SpecFileImport, location: SpecLocation) => Promise<Fig.Subcommand>;
