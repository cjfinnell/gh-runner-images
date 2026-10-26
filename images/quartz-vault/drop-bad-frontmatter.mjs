// Pre-build pass for build.sh: deletes notes whose YAML frontmatter does not
// parse, so one malformed note can't fail the whole Quartz build. Runs against
// the fresh per-build clone, never the vault itself. Prints each dropped path
// so the agent that wrote it can be told.
//
// Lives in /usr/src/app so `yaml` resolves from Quartz's node_modules.
import fs from "node:fs"
import path from "node:path"
import YAML from "yaml"

const root = process.argv[2]
const fm = /^---\r?\n([\s\S]*?)\r?\n---(\r?\n|$)/

const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    if (e.name.startsWith(".")) return []
    const p = path.join(dir, e.name)
    if (e.isDirectory()) return walk(p)
    return e.name.endsWith(".md") ? [p] : []
  })

for (const file of walk(root)) {
  const m = fs.readFileSync(file, "utf8").match(fm)
  if (!m) continue
  try {
    YAML.parse(m[1])
  } catch (err) {
    const why = String(err.message).split("\n")[0]
    console.log(`skipping ${path.relative(root, file)}: bad frontmatter: ${why}`)
    fs.rmSync(file)
  }
}
