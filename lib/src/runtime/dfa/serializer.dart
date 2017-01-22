/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../vocabulary.dart';
import '../vocabulary_impl.dart';
import 'dfa_class.dart';
import 'state.dart';

/** A DFA walker that knows how to dump them to serialized strings. */
 class DFASerializer {

	 final DFA dfa;

	 final Vocabulary vocabulary;

	/**
	 * @deprecated Use {@link #DFASerializer(DFA, Vocabulary)} instead.
	 */
	@deprecated
   factory DFASerializer.fromTokenNames(DFA dfa, List<String> tokenNames) =>
   new DFASerializer(dfa, VocabularyImpl.fromTokenNames(tokenNames));


   DFASerializer(this.dfa, this.vocabulary);

	@override
	 String toString() {
		if ( dfa.s0==null ) return null;
		var buf = new StringBuffer();
		List<DFAState> states = dfa.getStates();
		for (DFAState s in states) {
			int n = 0;
			if ( s.edges!=null ) n = s.edges.length;
			for (int i=0; i<n; i++) {
				DFAState t = s.edges[i];
				if ( t!=null && t.stateNumber != Integer.MAX_VALUE ) {
					buf.write(getStateString(s));
					String label = getEdgeLabel(i);
					buf..write("-")..write(label)..write("->")..write(getStateString(t))..write('\n');
				}
			}
		}

		String output = buf.toString();
		if ( output.length==0 ) return null;
		//return Utils.sortLinesInString(output);
		return output;
	}

	 String getEdgeLabel(int i) {
		return vocabulary.getDisplayName(i - 1);
	}


	 String getStateString(DFAState s) {
		int n = s.stateNumber;
		final String baseStateStr = (s.isAcceptState ? ":" : "") + "s$n" + (s.requiresFullContext ? "^" : "");
		if ( s.isAcceptState ) {
            if ( s.predicates!=null ) {
                return baseStateStr + "=>" + Arrays.toString(s.predicates);
            }
            else {
                return baseStateStr + "=>${s.prediction}";
            }
		}
		else {
			return baseStateStr;
		}
	}
}