import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { controlPlaneMigrations, render } from "./render-wrangler-configs.mjs";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifestPath = path.join(repoRoot, "scripts/fixtures/deploy-manifest.example.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

function renderToTemp(options = {}) {
  const outDir = mkdtempSync(path.join(tmpdir(), "wrangler-configs-"));
  render(manifest, outDir, { repoRoot, ...options });
  const read = (...parts) => readFileSync(path.join(outDir, ...parts), "utf8");
  return { outDir, read, json: (...parts) => JSON.parse(read(...parts)) };
}

test("each Worker gets a config pointing at its bundle in this checkout", () => {
  const { json } = renderToTemp();
  assert.equal(
    json("control-plane", "wrangler.json").main,
    path.join(repoRoot, "packages/control-plane/dist/index.js")
  );
  assert.equal(
    json("slack-bot", "wrangler.json").main,
    path.join(repoRoot, "packages/slack-bot/dist/index.js")
  );
  assert.equal(json("control-plane", "wrangler.json").no_bundle, true);
});

test("secrets go to secrets.json and never into the config", () => {
  const { read, json } = renderToTemp();
  assert.deepEqual(json("slack-bot", "secrets.json"), manifest.workers["slack-bot"].secrets);
  assert.ok(!read("control-plane", "wrangler.json").includes("example-not-a-secret"));
});

test("a disabled bot is absent from the manifest and gets no config", () => {
  const workers = { ...manifest.workers };
  delete workers["linear-bot"];
  const outDir = mkdtempSync(path.join(tmpdir(), "wrangler-configs-"));
  render({ ...manifest, workers }, outDir, { repoRoot });
  assert.equal(existsSync(path.join(outDir, "linear-bot")), false);
  assert.equal(existsSync(path.join(outDir, "slack-bot", "wrangler.json")), true);
});

test("a fresh or v1 control plane gets only the SessionDO step", () => {
  assert.deepEqual(controlPlaneMigrations(""), [{ tag: "v1", new_sqlite_classes: ["SessionDO"] }]);
  assert.deepEqual(controlPlaneMigrations("v1"), controlPlaneMigrations(""));
  const { json } = renderToTemp();
  assert.deepEqual(json("control-plane", "wrangler.json").migrations, controlPlaneMigrations(""));
});

test("a control plane that had SchedulerDO keeps the history that deletes it", () => {
  const steps = controlPlaneMigrations("v2");
  assert.deepEqual(
    steps.map((step) => step.tag),
    ["v1", "v2", "v3"]
  );
  assert.deepEqual(steps.at(-1), { tag: "v3", deleted_classes: ["SchedulerDO"] });
  assert.deepEqual(controlPlaneMigrations("v3"), steps);
});

test("an unknown migration tag stops the deploy", () => {
  assert.throws(() => controlPlaneMigrations("v9"), /Unknown control-plane migration tag "v9"/);
});

test("only the control plane carries Durable Object migrations", () => {
  const { json } = renderToTemp({ controlPlaneMigrationTag: "v3" });
  assert.equal(json("control-plane", "wrangler.json").migrations.length, 3);
  assert.equal(json("slack-bot", "wrangler.json").migrations, undefined);
});

test("the web config resolves OpenNext paths and the build env survives spaces", () => {
  const { read, json } = renderToTemp();
  const web = json("web", "wrangler.json");
  assert.equal(web.main, path.join(repoRoot, "packages/web/.open-next/worker.js"));
  assert.equal(web.assets.directory, path.join(repoRoot, "packages/web/.open-next/assets"));

  const env = execFileSync(
    "bash",
    [
      "-c",
      'set -a; . "$1"; printf "%s" "$NEXT_PUBLIC_APP_NAME"',
      "_",
      path.join(renderToTemp().outDir, "web", "build.env"),
    ],
    {
      encoding: "utf8",
    }
  );
  assert.equal(env, "Open Inspect (example)");
  assert.match(read("web", "build.env"), /^NEXT_PUBLIC_WS_URL='wss:\/\//m);
});

test("an unsupported manifest version is rejected", () => {
  const outDir = mkdtempSync(path.join(tmpdir(), "wrangler-configs-"));
  assert.throws(
    () => render({ ...manifest, version: 2 }, outDir, { repoRoot }),
    /Unsupported deploy manifest version: 2/
  );
});
