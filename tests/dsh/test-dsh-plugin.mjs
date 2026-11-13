import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');
const pluginPath = resolve(repoRoot, '.dsh/plugins/coding-harness.js');
const patchPath = resolve(repoRoot, '.dsh/cordis.patch.yml');
const skillsDir = resolve(repoRoot, 'skills');

/** A fake Cordis context that records everything the plugin registers. */
function fakeContext() {
  const registered = [];
  const sections = [];
  const warnings = [];
  return {
    registered,
    sections,
    warnings,
    ctx: {
      logger: { warn: (message) => warnings.push(message) },
      skills: { register: (skill) => registered.push(skill) },
      systemPrompt: { section: (section) => sections.push(section) },
    },
  };
}

/** Import the plugin fresh so no module-level state is shared between tests. */
async function loadPlugin(modulePath = pluginPath) {
  return import(`${pathToFileURL(modulePath).href}?t=${Date.now()}-${Math.random()}`);
}

function skillDirectoryNames() {
  return readdirSync(skillsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

/**
 * Copy the plugin into a scratch tree whose sibling `skills/` holds only the
 * given fixtures, so degraded catalogs can be exercised without touching the
 * real one.
 */
function scratchPlugin(fixtures) {
  const root = mkdtempSync(join(tmpdir(), 'superpowers-dsh-'));
  mkdirSync(join(root, '.dsh/plugins'), { recursive: true });
  cpSync(pluginPath, join(root, '.dsh/plugins/coding-harness.js'));
  for (const [name, contents] of Object.entries(fixtures)) {
    mkdirSync(join(root, 'skills', name), { recursive: true });
    writeFileSync(join(root, 'skills', name, 'SKILL.md'), contents);
  }
  return { root, modulePath: join(root, '.dsh/plugins/coding-harness.js') };
}

test('package.json declares the dsh bundle patch', async () => {
  const pkg = JSON.parse(await readFile(resolve(repoRoot, 'package.json'), 'utf8'));

  assert.equal(pkg.name, 'coding-harness');
  assert.equal(pkg.dsh.bundle.patch, './.dsh/cordis.patch.yml');
  // The dsh entry point must not shadow the OpenCode plugin that `main` names.
  assert.equal(pkg.main, '.opencode/plugins/coding-harness.js');
});

test('the bundle patch inserts one row pointing at the plugin module', async () => {
  const patch = await readFile(patchPath, 'utf8');
  const rows = patch.split('\n').filter((line) => line.trim().startsWith('- id:'));

  assert.deepEqual(rows.map((row) => row.trim()), ['- id: coding-harness']);
  assert.match(patch, /^\s+name: coding-harness\/\.dsh\/plugins\/coding-harness\.js$/m);
  // The specifier is a package-relative deep import, so it has to be a real file.
  await readFile(pluginPath, 'utf8');
});

test('the plugin injects exactly the two registries it writes to', async () => {
  const mod = await loadPlugin();

  assert.equal(mod.name, 'coding-harness');
  assert.deepEqual(mod.inject, ['skills', 'systemPrompt']);
  assert.equal(typeof mod.apply, 'function');
});

test('apply registers every bundled skill once, with its frontmatter', async () => {
  const mod = await loadPlugin();
  const { ctx, registered, warnings } = fakeContext();

  mod.apply(ctx);

  assert.deepEqual(registered.map((skill) => skill.name).sort(), skillDirectoryNames());
  assert.deepEqual(warnings, []);

  const brainstorming = registered.find((skill) => skill.name === 'brainstorming');
  const source = await readFile(join(skillsDir, 'brainstorming/SKILL.md'), 'utf8');
  assert.match(source, new RegExp(`description: "?${brainstorming.description.slice(0, 40)}`));
  assert.equal(brainstorming.source, 'bundled');
  assert.equal(brainstorming.path, join(skillsDir, 'brainstorming/SKILL.md'));
  assert.deepEqual(brainstorming.resourceBase, {
    kind: 'directory',
    path: join(skillsDir, 'brainstorming'),
  });
  // Frontmatter is metadata for the registry, not part of the instruction body.
  assert.ok(!brainstorming.content.startsWith('---'));
});

test('apply registers one bootstrap section carrying using-coding-harness', async () => {
  const mod = await loadPlugin();
  const { ctx, sections } = fakeContext();

  mod.apply(ctx);

  assert.equal(sections.length, 1);
  const [section] = sections;
  assert.equal(section.name, 'coding-harness:bootstrap');
  // After the deployment persona (0), before tool guidance (TOOL_* start at 1000).
  assert.ok(section.order > 0 && section.order < 1000, `order ${section.order} is out of range`);
  assert.match(section.text, /^<EXTREMELY_IMPORTANT>/);
  assert.match(section.text, /<\/EXTREMELY_IMPORTANT>$/);
  assert.match(section.text, /You have superpowers\./);
  assert.match(section.text, /already loaded for this session/);
  assert.match(section.text, /Do not load using-coding-harness again/);

  const body = (await readFile(join(skillsDir, 'using-coding-harness/SKILL.md'), 'utf8'))
    .replace(/^---\n[\s\S]*?\n---\n/, '')
    .trim();
  assert.ok(section.text.includes(body), 'bootstrap must carry the live skill body');

  // The inline dsh tool mapping must travel with the bootstrap.
  assert.match(section.text, /## DeepSeek Harness tool mapping/);
  assert.match(section.text, /NO named subagent types/);
  assert.match(section.text, /`todo_write` \(send the ENTIRE list/);
  assert.match(section.text, /never `superpowers:brainstorming`/);
});

test('the dsh tool-mapping reference exists, is linked, and matches the inline mapping', async () => {
  const referencePath = join(skillsDir, 'using-coding-harness/references/dsh-tools.md');
  const reference = await readFile(referencePath, 'utf8');
  const skill = await readFile(join(skillsDir, 'using-coding-harness/SKILL.md'), 'utf8');

  // The one allowed SKILL.md edit: the pointer line in Platform Adaptation.
  assert.match(skill, /DeepSeek Harness \(dsh\): `references\/dsh-tools\.md`/);

  const mod = await loadPlugin();
  const { ctx, sections } = fakeContext();
  mod.apply(ctx);
  const [section] = sections;

  // The subagent and Windows sandbox deltas are load-bearing: keep both copies in sync.
  for (const delta of [
    'NO named subagent types',
    'TEAM_MEMBER_NOT_FOUND',
    'Delegation depth is 1',
    '--test-isolation=none',
  ]) {
    assert.ok(reference.includes(delta), `reference must carry delta: ${delta}`);
    assert.ok(section.text.includes(delta), `inline mapping must carry delta: ${delta}`);
  }
});

test('a second apply registers the same thing again, with no leaked state', async () => {
  const mod = await loadPlugin();
  const first = fakeContext();
  const second = fakeContext();

  mod.apply(first.ctx);
  mod.apply(second.ctx);

  assert.deepEqual(
    second.registered.map((skill) => skill.name),
    first.registered.map((skill) => skill.name),
  );
  assert.equal(second.sections.length, 1);
  assert.equal(second.sections[0].text, first.sections[0].text);
});

test('a malformed skill is skipped and reported, and the rest still register', async () => {
  const { root, modulePath } = scratchPlugin({
    'using-coding-harness': '---\nname: using-coding-harness\ndescription: bootstrap\n---\nBootstrap body.\n',
    'no-frontmatter': 'Just a body.\n',
    'no-description': '---\nname: no-description\n---\nBody.\n',
    'empty-body': '---\nname: empty-body\ndescription: nothing\n---\n\n',
  });

  try {
    const mod = await loadPlugin(modulePath);
    const { ctx, registered, sections, warnings } = fakeContext();

    mod.apply(ctx);

    assert.deepEqual(registered.map((skill) => skill.name), ['using-coding-harness']);
    assert.equal(sections.length, 1);
    assert.equal(warnings.length, 3, warnings.join('\n'));
    for (const warning of warnings) {
      assert.match(warning, /needs name and description frontmatter and a body/);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('without using-coding-harness the skills still register but no bootstrap does', async () => {
  const { root, modulePath } = scratchPlugin({
    brainstorming: '---\nname: brainstorming\ndescription: design first\n---\nBody.\n',
  });

  try {
    const mod = await loadPlugin(modulePath);
    const { ctx, registered, sections, warnings } = fakeContext();

    mod.apply(ctx);

    assert.deepEqual(registered.map((skill) => skill.name), ['brainstorming']);
    assert.deepEqual(sections, []);
    assert.equal(warnings.length, 1);
    assert.match(warnings[0], /using-coding-harness is missing/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('a missing skills directory degrades to a warning, not a throw', async () => {
  const { root, modulePath } = scratchPlugin({});

  try {
    const mod = await loadPlugin(modulePath);
    const { ctx, registered, sections, warnings } = fakeContext();

    mod.apply(ctx);

    assert.deepEqual(registered, []);
    assert.deepEqual(sections, []);
    assert.equal(warnings.length, 2);
    assert.match(warnings[0], /cannot read/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('the Codex plugin sync excludes the dsh dotdir', async () => {
  const sync = await readFile(resolve(repoRoot, 'scripts/sync-to-codex-plugin.sh'), 'utf8');

  assert.match(sync, /^\s+"\/\.dsh\/"$/m);
});
