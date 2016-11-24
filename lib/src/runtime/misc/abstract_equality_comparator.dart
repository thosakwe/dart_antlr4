import 'equality_comparator.dart';

/**
 * This abstract base class is provided so performance-critical applications can
 * use virtual- instead of interface-dispatch when calling comparator methods.
 *
 * @author Sam Harwell
 */
abstract class AbstractEqualityComparator<T> implements EqualityComparator<T> {}