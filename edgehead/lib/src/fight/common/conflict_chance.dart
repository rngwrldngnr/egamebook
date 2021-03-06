import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/anatomy/body_part.dart';
import 'package:meta/meta.dart';

/// This is a convenience method for constructing [ReasonedSuccessChance]
/// for the combat in Edgehead.
///
/// [performer] and [target] are the two actors at play. [performer] is the
/// actor who is trying to achieve something. [target] is the victim.
///
/// [base] is the base difficulty of the move, and must be between `0` and `1`,
/// exclusive. (For sure failures and sure successes, use
/// [ReasonedSuccessChance.sureFailure] and
/// [ReasonedSuccessChance.sureSuccess], respectively.)
///
/// [bonuses] is the list of adjustments to the [base] success chance.
///
/// Example:
///
///    return getCombatMoveChance(a, enemy, 0.5, [
///      const Bonus(100, CombatReason.dexterity),
///      const Bonus(30, CombatReason.balance),
///    ]);
///
/// The example above defines a combat move that has 50% chance of success when
/// [actor] and [performer] have the same dexterity and the actor is in combat
/// stance. The difference in dexterity of the two actors can nudge
/// the success chance all the way (`100`) up to 100%, or down to 0%. The
/// combat stance can change the final success chance, too, but only by 30%.
ReasonedSuccessChance<CombatReason> getCombatMoveChance(Actor performer,
    Actor target, double base, List<Bonus<CombatReason>> bonuses) {
  assert(base > 0.0, "For sureFailures, use ReasonedSuccessChance.sureFailure");
  assert(
      base < 1.0, "For sureSuccesses, use ReasonedSuccessChance.sureSuccess");

  double value = base;
  final successReasons = List<Reason<CombatReason>>();
  final failureReasons = List<Reason<CombatReason>>();

  for (final bonus in bonuses) {
    assert(bonus.maxAdjustment > 0,
        "There is no reason to have bonuses with maxAdjustment of 0 or below.");
    final scale = _getAdjustmentScale(performer, target, bonus.reason);
    assert(scale >= -1.0);
    assert(scale <= 1.0);
    if (scale == 0.0) continue;

    final previous = value;
    final adjustment = bonus.maxAdjustment * scale;
    value = _lerp(value, adjustment.round());
    final difference = (value - previous).abs();
    final reason = Reason<CombatReason>(bonus.reason, difference);

    if (scale > 0) {
      successReasons.add(reason);
    } else {
      failureReasons.add(reason);
    }
  }

  return ReasonedSuccessChance<CombatReason>(value,
      successReasons: successReasons, failureReasons: failureReasons);
}

/// Returns the portion of body parts with given [function] that are disabled
/// ([BodyPart.isAlive] is `false`).
///
/// When [actor] has no parts with that [function], this method returns `1.0`.
/// It's possible that these parts were cleaved off.
double _fractionDisabled(Actor actor, BodyPartFunction function) {
  int total = 0;
  int disabled = 0;
  for (final part in actor.anatomy.allParts) {
    if (part.function != function) continue;
    total += 1;
    if (!part.isAlive) {
      disabled += 1;
    }
  }
  if (total == 0) return 1.0;
  return disabled / total;
}

/// Given the current state of [performer] and [target], to what degree
/// is [reason] applicable as a bonus.
///
/// For example, if both actors have the same dexterity, then this function
/// returns `0.0` for [CombatReason.dexterity]. When the [performer] is more
/// than `100` points of dexterity better, it will return `1.0`.
double _getAdjustmentScale(Actor performer, Actor target, CombatReason reason) {
  switch (reason) {
    case CombatReason.dexterity:
      return (performer.dexterity - target.dexterity).clamp(-100, 100) / 100;
    case CombatReason.balance:
      if (performer.isOffBalance && !target.isOffBalance) {
        return -1.0;
      } else if (!performer.isOffBalance && target.isOffBalance) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.height:
      if (performer.isOnGround && !target.isOnGround) {
        return -1.0;
      } else if (!performer.isOnGround && target.isOnGround) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetWithoutShield:
      if (target.currentShield == null) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetHasPrimaryArmDisabled:
      if (_partDisabled(target, BodyPartDesignation.primaryArm)) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetHasSecondaryArmDisabled:
      if (_partDisabled(target, BodyPartDesignation.secondaryArm)) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetHasOneLegDisabled:
      final percent = _fractionDisabled(target, BodyPartFunction.mobile);
      if (percent > 0 && percent < 1) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetHasAllLegsDisabled:
      final percent = _fractionDisabled(target, BodyPartFunction.mobile);
      if (percent == 1.0) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetHasOneEyeDisabled:
      final percent = _fractionDisabled(target, BodyPartFunction.vision);
      if (percent > 0 && percent < 1) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
    case CombatReason.targetHasAllEyesDisabled:
      final percent = _fractionDisabled(target, BodyPartFunction.vision);
      if (percent == 1.0) {
        return 1.0;
      } else {
        return 0.0;
      }
      throw StateError("Forgotten logic branch"); // ignore: dead_code
  }

  throw ArgumentError("no rule for $reason");
}

double _lerp(double current, int bonus) {
  if (bonus >= 100) return 1.0;
  if (bonus <= -100) return 0.0;

  final distance = bonus.isNegative ? current : 1.0 - current;
  final portion = bonus / 100;
  return current + portion * distance;
}

/// Returns `true` if the (single) part that's defined by [designation]
/// is dead ([BodyPart.isAlive] is `false`).
bool _partDisabled(Actor actor, BodyPartDesignation designation) {
  return !actor.anatomy.findByDesignation(designation).isAlive;
}

@immutable
class Bonus<R> {
  final int maxAdjustment;
  final R reason;

  const Bonus(this.maxAdjustment, this.reason);
}

/// Reasons for the performer of a move (e.g. attacker) to be successful
/// or unsuccessful.
///
/// For example, if a [Bonus] has a [CombatReason.dexterity] and the
/// [Bonus.maxAdjustment] is positive, it means that the (possible) success was
/// partly because the performer was more dexterous than the target
/// (e.g. fast slash). If [Bonus.maxAdjustment] is negative, than the
/// (possible) failure was because the target was more dexterous
/// (e.g. dodged slash).
enum CombatReason {
  /// The general ability to move during combat. Includes ability to use
  /// weapons in case of humanoids.
  dexterity,

  /// The relative balance. Attacking out of balance is bad, especially if
  /// the enemy has good combat stance. And vice versa, defending while
  /// out of balance is bad.
  balance,

  /// Advantage for the actor who is standing above the enemy thanks to
  /// a) terrain or b) posture. For example, an actor on a table has
  /// a height advantage. An actor lying on the ground has a height
  /// disadvantage towards an actor who is standing (regardless whether
  /// the standing actor is in balance or not).
  height,

  /// The fact that the target doesn't have (or can't use) a shield to deflect
  /// or foil the move.
  targetWithoutShield,

  /// The fact that the target has disabled (or cleaved off) primary arm,
  /// meaning that he cannot move it to defend themselves.
  targetHasPrimaryArmDisabled,

  /// The fact that the target has disabled (or cleaved off) secondary arm,
  /// meaning that he cannot move it to defend themselves.
  targetHasSecondaryArmDisabled,

  /// One of the (probably two) legs is disabled. Dodging and movement
  /// is harder.
  targetHasOneLegDisabled,

  /// All legs (i.e. _both_ legs in case of humanoids) are disabled or
  /// cleaved-off. No dodging for the target, and severely impacted
  /// ability to defend oneself.
  targetHasAllLegsDisabled,

  /// One of target's eyes is non-functional. Makes fighting harder.
  targetHasOneEyeDisabled,

  /// All eyes (i.e. _both_ eyes, for most creatures) are non-functional.
  /// Severely impacts the target's ability to defend themselves.
  targetHasAllEyesDisabled,

  // TODO: weaponDexterity /// Lightness of weapon
  // TODO: reach /// Advantage of longer limbs and longer weapons
  // TODO: strength /// Brute force (e.g. withstanding a kick, still standing)
}
