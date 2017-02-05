import 'dart:collection';

/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../lexer.dart';
import 'interval.dart';
import 'murmur_hash.dart';

/**
 * This class implements the {@link IntSet} backed by a sorted array of
 * non-overlapping intervals. It is particularly efficient for representing
 * large collections of numbers, where the majority of elements appear as part
 * of a sequential range of numbers that are all part of the set. For example,
 * the set { 1, 2, 3, 4, 7, 8 } may be represented as { [1, 4], [7, 8] }.
 *
 * <p>
 * This class is able to represent sets containing any combination of values in
 * the range {@link Integer#MIN_VALUE} to {@link Integer#MAX_VALUE}
 * (inclusive).</p>
 */
 class IntervalSet implements IntSet {
	 static final IntervalSet COMPLETE_CHAR_SET = IntervalSet.of(Lexer.MIN_CHAR_VALUE, Lexer.MAX_CHAR_VALUE);

	/*static {
		COMPLETE_CHAR_SET.setReadonly(true);
	}*/

	 static final IntervalSet EMPTY_SET = new IntervalSet();
	/*static {
		EMPTY_SET.setReadonly(true);
	}*/

	/** The list of sorted, disjoint intervals. */
     List<Interval> intervals;

     bool readonly;

	 IntervalSet.fromIntervals(List<Interval> intervals) {
		this.intervals = intervals;
	}

	 IntervalSet.from(IntervalSet set) => new IntervalSet()..addAll(set);

   IntervalSet([List<int> els]) {
		if ( els==null ) {
			intervals = new ArrayList<Interval>(2); // most sets are 1 or 2 elements
		}
		else {
			intervals = new ArrayList<Interval>(els.length);
			for (int e in els) add(e);
		}
	}

	/** Create a set with a single element, el. */

     static IntervalSet of(int a) {
		IntervalSet s = new IntervalSet();
        s.add(a);
        return s;
    }

    /** Create a set with all ints within range [a..b] (inclusive) */
	 static IntervalSet of(int a, int b) {
		IntervalSet s = new IntervalSet();
		s.add(a,b);
		return s;
	}

	 void clear() {
        if ( readonly ) throw new IllegalStateException("can't alter readonly IntervalSet");
		intervals.clear();
	}

    /** Add a single element to the set.  An isolated element is stored
     *  as a range el..el.
     */
    @override
     void add(int el) {
        if ( readonly ) throw new IllegalStateException("can't alter readonly IntervalSet");
        add(el,el);
    }

    /** Add interval; i.e., add all integers from a to b to set.
     *  If b&lt;a, do nothing.
     *  Keep list in sorted order (by left range value).
     *  If overlap, combine ranges.  For example,
     *  If this is {1..5, 10..20}, adding 6..7 yields
     *  {1..5, 6..7, 10..20}.  Adding 4..8 yields {1..8, 10..20}.
     */
     void add(int a, int b) {
        add(Interval.of(a, b));
    }

	// copy on write so we can cache a..a intervals and sets of that
	 void add(Interval addition) {
        if ( readonly ) throw new IllegalStateException("can't alter readonly IntervalSet");
		//System.out.println("add "+addition+" to "+intervals.toString());
		if ( addition.b<addition.a ) {
			return;
		}
		// find position in list
		// Use iterators as we modify list in place
		for (ListIterator<Interval> iter = intervals.listIterator(); iter.hasNext();) {
			Interval r = iter.next();
			if ( addition.equals(r) ) {
				return;
			}
			if ( addition.adjacent(r) || !addition.disjoint(r) ) {
				// next to each other, make a single larger interval
				Interval bigger = addition.union(r);
				iter.set(bigger);
				// make sure we didn't just create an interval that
				// should be merged with next interval in list
				while ( iter.hasNext() ) {
					Interval next = iter.next();
					if ( !bigger.adjacent(next) && bigger.disjoint(next) ) {
						break;
					}

					// if we bump up against or overlap next, merge
					iter.remove();   // remove this one
					iter.previous(); // move backwards to what we just set
					iter.set(bigger.union(next)); // set to 3 merged ones
					iter.next(); // first call to next after previous duplicates the result
				}
				return;
			}
			if ( addition.startsBeforeDisjoint(r) ) {
				// insert before r
				iter.previous();
				iter.add(addition);
				return;
			}
			// if disjoint and after r, a future iteration will handle it
		}
		// ok, must be after last interval (and disjoint from last interval)
		// just add it
		intervals.add(addition);
	}

	/** combine all sets in the array returned the or'd value */
	 static IntervalSet or(List<IntervalSet> sets) {
		IntervalSet r = new IntervalSet();
		for (IntervalSet s in sets) r.addAll(s);
		return r;
	}

	@override
	 IntervalSet addAll(IntSet set) {
		if ( set==null ) {
			return this;
		}

		if (set is IntervalSet) {
			IntervalSet other = set;
			// walk set and add each interval
			int n = other.intervals.size();
			for (int i = 0; i < n; i++) {
				Interval I = other.intervals.get(i);
				this.add(I.a,I.b);
			}
		}
		else {
			for (int value in set.toList()) {
				add(value);
			}
		}

		return this;
    }

     IntervalSet complement(int minElement, int maxElement) {
        return this.complement(IntervalSet.of(minElement,maxElement));
    }

    /** {@inheritDoc} */
    @override
     IntervalSet complement(IntSet vocabulary) {
		if ( vocabulary==null || vocabulary.isNil() ) {
			return null; // nothing in common with null set
		}

		IntervalSet vocabularyIS;
		if (vocabulary is IntervalSet) {
			vocabularyIS = vocabulary;
		}
		else {
			vocabularyIS = new IntervalSet();
			vocabularyIS.addAll(vocabulary);
		}

		return vocabularyIS.subtract(this);
    }

	@override
	 IntervalSet subtract(IntSet a) {
		if (a == null || a.isNil()) {
			return new IntervalSet(this);
		}

		if (a is IntervalSet) {
			return subtract(this, a);
		}

		IntervalSet other = new IntervalSet();
		other.addAll(a);
		return subtract(this, other);
	}

	/**
	 * Compute the set difference between two interval sets. The specific
	 * operation is {@code left - right}. If either of the input sets is
	 * {@code null}, it is treated as though it was an empty set.
	 */

	 static IntervalSet subtract(IntervalSet left, IntervalSet right) {
		if (left == null || left.isNil()) {
			return new IntervalSet();
		}

		IntervalSet result = new IntervalSet(left);
		if (right == null || right.isNil()) {
			// right set has no elements; just return the copy of the current set
			return result;
		}

		int resultI = 0;
		int rightI = 0;
		while (resultI < result.intervals.size() && rightI < right.intervals.size()) {
			Interval resultInterval = result.intervals.get(resultI);
			Interval rightInterval = right.intervals.get(rightI);

			// operation: (resultInterval - rightInterval) and update indexes

			if (rightInterval.b < resultInterval.a) {
				rightI++;
				continue;
			}

			if (rightInterval.a > resultInterval.b) {
				resultI++;
				continue;
			}

			Interval beforeCurrent = null;
			Interval afterCurrent = null;
			if (rightInterval.a > resultInterval.a) {
				beforeCurrent = new Interval(resultInterval.a, rightInterval.a - 1);
			}

			if (rightInterval.b < resultInterval.b) {
				afterCurrent = new Interval(rightInterval.b + 1, resultInterval.b);
			}

			if (beforeCurrent != null) {
				if (afterCurrent != null) {
					// split the current interval into two
					result.intervals.set(resultI, beforeCurrent);
					result.intervals.add(resultI + 1, afterCurrent);
					resultI++;
					rightI++;
					continue;
				}
				else {
					// replace the current interval
					result.intervals.set(resultI, beforeCurrent);
					resultI++;
					continue;
				}
			}
			else {
				if (afterCurrent != null) {
					// replace the current interval
					result.intervals.set(resultI, afterCurrent);
					rightI++;
					continue;
				}
				else {
					// remove the current interval (thus no need to increment resultI)
					result.intervals.remove(resultI);
					continue;
				}
			}
		}

		// If rightI reached right.intervals.size(), no more intervals to subtract from result.
		// If resultI reached result.intervals.size(), we would be subtracting from an empty set.
		// Either way, we are done.
		return result;
	}

	@override
	 IntervalSet or(IntSet a) {
		IntervalSet o = new IntervalSet();
		o.addAll(this);
		o.addAll(a);
		return o;
	}

    /** {@inheritDoc} */
	@override
	 IntervalSet and(IntSet other) {
		if ( other==null ) { //|| !(other instanceof IntervalSet) ) {
			return null; // nothing in common with null set
		}

		List<Interval> myIntervals = this.intervals;
		List<Interval> theirIntervals = (other).intervals;
		IntervalSet intersection = null;
		int mySize = myIntervals.size();
		int theirSize = theirIntervals.size();
		int i = 0;
		int j = 0;
		// iterate down both interval lists looking for nondisjoint intervals
		while ( i<mySize && j<theirSize ) {
			Interval mine = myIntervals.get(i);
			Interval theirs = theirIntervals.get(j);
			//System.out.println("mine="+mine+" and theirs="+theirs);
			if ( mine.startsBeforeDisjoint(theirs) ) {
				// move this iterator looking for interval that might overlap
				i++;
			}
			else if ( theirs.startsBeforeDisjoint(mine) ) {
				// move other iterator looking for interval that might overlap
				j++;
			}
			else if ( mine.properlyContains(theirs) ) {
				// overlap, add intersection, get next theirs
				if ( intersection==null ) {
					intersection = new IntervalSet();
				}
				intersection.add(mine.intersection(theirs));
				j++;
			}
			else if ( theirs.properlyContains(mine) ) {
				// overlap, add intersection, get next mine
				if ( intersection==null ) {
					intersection = new IntervalSet();
				}
				intersection.add(mine.intersection(theirs));
				i++;
			}
			else if ( !mine.disjoint(theirs) ) {
				// overlap, add intersection
				if ( intersection==null ) {
					intersection = new IntervalSet();
				}
				intersection.add(mine.intersection(theirs));
				// Move the iterator of lower range [a..b], but not
				// the upper range as it may contain elements that will collide
				// with the next iterator. So, if mine=[0..115] and
				// theirs=[115..200], then intersection is 115 and move mine
				// but not theirs as theirs may collide with the next range
				// in thisIter.
				// move both iterators to next ranges
				if ( mine.startsAfterNonDisjoint(theirs) ) {
					j++;
				}
				else if ( theirs.startsAfterNonDisjoint(mine) ) {
					i++;
				}
			}
		}
		if ( intersection==null ) {
			return new IntervalSet();
		}
		return intersection;
	}

    /** {@inheritDoc} */
    @override
     bool contains(int el) {
		int n = intervals.size();
		for (int i = 0; i < n; i++) {
			Interval I = intervals.get(i);
			int a = I.a;
			int b = I.b;
			if ( el<a ) {
				break; // list is sorted and el is before this interval; not here
			}
			if ( el>=a && el<=b ) {
				return true; // found in this interval
			}
		}
		return false;
/*
		for (ListIterator iter = intervals.listIterator(); iter.hasNext();) {
            Interval I = (Interval) iter.next();
            if ( el<I.a ) {
                break; // list is sorted and el is before this interval; not here
            }
            if ( el>=I.a && el<=I.b ) {
                return true; // found in this interval
            }
        }
        return false;
        */
    }

    /** {@inheritDoc} */
    @override
     bool isNil() {
        return intervals==null || intervals.isEmpty();
    }

    /** {@inheritDoc} */
    @override
     int getSingleElement() {
        if ( intervals!=null && intervals.size()==1 ) {
            Interval I = intervals.get(0);
            if ( I.a == I.b ) {
                return I.a;
            }
        }
        return Token.INVALID_TYPE;
    }

	/**
	 * Returns the maximum value contained in the set.
	 *
	 * @return the maximum value contained in the set. If the set is empty, this
	 * method returns {@link Token#INVALID_TYPE}.
	 */
	 int getMaxElement() {
		if ( isNil() ) {
			return Token.INVALID_TYPE;
		}
		Interval last = intervals.get(intervals.size()-1);
		return last.b;
	}

	/**
	 * Returns the minimum value contained in the set.
	 *
	 * @return the minimum value contained in the set. If the set is empty, this
	 * method returns {@link Token#INVALID_TYPE}.
	 */
	 int getMinElement() {
		if ( isNil() ) {
			return Token.INVALID_TYPE;
		}

		return intervals.get(0).a;
	}

    /** Return a list of Interval objects. */
     List<Interval> getIntervals() {
        return intervals;
    }

	@override
	 int hashCode() {
		int hash = MurmurHash.initialize();
		for (Interval I in intervals) {
			hash = MurmurHash.update(hash, I.a);
			hash = MurmurHash.update(hash, I.b);
		}

		hash = MurmurHash.finish(hash, intervals.size() * 2);
		return hash;
	}

	/** Are two IntervalSets equal?  Because all intervals are sorted
     *  and disjoint, equals is a simple linear walk over both lists
     *  to make sure they are the same.  Interval.equals() is used
     *  by the List.equals() method to check the ranges.
     */
    @override
     bool equals(Object obj) {
        if ( obj==null || obj is! IntervalSet ) {
            return false;
        }
        IntervalSet other = obj;
		return this.intervals.equals(other.intervals);
	}

	@override
	 String toString() { return toString(false); }

	 String toString(bool elemAreChar) {
		StringBuilder buf = new StringBuilder();
		if ( this.intervals==null || this.intervals.isEmpty() ) {
			return "{}";
		}
		if ( this.size()>1 ) {
			buf.append("{");
		}
		Iterator<Interval> iter = this.intervals.iterator();
		while (iter.hasNext()) {
			Interval I = iter.next();
			int a = I.a;
			int b = I.b;
			if ( a==b ) {
				if ( a==Token.EOF ) buf.append("<EOF>");
				else if ( elemAreChar ) buf.append("'").append(a).append("'");
				else buf.append(a);
			}
			else {
				if ( elemAreChar ) buf.append("'").append(a).append("'..'").append(b).append("'");
				else buf.append(a).append("..").append(b);
			}
			if ( iter.hasNext() ) {
				buf.append(", ");
			}
		}
		if ( this.size()>1 ) {
			buf.append("}");
		}
		return buf.toString();
	}

	/**
	 * @deprecated Use {@link #toString(Vocabulary)} instead.
	 */
	@deprecated
	 String toString(List<String> tokenNames) {
		return toString(VocabularyImpl.fromTokenNames(tokenNames));
	}

	 String toString(Vocabulary vocabulary) {
		StringBuilder buf = new StringBuilder();
		if ( this.intervals==null || this.intervals.isEmpty() ) {
			return "{}";
		}
		if ( this.size()>1 ) {
			buf.append("{");
		}
		Iterator<Interval> iter = this.intervals.iterator();
		while (iter.hasNext()) {
			Interval I = iter.next();
			int a = I.a;
			int b = I.b;
			if ( a==b ) {
				buf.append(elementName(vocabulary, a));
			}
			else {
				for (int i=a; i<=b; i++) {
					if ( i>a ) buf.append(", ");
                    buf.append(elementName(vocabulary, i));
				}
			}
			if ( iter.hasNext() ) {
				buf.append(", ");
			}
		}
		if ( this.size()>1 ) {
			buf.append("}");
		}
        return buf.toString();
    }

	/**
	 * @deprecated Use {@link #elementName(Vocabulary, int)} instead.
	 */
	@deprecated
	 String elementName(List<String> tokenNames, int a) {
		return elementName(VocabularyImpl.fromTokenNames(tokenNames), a);
	}


	 String elementName(Vocabulary vocabulary, int a) {
		if (a == Token.EOF) {
			return "<EOF>";
		}
		else if (a == Token.EPSILON) {
			return "<EPSILON>";
		}
		else {
			return vocabulary.getDisplayName(a);
		}
	}

    @override
     int size() {
		int n = 0;
		int numIntervals = intervals.size();
		if ( numIntervals==1 ) {
			Interval firstInterval = this.intervals.get(0);
			return firstInterval.b-firstInterval.a+1;
		}
		for (int i = 0; i < numIntervals; i++) {
			Interval I = intervals.get(i);
			n += (I.b-I.a+1);
		}
		return n;
    }

	 IntegerList toIntegerList() {
		IntegerList values = new IntegerList(size());
		int n = intervals.size();
		for (int i = 0; i < n; i++) {
			Interval I = intervals.get(i);
			int a = I.a;
			int b = I.b;
			for (int v=a; v<=b; v++) {
				values.add(v);
			}
		}
		return values;
	}

    @override
     List<int> toList() {
		List<int> values = [];
		int n = intervals.size();
		for (int i = 0; i < n; i++) {
			Interval I = intervals.get(i);
			int a = I.a;
			int b = I.b;
			for (int v=a; v<=b; v++) {
				values.add(v);
			}
		}
		return values;
	}

	 Set<int> toSet() {
		Set<int> s = new HashSet<int>();
		for (Interval I in intervals) {
			int a = I.a;
			int b = I.b;
			for (int v=a; v<=b; v++) {
				s.add(v);
			}
		}
		return s;
	}

	/** Get the ith element of ordered set.  Used only by RandomPhrase so
	 *  don't bother to implement if you're not doing that for a new
	 *  ANTLR code gen target.
	 */
	 int get(int i) {
		int n = intervals.size();
		int index = 0;
		for (int j = 0; j < n; j++) {
			Interval I = intervals.get(j);
			int a = I.a;
			int b = I.b;
			for (int v=a; v<=b; v++) {
				if ( index==i ) {
					return v;
				}
				index++;
			}
		}
		return -1;
	}

	 List<int> toArray() {
		return toIntegerList().toArray();
	}

	@override
	 void remove(int el) {
        if ( readonly ) throw new StateError("can't alter readonly IntervalSet");
        int n = intervals.length;
        for (int i = 0; i < n; i++) {
            Interval I = intervals[i];
            int a = I.a;
            int b = I.b;
            if ( el<a ) {
                break; // list is sorted and el is before this interval; not here
            }
            // if whole interval x..x, rm
            if ( el==a && el==b ) {
                intervals.remove(i);
                break;
            }
            // if on left edge x..b, adjust left
            if ( el==a ) {
                I.a++;
                break;
            }
            // if on right edge a..x, adjust right
            if ( el==b ) {
                I.b--;
                break;
            }
            // if in middle a..x..b, split interval
            if ( el>a && el<b ) { // found in this interval
                int oldb = I.b;
                I.b = el-1;      // [a..x-1]
                add(el+1, oldb); // add [x+1..b]
            }
        }
    }

     bool isReadonly() {
        return readonly;
    }

     void setReadonly(bool readonly) {
        if ( this.readonly && !readonly ) throw new StateError("can't alter readonly IntervalSet");
        this.readonly = readonly;
    }
}