import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/context.dart';
import 'package:edgehead/fractal_stories/simulation.dart';
import 'package:edgehead/fractal_stories/storyline/randomly.dart';
import 'package:edgehead/fractal_stories/storyline/storyline.dart';
import 'package:edgehead/fractal_stories/team.dart';
import 'package:edgehead/fractal_stories/world_state.dart';
import 'package:edgehead/src/fight/common/conflict_chance.dart';
import 'package:edgehead/src/fight/common/defense_situation.dart';
import 'package:edgehead/src/fight/common/weapon_as_object2.dart';

final Entity swing =
    Entity(name: "swing", team: neutralTeam, nameIsProperNoun: true);

ReasonedSuccessChance computeOnGroundShieldBlock(
    Actor a, Simulation sim, WorldState w, Actor enemy) {
  return getCombatMoveChance(a, enemy, 0.7, [
    const Bonus(70, CombatReason.dexterity),
  ]);
}

class OnGroundShieldBlock extends OtherActorAction {
  static final OnGroundShieldBlock singleton = OnGroundShieldBlock();

  static const String className = "OnGroundShieldBlock";

  @override
  final String helpMessage = "A shield blocks enemy attacks with the least "
      "amount of energy and movement.";

  @override
  final bool isAggressive = false;

  @override
  final bool isProactive = false;

  @override
  final bool rerollable = true;

  @override
  final Resource rerollResource = Resource.stamina;

  @override
  String get commandTemplate => "block with shield";

  @override
  String get name => className;

  @override
  String get rollReasonTemplate => "will <subject> block the strike?";

  @override
  String applyFailure(ActionContext context, Actor enemy) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    a.report(
        s,
        "<subject> tr<ies> to {block|stop|deflect} the {swing|attack|strike} "
        "with ${shieldAsObject2(a)}");
    Randomly.run(
        () => a.report(s, "<subject> {fail<s>|<does>n't succeed}", but: true),
        () => a.report(s, "<subject> <is> too slow", but: true),
        () => enemy.report(s, "<subject> <is> too quick for <object>",
            object: a, but: true));
    w.popSituation(sim);
    return "${a.name} fails to block ${enemy.name} with shield on ground";
  }

  @override
  String applySuccess(ActionContext context, Actor enemy) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    if (enemy.isOffBalance) {
      s.add("<subject> <is> out of balance",
          subject: enemy, negative: true, startSentence: true);
      s.add("so <ownerPronoun's> <subject> is {weak|feeble}",
          owner: enemy, subject: swing);
      a.report(
          s,
          "<subject> easily {block<s>|stop<s>|deflect<s>} "
          "the {swing|attack|strike} "
          "with ${shieldAsObject2(a)}",
          positive: true);
    } else {
      a.report(
          s,
          "<subject> {block<s>|stop<s>|deflect<s>} the {swing|attack|strike} "
          "with ${shieldAsObject2(a)}",
          positive: true);
    }

    w.popSituationsUntil("FightSituation", sim);
    return "${a.name} blocks ${enemy.name} with a shield on ground";
  }

  @override
  ReasonedSuccessChance getSuccessChance(
      Actor a, Simulation sim, WorldState w, Actor enemy) {
    final situation = w.currentSituation as DefenseSituation;
    return situation.predeterminedChance
        .or(computeOnGroundShieldBlock(a, sim, w, enemy));
  }

  @override
  bool isApplicable(Actor a, Simulation sim, WorldState w, Actor enemy) =>
      a.currentShield != null;
}
