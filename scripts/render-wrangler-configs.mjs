#!/usr/bin/env node
// Renders Terraform's deploy manifest into the files `wrangler deploy` reads.
//
//   node scripts/render-wrangler-configs.mjs <manifest.json> <out-dir> \
//     [--control-plane-migration-tag <tag>]
//
// <manifest.json> is `terraform output -json deploy_manifest`. For each Worker
// it writes <out-dir>/<package>/wrangler.json and secrets.json (for
// `--secrets-file`). When the manifest describes a Cloudflare web app it also
// writes <out-dir>/web/wrangler.json, secrets.json and build.env (the
// NEXT_PUBLIC_* values the OpenNext build inlines).
//
// Paths in the manifest are relative to the repository; they are resolved
// against the current directory, which must be the checkout being deployed.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Durable Object classes the control plane has created or deleted, oldest
// first. Wrangler reads the Worker's live migration tag and applies only the
// steps after it, so the list must contain that tag and nothing that is
// invalid after it. Deployments sit on different tags: one that never had
// SchedulerDO is on v1; one that had it is on v2 (still has it) or v3 (deleted).
// This replaces the Terraform workflow's "Stage SchedulerDO deletion migration"
// step, reading the tag from Cloudflare instead of Terraform state.
const CONTROL_PLANE_MIGRATIONS = [
  { tag: "v1", new_sqlite_classes: ["SessionDO"] },
  { tag: "v2", new_sqlite_classes: ["SchedulerDO"] },
  { tag: "v3", deleted_classes: ["SchedulerDO"] },
];

export function controlPlaneMigrations(currentTag) {
  if (!currentTag || currentTag === "v1") return CONTROL_PLANE_MIGRATIONS.slice(0, 1);
  if (currentTag === "v2" || currentTag === "v3") return CONTROL_PLANE_MIGRATIONS;
  throw new Error(
    `Unknown control-plane migration tag "${currentTag}". Add its step to CONTROL_PLANE_MIGRATIONS before deploying.`
  );
}

// Single-quoted for `set -a; . build.env`, so values with spaces survive.
function shellQuote(value) {
  return `'${String(value).replaceAll("'", `'"'"'`)}'`;
}

function writeJson(file, value) {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

export function render(
  manifest,
  outDir,
  { controlPlaneMigrationTag = "", repoRoot = process.cwd() } = {}
) {
  if (manifest?.version !== 1) {
    throw new Error(`Unsupported deploy manifest version: ${manifest?.version}`);
  }

  const written = [];
  for (const [pkg, worker] of Object.entries(manifest.workers)) {
    const config = JSON.parse(worker.config_json);
    config.main = path.resolve(repoRoot, config.main);
    if (pkg === "control-plane") {
      config.migrations = controlPlaneMigrations(controlPlaneMigrationTag);
    }
    writeJson(path.join(outDir, pkg, "wrangler.json"), config);
    writeJson(path.join(outDir, pkg, "secrets.json"), worker.secrets ?? {});
    written.push(pkg);
  }

  if (manifest.web) {
    const webRoot = path.resolve(repoRoot, "packages/web");
    const config = JSON.parse(manifest.web.config_json);
    config.main = path.resolve(webRoot, config.main);
    config.assets = { ...config.assets, directory: path.resolve(webRoot, config.assets.directory) };
    writeJson(path.join(outDir, "web", "wrangler.json"), config);
    writeJson(path.join(outDir, "web", "secrets.json"), manifest.web.secrets ?? {});
    const env = Object.entries(manifest.web.build_env)
      .map(([name, value]) => `${name}=${shellQuote(value)}`)
      .join("\n");
    writeFileSync(path.join(outDir, "web", "build.env"), `${env}\n`, { mode: 0o600 });
    written.push("web");
  }

  return written;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [manifestPath, outDir, ...rest] = process.argv.slice(2);
  if (!manifestPath || !outDir) {
    console.error(
      "Usage: render-wrangler-configs.mjs <manifest.json> <out-dir> [--control-plane-migration-tag <tag>]"
    );
    process.exit(2);
  }
  const tagFlag = rest.indexOf("--control-plane-migration-tag");
  const controlPlaneMigrationTag = tagFlag === -1 ? "" : (rest[tagFlag + 1] ?? "");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const written = render(manifest, outDir, { controlPlaneMigrationTag });
  console.log(`Rendered Wrangler configs for: ${written.join(", ")}`);
}
