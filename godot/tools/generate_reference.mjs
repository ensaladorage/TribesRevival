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
  const navigation = await moduleAt('minionNavigation');
  const idle = await moduleAt('minionIdle');
  const { chooseEntityCalls } = await moduleAt('minionAwareness');
  const { assignCombatPositions } = await moduleAt('minionCombatPositions');
  const rules = await moduleAt('survivalRules');
  const projection = await moduleAt('stepSimulation'); // Exported pure geometry only.
  const combat = await moduleAt('survivalCombat');
  const seeds = ['', 'totem-tribes-hito-2a', 'migration-parity-42', 'España 🌲 tótem'];
  const allowed = p => p.x >= 2 && p.x <= 158 && p.y >= 2 && p.y <= 158;
  const agent = (id, x, y, vx, vy, fixed = false) => ({id, position:{x,y}, velocity:{x:vx,y:vy}, tickVelocity:{x:0,y:0}, stopAfterSeconds:1, fixed, priority:fixed ? 3 : 1});
  const navCases = [];
  for (let index = 0; index < 16; index++) {
    const input = {agent:agent('b',80,80,3,0), destination:{x:84,y:80}, speed:3, deltaSeconds:0.05,
      neighbors:index === 0 ? [] : [agent('a',80.5+index*0.1,80+(index%3-1)*0.6,-3,0,index%2===0)],
      preferredSide:index%3-1, previousVelocity:{x:3,y:0}};
    navCases.push({input, result:navigation.chooseNavigationStep({...input,isAllowed:allowed}),
      yieldTarget:navigation.idleYieldTarget(input.agent,input.neighbors)});
  }
  const routes = [[],[{id:'worker',position:{x:82,y:80}}],
    [{id:'worker-1',position:{x:82,y:80}},{id:'worker-2',position:{x:83.3,y:80.3}}]]
    .map(obstacles => ({start:{x:80,y:80},goal:{x:85,y:80},obstacles,
      result:navigation.planMinionRoute({x:80,y:80},{x:85,y:80},obstacles,allowed)}));
  const idleCases = seeds.flatMap(seed => [0,1,8].flatMap(step => [
    {center:{x:80,y:80},commandRadius:10,minimumCoordinate:2,maximumCoordinate:158},
    {center:{x:3,y:3},commandRadius:10,minimumCoordinate:2,maximumCoordinate:158}]
    .map(area => { const position={x:area.center.x+4,y:area.center.y};
      const neighbors=[{position:{x:area.center.x+5,y:area.center.y+2}}];
      return {seed,step,id:'unit-a',position,area,neighbors,
        destination:idle.chooseIdleDestination(seed,'unit-a',step,position,area,neighbors),
        wait:idle.idleWaitSeconds(seed,'unit-a',step),entry:idle.totemRangeEntry(position,area)}; })));
  const combatSlots = [1,2,6,8].map(count => {
    const target={x:80,y:80};
    const attackers=Array.from({length:count},(_,index)=>({id:`u${index}`,position:{x:84,y:80+index},range:index%3===0?5:1,ranged:index%3===0,offset:index===1?{x:0.98,y:0}:null}));
    const occupied=[{x:79,y:80}];
    return {target,attackers,occupied,result:Object.fromEntries(assignCombatPositions(target,attackers,occupied,(_,point)=>allowed(point)))};
  });
  const awareness = [true,false].map(available => {
    const units=[{id:'detector',position:{x:80,y:80},available:false,canFight:false,canHunt:false,currentKind:'idle'},
      {id:'responder',position:{x:120,y:80},available,canFight:true,canHunt:true,currentKind:'idle'}];
    const entities=[{id:'enemy',kind:'combat',position:{x:82,y:80},isAlive:true},{id:'rabbit',kind:'hunt',position:{x:81,y:80},isAlive:true}];
    return {units,entities,result:Object.fromEntries(chooseEntityCalls(units,entities,18,18))};
  });
  const reference = {
    description: 'Read-only TypeScript data reference. No gameplay loop executed.',
    random: seeds.map(seed => {
      const random = createSeededRandom(seed);
      return { seed, uints: Array.from({ length: 12 }, () => random.nextUint()) };
    }),
    initialStates: seeds.map(seed => createInitialState(seed)),
    combat: {
      attacks:['explorer','gatherer','lumberjack','hunter','guardian','artisan','mage'].flatMap(role=>[0,5,10].map(level=>({role,level,result:combat.getMinionAttackStats(role,level) ?? null}))),
      damage:['minion','barbarian','animal'].flatMap(source=>['minion','barbarian','animal'].flatMap(target=>[-1,0,1,8].map(amount=>({source,target,amount,result:combat.dealDamage(source,target,{health:4,maxHealth:4},amount)})))),
      heal:[-1,0,1,8].map(amount=>({amount,result:combat.healCombatant({health:2,maxHealth:4},amount)})),
    },
    support: {navigation:navCases,routes,idle:idleCases,combatSlots,awareness,
      projection:[{x:80,y:80},{x:80.001,y:80},{x:-5,y:170},{x:100,y:120}].map(position=>({position,
        clearance:projection.projectOutsideTotemClearance(position,{x:80,y:80},'unit-a'),
        recruitment:projection.projectRecruitmentPosition(position,{x:80,y:80})})),
      gathering:seeds.map(seed=>{
        const state=createInitialState(seed);
        const input={role:'gatherer',unitPosition:{x:80,y:80},totemPosition:state.totem.position,commandRadius:10,cargo:state.units[0].cargo,resources:state.resources,toolLevels:state.toolLevels};
        return {input,result:rules.chooseGatherTask(input)};
      })},
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
