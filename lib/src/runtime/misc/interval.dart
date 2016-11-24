import 'dart:math' as math;

/** An immutable inclusive interval a..b */
class Interval {
  static final int INTERVAL_POOL_MAX_VALUE = 1000;

  static final Interval INVALID = new Interval(-1, -2);

  static List<Interval> cache = new List<Interval>(INTERVAL_POOL_MAX_VALUE + 1);

  int a;
  int b;

  static int creates = 0;
  static int misses = 0;
  static int hits = 0;
  static int outOfRange = 0;

  Interval(int a, int b) {
    this.a = a;
    this.b = b;
  }

  /** Interval objects are used readonly so share all with the
   *  same single value a==b up to some max size.  Use an array as a perfect hash.
   *  Return shared object for 0..INTERVAL_POOL_MAX_VALUE or a new
   *  Interval object with a..a in it.  On Java.g4, 218623 IntervalSets
   *  have a..a (set with 1 element).
   */
  static Interval of(int a, int b) {
    // cache just a..a
    if (a != b || a < 0 || a > INTERVAL_POOL_MAX_VALUE) {
      return new Interval(a, b);
    }
    if (cache[a] == null) {
      cache[a] = new Interval(a, a);
    }
    return cache[a];
  }

  /** return number of elements between a and b inclusively. x..x is length 1.
   *  if b &lt; a, then length is 0.  9..10 has length 2.
   */
  int length() {
    if (b < a) return 0;
    return b - a + 1;
  }

  @override
  bool operator ==(Object o) {
    if (o == null || !(o is Interval)) {
      return false;
    }

    Interval other = o;
    return this.a == other.a && this.b == other.b;
  }

  @override
  int hashCode() {
    int hash = 23;
    hash = hash * 31 + a;
    hash = hash * 31 + b;
    return hash;
  }

  /** Does this start completely before other? Disjoint */
  bool startsBeforeDisjoint(Interval other) {
    return this.a < other.a && this.b < other.a;
  }

  /** Does this start at or before other? Nondisjoint */
  bool startsBeforeNonDisjoint(Interval other) {
    return this.a <= other.a && this.b >= other.a;
  }

  /** Does this.a start after other.b? May or may not be disjoint */
  bool startsAfter(Interval other) {
    return this.a > other.a;
  }

  /** Does this start completely after other? Disjoint */
  bool startsAfterDisjoint(Interval other) {
    return this.a > other.b;
  }

  /** Does this start after other? NonDisjoint */
  bool startsAfterNonDisjoint(Interval other) {
    return this.a > other.a && this.a <= other.b; // this.b>=other.b implied
  }

  /** Are both ranges disjoint? I.e., no overlap? */
  bool disjoint(Interval other) {
    return startsBeforeDisjoint(other) || startsAfterDisjoint(other);
  }

  /** Are two intervals adjacent such as 0..41 and 42..42? */
  bool adjacent(Interval other) {
    return this.a == other.b + 1 || this.b == other.a - 1;
  }

  bool properlyContains(Interval other) {
    return other.a >= this.a && other.b <= this.b;
  }

  /** Return the interval computed from combining this and other */
  Interval union(Interval other) {
    return Interval.of(math.min(a, other.a), math.max(b, other.b));
  }

  /** Return the interval in common between this and o */
  Interval intersection(Interval other) {
    return Interval.of(math.max(a, other.a), math.min(b, other.b));
  }

  /** Return the interval with elements from this not in other;
   *  other must not be totally enclosed (properly contained)
   *  within this, which would result in two disjoint intervals
   *  instead of the single one returned by this method.
   */
  Interval differenceNotProperlyContained(Interval other) {
    Interval diff = null;
    // other.a to left of this.a (or same)
    if (other.startsBeforeNonDisjoint(this)) {
      diff = Interval.of(math.max(this.a, other.b + 1), this.b);
    }

    // other.a to right of this.a
    else if (other.startsAfterNonDisjoint(this)) {
      diff = Interval.of(this.a, other.a - 1);
    }
    return diff;
  }

  @override
  String toString() {
    return "$a..$b";
  }
}
