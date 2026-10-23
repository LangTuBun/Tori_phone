// Exports the TypeScript-only datasets (transitivity.ts, usage.ts) to JSON for
// the iOS app, so the web files stay the single source of truth.
// Run: node scripts/export-ios-data.mjs   (Node 22.6+ strips the types itself)
import { writeFileSync, mkdirSync } from "node:fs"
import { fileURLToPath, pathToFileURL } from "node:url"
import { dirname, join } from "node:path"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const out = join(root, "ios/Tori/Resources")
mkdirSync(out, { recursive: true })

const transitivity = await import(pathToFileURL(join(root, "src/data/transitivity.ts")))
writeFileSync(join(out, "transitivity.json"), JSON.stringify({
  irregularPatternId: transitivity.IRREGULAR_PATTERN_ID,
  patterns: transitivity.transitivityPatterns,
  pairs: transitivity.verbPairs,
}))

const usage = await import(pathToFileURL(join(root, "src/data/usage.ts")))
writeFileSync(join(out, "usage.json"), JSON.stringify({
  synonymGroups: usage.synonymGroups,
  collocationGroups: usage.collocationGroups,
  auxiliaryVerbs: usage.auxiliaryVerbs,
}))
console.log("exported transitivity.json, usage.json")
