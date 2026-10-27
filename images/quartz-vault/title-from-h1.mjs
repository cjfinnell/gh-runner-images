// Pre-build pass for build.sh: vault notes carry their title as the first
// `# Heading`, not in frontmatter, so Quartz would show the file slug
// (memory-vault) above a duplicate H1. For notes without a frontmatter title,
// move the leading H1 into `title:`. Runs on the per-build clone only.
import fs from "node:fs"
import path from "node:path"

const root = process.argv[2]
const fm = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/

const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    if (e.name.startsWith(".")) return []
    const p = path.join(dir, e.name)
    if (e.isDirectory()) return walk(p)
    return e.name.endsWith(".md") ? [p] : []
  })

for (const file of walk(root)) {
  const text = fs.readFileSync(file, "utf8")
  const m = text.match(fm)
  const head = m ? m[1] : null
  if (head !== null && /^title\s*:/m.test(head)) continue
  const body = m ? text.slice(m[0].length) : text
  const h1 = body.match(/^\s*# (.+?)\s*\r?\n/)
  if (!h1) continue
  const title = `title: ${JSON.stringify(h1[1])}`
  const rest = body.slice(h1[0].length)
  const front = head === null ? title : `${head}\n${title}`
  fs.writeFileSync(file, `---\n${front}\n---\n${rest}`)
}
