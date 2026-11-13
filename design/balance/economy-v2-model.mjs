// Economic scenarios conditional on successful runs. This is not a combat simulator.
// Run: node design/balance/economy-v2-model.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";

const balanceBytes = readFileSync(new URL("../../assets/data/game_balance.json", import.meta.url));
const balance = JSON.parse(balanceBytes);
const balanceHash = createHash("sha256").update(balanceBytes).digest("hex");
const dungeonCount = balance.dungeon_order.length;
const floorLimit = balance.modes.timed.floor_limit;
const upgradePrice = Array.from({length: balance.upgrades.max_per_item}, (_, u) =>
  balance.upgrades.price_base + balance.upgrades.price_step * u).reduce((a, b) => a + b, 0);

const trials = 1000;
const seedBase = 0x20261020;
const prices = Object.fromEntries(Object.entries(balance.village.objects).map(([id, value]) => [id, value.stage_prices]));
const priority = [
  ["square", 1], ["houses", 1], ["chronicler", 1], ["marketplace", 1],
  ["marketplace", 2], ["forge", 1], ["alchemist", 1], ["forge", 2],
  ["alchemist", 2], ["square", 2], ["houses", 2], ["chronicler", 2],
  ["square", 3], ["houses", 3], ["chronicler", 3], ["marketplace", 3],
  ["forge", 3], ["alchemist", 3],
];
// Columns: kind, sale value, base effect, weight, required alchemist stage.
const allCards = Object.values(balance.items.cards).map(card => [
  ["weapon", "armor"].includes(card.kind) ? "gear" : card.kind,
  balance.economy.sale_by_rarity[card.rarity],
  card.heal ?? card.power_buff ?? card.power ?? 0, card.loot_weight, card.alchemist_stage,
]);
const totalVillageStages = Object.values(prices).reduce((sum, values) => sum + values.length, 0);
const starterCount = kind => balance.starter.consumables.filter(item => balance.items.cards[item.id].kind === kind)
  .reduce((sum, item) => sum + item.count, 0);
// The experiment covers first clears and the approved single-choice reward rule.
if (balance.loot.pick_count !== 1 || !balance.loot.without_replacement) throw Error("Unsupported loot policy for this model");
const policies = [
  { id: "regular_trader", sellProbability: 1, reforgeEvery: 5 },
  { id: "partial_trader", sellProbability: 0.7, reforgeEvery: 5 },
  { id: "frequent_reforge", sellProbability: 1, reforgeEvery: 2 },
];
function rng(seed) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let value = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    value = value + Math.imul(value ^ (value >>> 7), 61 | value) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}
function quantile(values, p) {
  const sorted = values.slice().sort((a, b) => a - b);
  return sorted[Math.floor((sorted.length - 1) * p)];
}
function simulate(policy, trial) {
  const random = rng((seedBase + trial * 101) >>> 0);
  const stage = Object.fromEntries(Object.keys(prices).map(id => [id, balance.village.initial_stage]));
  const defeatedFinalBosses = new Set();
  let wallet = balance.hero.starting_gold, incoming = wallet, outgoing = 0, nextPurchase = 0;
  const runs = [];
  for (let dungeon = 1; dungeon <= dungeonCount; dungeon++) {
    const pool = allCards.filter(card => card[4] <= stage.alchemist && card[3] > 0);
    if (pool.length < balance.loot.offer_count) throw Error("Loot pool too small");
    const poolWeight = pool.reduce((sum, card) => sum + card[3], 0);
    let buffs = starterCount("buff"), potions = starterCount("potion"), sales = 0, gross = 0, upgrades = 0, shortages = 0;
    for (let floor = 1; floor <= floorLimit; floor++) {
      // A resource budget, not a calculation of damage or actual survival.
      const required = (floor === 1 ? 1 : 2) + (floor === floorLimit && stage.forge < 2 ? 1 : 0);
      const used = Math.min(buffs, required);
      buffs -= used;
      shortages += required - used;
      if (floor % 3 === 0) {
        if (potions > 0) potions--;
        else shortages++;
      }
      const depth = balance.modes.timed.depth_stride * (dungeon - 1) + floor - 1;
      const composition = floor === 1 ? balance.floor.first_floor : balance.floor.later_floors;
      const rewards = balance.economy.gold_per_victory;
      const gold = (composition.regular * rewards.regular_multiplier + composition.elite * rewards.elite_multiplier + rewards.boss_multiplier)
        * (rewards.base + Math.floor(depth / rewards.depth_divisor));
      gross += gold; wallet += gold; incoming += gold;
      // Final-floor cards cannot be sold in camp before the accepted result screen.
      if (floor < floorLimit) for (let drop = 0; drop < composition.regular + composition.elite + 1; drop++) {
        const indices = [];
        while (indices.length < balance.loot.offer_count) {
          let ticket = random() * poolWeight;
          let index = 0;
          while (index < pool.length - 1 && ticket >= pool[index][3]) ticket -= pool[index++][3];
          if (!indices.includes(index)) indices.push(index);
        }
        const offer = indices.map(index => pool[index]);
        let kept = null;
        if (buffs < 4) kept = offer.filter(card => card[0] === "buff").sort((a, b) => b[2] - a[2])[0];
        if (!kept && potions < 3) kept = offer.filter(card => card[0] === "potion").sort((a, b) => b[2] - a[2])[0];
        if (kept) {
          if (kept[0] === "buff") buffs++;
          else potions++;
        } else if (policy.sellProbability === 1 || random() < policy.sellProbability) {
          // Omitted sales are retained/discarded; never counted as spendable gold.
          const value = Math.max(...offer.map(card => card[1]));
          wallet += value; incoming += value; sales += value;
        }
      }
      if (floor < floorLimit && floor % policy.reforgeEvery === 0 && wallet >= upgradePrice) {
        wallet -= upgradePrice; outgoing += upgradePrice; upgrades += upgradePrice;
      }
    }
    // The final bonus is available only after the final boss, not during the run.
    const dungeonId = balance.dungeon_order[dungeon - 1];
    if (defeatedFinalBosses.has(dungeonId)) throw Error("This experiment only supports first clears");
    const bonus = balance.economy.first_final_boss_bonus;
    defeatedFinalBosses.add(dungeonId);
    wallet += bonus; incoming += bonus; gross += bonus;
    const beforeVillage = wallet;
    while (nextPurchase < priority.length) {
      const [id, target] = priority[nextPurchase];
      const cost = prices[id][target - 1];
      const reserve = nextPurchase === 0 ? 0 : 500;
      if (wallet - cost < reserve) break;
      const prerequisite = balance.village.objects[id].prerequisites.every(rule => stage[rule.id] >= rule.stage);
      if (!prerequisite || stage[id] !== target - 1) throw new Error("Invalid purchase order");
      wallet -= cost; outgoing += cost; stage[id] = target; nextPurchase++;
    }
    if (wallet !== incoming - outgoing) throw new Error("Gold conservation failed");
    runs.push({
      dungeon, gross, sales, upgrades, net: gross + sales - upgrades,
      beforeVillage, wallet, stages: nextPurchase, shortages,
      forge: stage.forge, alchemist: stage.alchemist,
    });
  }
  return runs;
}
const scenarios = policies.map(policy => {
  const samples = Array.from({ length: dungeonCount }, () => []);
  for (let trial = 0; trial < trials; trial++) {
    for (const run of simulate(policy, trial)) samples[run.dungeon - 1].push(run);
  }
  return {
    policy,
    runs: samples.map((runs, index) => ({
      dungeon: index + 1, gross: runs[0].gross,
      salesMedian: quantile(runs.map(run => run.sales), 0.5),
      upgradesMedian: quantile(runs.map(run => run.upgrades), 0.5),
      netMedian: quantile(runs.map(run => run.net), 0.5),
      walletMedian: quantile(runs.map(run => run.wallet), 0.5),
      walletP10: quantile(runs.map(run => run.wallet), 0.1),
      walletP90: quantile(runs.map(run => run.wallet), 0.9),
      stagesMedian: quantile(runs.map(run => run.stages), 0.5),
      allStagesScenarios: runs.filter(run => run.stages === totalVillageStages).length,
      resourceBudgetShortagesMedian: quantile(runs.map(run => run.shortages), 0.5),
    })),
  };
});
const result = {
  version: 2, trialsPerPolicy: trials, seedBase, scenarioBasis: "APPROVED dungeon progression; first clear of each dungeon",
  balanceVersion: balance.balance_version, balanceSha256: balanceHash,
  conditionalOn: "five distinct successful first clears; no combat or HP simulation; no win-rate inference",
  assumptions: {
    scrollBuffer: 4, potionBuffer: 3, potionBudget: "one every third floor",
    villageReservePolicy: 500, villageReserveIsGameRule: false,
    equipmentDropAvailabilitySimulated: false, finalFloorLootSales: false,
    finalBonusTiming: "after first permanent death of each final boss", reforgePrice: upgradePrice,
    weaponCostMeans: "replacement and five upgrades; not upgrading the same item beyond U5",
  },
  prices, purchasePriority: priority,
  allVillageStagesCost: Object.values(prices).flat().reduce((sum, price) => sum + price, 0),
  scenarios, conservationChecks: "passed for all scenarios",
};
writeFileSync(new URL("economy-v2-results-2026-10-20.json", import.meta.url), JSON.stringify(result, null, 2) + "\n", "utf8");
console.log(JSON.stringify(result, null, 2));
