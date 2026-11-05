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
      // Expose this private pure helper only in the disposable reference copy.
      const extra = name === 'stepSimulation.ts' ? '\nexport { resourceApproachPosition };\n' : '';
      await writeFile(path.join(temporary, directory, name.replace(/\.ts$/, '.mjs')), output + extra);
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
  const edgeObstacles = createInitialState().barbarians.map(({id,position}) => ({id,position}));
  for (const [start,goal] of [[{x:80,y:80},{x:84,y:80}],
    [{x:84.2,y:80},{x:84.5,y:80}], [{x:83.8,y:80},{x:84.5,y:80}],
    [{x:80,y:80},{x:84.96,y:80}], [{x:80,y:80},{x:85.2,y:80}]]) {
    const obstacles=[...edgeObstacles,{id:'worker',position:{x:84,y:80}}];
    routes.push({start,goal,obstacles,result:navigation.planMinionRoute(start,goal,obstacles,allowed)});
  }
  const segmentRandom=createSeededRandom('migration-segments');
  const segments=Array.from({length:256},(_,index)=>{
    const point=()=>({x:segmentRandom.nextFloat(2,158),y:segmentRandom.nextFloat(2,158)});
    const start=point(),end=index%8===0?start:point();
    const obstacles=Array.from({length:index%8},(_,i)=>({id:`obstacle-${i}`,position:point()}));
    return {start,end,obstacles,result:navigation.segmentIsClear(start,end,obstacles)};
  });
  for (const goal of [{x:-2,y:80},{x:2-1e-5,y:80},{x:2,y:80},
    {x:158,y:80},{x:158+1e-5,y:80},{x:162,y:80},
    {x:80,y:-2},{x:80,y:162},{x:162,y:162}]) {
    routes.push({start:{x:80,y:80},goal,obstacles:edgeObstacles,
      result:navigation.planMinionRoute({x:80,y:80},goal,edgeObstacles,allowed)});
  }
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
  const purchaseCases = [
    {name:'population cap',setup:{},actions:Array.from({length:7},()=>({type:'recruit-gatherer',position:{x:140,y:140}}))},
    {name:'one exterior mage',setup:{technologies:['mage']},actions:[{type:'recruit-gatherer',position:{x:85,y:80}},{type:'transform-unit',item:'mage',unitId:'unit-gatherer-01'},{type:'transform-unit',item:'mage',unitId:'unit-gatherer-02'}]},
    {name:'last food provider',setup:{secondRole:'lumberjack'},actions:[{type:'transform-unit',item:'axe',unitId:'unit-gatherer-01'}]},
    {name:'shield single purchase',setup:{secondRole:'guardian',secondHealth:2,technologies:['shield']},actions:[{type:'equip-shield',unitId:'unit-initial-specialist-02'},{type:'equip-shield',unitId:'unit-initial-specialist-02'}]},
    {name:'failed mixed upgrade',setup:{axeLevel:9,amounts:{food:0,wood:0,stone:9,spark:2,gold:2}},actions:[{type:'upgrade-tool',tool:'axe'}]},
  ].map(sample=>{
    const state=createInitialState('totem-tribes-hito-2a');
    state.inventory.amounts=sample.setup.amounts ?? {food:100,wood:100,stone:100,spark:100,gold:100};
    state.progression.unlockedTechnologies=sample.setup.technologies ?? [];
    if(sample.setup.secondRole) state.units[1].role=sample.setup.secondRole;
    if(sample.setup.secondHealth) state.units[1].health=sample.setup.secondHealth;
    if(sample.setup.axeLevel) state.toolLevels.axe=sample.setup.axeLevel;
    projection.applyInputActions(state,sample.actions); // Atomic transactions only, no simulation frames.
    const result=Object.fromEntries(['units','inventory','purchaseCounts','toolLevels','progression'].map(key=>[key,state[key]]));
    return {...sample,result};
  });
  const reference = {
    description: 'Read-only TypeScript data reference. No gameplay loop executed.',
    random: seeds.map(seed => {
      const random = createSeededRandom(seed);
      return { seed, uints: Array.from({ length: 12 }, () => random.nextUint()) };
    }),
    initialStates: seeds.map(seed => createInitialState(seed)),
    purchases:purchaseCases,
    durations:[['tree','wood',1],['stone-vein','stone',1],['stone-vein','stone',2],['berry-bush','food',1],['ruin','spark',1],['twigs','wood',1]].flatMap(([source,type,tier])=>[0,5,10].map(level=>{
      const base=source==='tree'?projection.RESOURCE_SOURCE_GATHER_DURATION_SECONDS.tree:source==='stone-vein'?projection.RESOURCE_SOURCE_GATHER_DURATION_SECONDS['stone-vein'][tier]:projection.GATHER_ACTION_DURATION_SECONDS;
      const tool=type==='wood'?'axe':type==='stone'?'hammer':null;
      return {node:{source,type,tier},levels:{axe:level,hammer:level,sword:0},result:base/(tool?economy.getGatherActionDurationMultiplier(tool,level):1)};
    })),
    combat: {
      attacks:['explorer','gatherer','lumberjack','hunter','guardian','artisan','mage'].flatMap(role=>[0,5,10].map(level=>({role,level,result:combat.getMinionAttackStats(role,level) ?? null}))),
      damage:['minion','barbarian','animal'].flatMap(source=>['minion','barbarian','animal'].flatMap(target=>[-1,0,1,8].map(amount=>({source,target,amount,result:combat.dealDamage(source,target,{health:4,maxHealth:4},amount)})))),
      heal:[-1,0,1,8].map(amount=>({amount,result:combat.healCombatant({health:2,maxHealth:4},amount)})),
    },
    support: {navigation:navCases,routes,segments,idle:idleCases,combatSlots,awareness,
      approaches:[{x:90,y:80},{x:90.2,y:80},{x:91.5,y:80},{x:94,y:80},{x:89.8,y:79.8}].flatMap(position=>[0,1.5].map(interactionRadius=>{
        const resource={position:{x:90,y:80},interactionRadius};
        return {position,resource,result:projection.resourceApproachPosition(position,resource)};
      })),
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
