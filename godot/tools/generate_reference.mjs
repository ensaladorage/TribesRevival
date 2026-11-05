// Generate cross-language data references only; never run stepSimulation.
// Uses the existing TypeScript dependency; original sources are read-only.
import { readFile, writeFile, readdir, mkdtemp, rm, mkdir } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import os from 'node:os';
import ts from 'typescript';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.dirname(project);
const temporary = await mkdtemp(path.join(os.tmpdir(), 'tribes-godot-reference-'));
try {
  for (const directory of ['simulation', 'input']) {
    await mkdir(path.join(temporary, directory));
    for (const name of await readdir(path.join(root, 'src', directory))) {
      if (!name.endsWith('.ts') || name.endsWith('.test.ts')) continue;
      const source = await readFile(path.join(root, 'src', directory, name), 'utf8');
      const output = ts.transpileModule(source, {
        compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext },
      }).outputText.replace(/from (['"])(\.[^'"]+)\1/g, (_, quote, target) => `from ${quote}${target}.mjs${quote}`);
      await writeFile(path.join(temporary, directory, name.replace(/\.ts$/, '.mjs')), output);
    }
  }
  const moduleAt = (name) => import(pathToFileURL(path.join(temporary, 'simulation', name + '.mjs')).href);
  const { createSeededRandom } = await moduleAt('seededRandom');
  const { createInitialState } = await moduleAt('createInitialState');
  const economy = await moduleAt('economyConfig');
  const { TECHNOLOGIES } = await moduleAt('technologyConfig');
  const { PROGRESSION_BALANCE } = await moduleAt('progression');
  const seeds = ['', 'totem-tribes-hito-2a', 'migration-parity-42', 'España 🌲 tótem'];
  const reference = {
    description: 'Read-only TypeScript data reference. No gameplay loop executed.',
    random: seeds.map(seed => {
      const random = createSeededRandom(seed);
      return { seed, uints: Array.from({ length: 12 }, () => random.nextUint()) };
    }),
    initialStates: seeds.map(seed => createInitialState(seed)),
    economy: {
      recruitment: Array.from({ length: 10 }, (_, population) => economy.getGathererRecruitmentCost(population)),
      specializations: Object.fromEntries(['axe', 'bow', 'hammer', 'sword', 'mage'].map(item => [item, {
        limit: economy.getSpecializationLimit(item),
        costs: Array.from({ length: 7 }, (_, count) => economy.getSpecializationCost(item, count)),
      }])),
      shields: Array.from({ length: 7 }, (_, count) => economy.getShieldCost(count)),
      upgrades: economy.TOOL_UPGRADES,
      technologies: TECHNOLOGIES,
      progression: PROGRESSION_BALANCE,
      bonuses: seeds.flatMap(seed => ['axe', 'hammer'].flatMap(tool => [0, 2, 6, 10].flatMap(level => [0, 1, 42, 200].map(tick => {
        const input = {seed, tick, unitId: 'unit-gatherer-01', nodeId: 'resource-001', tool, level};
        return {...input, result: economy.rollsToolBonusResource(input)};
      })))),
    },
  };
  await mkdir(path.join(project, 'tests', 'fixtures'), { recursive: true });
  await writeFile(path.join(project, 'tests', 'fixtures', 'typescript_reference.json'), JSON.stringify(reference) + '\n');
  console.log(`Generated reference: ${seeds.length} seeds and complete initial states, economy tables; no gameplay ticks`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
