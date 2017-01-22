import '../vocabulary.dart';
import '../vocabulary_impl.dart';
import 'lexer.dart';
import 'serializer.dart';
import 'state.dart';

/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
class DFA {
  bool _precedenceDfa;

  /** A set of all DFA states. Use {@link Map} so we can get old state back
	 *  ({@link Set} only allows you to see if it's there).
     */

  final Map<DFAState, DFAState> states = {};

  DFAState s0;

  final int decision;

  /** From which ATN state did we create this DFA? */

  final DecisionState atnStartState;

  /**
	 * {@code true} if this DFA is for a precedence decision; otherwise,
	 * {@code false}. This is the backing field for {@link #isPrecedenceDfa}.
	 */

  bool get precedenceDfa => _precedenceDfa;

  DFA(this.atnStartState, [this.decision = 0]) {
    bool precedenceDfa = false;

    if (atnStartState is StarLoopEntryState) {
      if (atnStartState.isPrecedenceDecision) {
        precedenceDfa = true;
        var precedenceState = new DFAState(null, new ATNConfigSet());
        precedenceState.edges = [];
        precedenceState.isAcceptState = false;
        precedenceState.requiresFullContext = false;
        this.s0 = precedenceState;
      }
    }

    _precedenceDfa = precedenceDfa;
  }

  /**
	 * Gets whether this DFA is a precedence DFA. Precedence DFAs use a special
	 * start state {@link #s0} which is not stored in {@link #states}. The
	 * {@link DFAState#edges} array for this start state contains outgoing edges
	 * supplying individual start states corresponding to specific precedence
	 * values.
	 *
	 * @return {@code true} if this is a precedence DFA; otherwise,
	 * {@code false}.
	 * @see Parser#getPrecedence()
	 */
  bool isPrecedenceDfa() => precedenceDfa;

  /**
	 * Get the start state for a specific precedence value.
	 *
	 * @param precedence The current precedence.
	 * @return The start state corresponding to the specified precedence, or
	 * {@code null} if no start state exists for the specified precedence.
	 *
	 * @throws StateError if this is not a precedence DFA.
	 * @see #isPrecedenceDfa()
	 */
  //@SuppressWarnings("null")
  DFAState getPrecedenceStartState(int precedence) {
    if (!isPrecedenceDfa()) {
      throw new StateError(
          "Only precedence DFAs may contain a precedence start state.");
    }

    // s0.edges is never null for a precedence DFA
    if (precedence < 0 || precedence >= s0.edges.length) {
      return null;
    }

    return s0.edges[precedence];
  }

  /**
	 * Set the start state for a specific precedence value.
	 *
	 * @param precedence The current precedence.
	 * @param startState The start state corresponding to the specified
	 * precedence.
	 *
	 * @throws StateError if this is not a precedence DFA.
	 * @see #isPrecedenceDfa()
	 */
  // @SuppressWarnings({"SynchronizeOnNonFinalField", "null"})
  void setPrecedenceStartState(int precedence, DFAState startState) {
    if (!isPrecedenceDfa()) {
      throw new StateError(
          "Only precedence DFAs may contain a precedence start state.");
    }

    if (precedence < 0) {
      return;
    }

    // synchronization on s0 here is ok. when the DFA is turned into a
    // precedence DFA, s0 will be initialized once and not updated again
    synchronized(DFAState s0) {
      // s0.edges is never null for a precedence DFA
      if (precedence >= s0.edges.length) {
        s0.edges = Arrays.copyOf(s0.edges, precedence + 1);
      }

      s0.edges[precedence] = startState;
    }

    synchronized(s0);
  }

  /**
	 * Sets whether this is a precedence DFA.
	 *
	 * @param precedenceDfa {@code true} if this is a precedence DFA; otherwise,
	 * {@code false}
	 *
	 * @throws UnsupportedOperationException if {@code precedenceDfa} does not
	 * match the value of {@link #isPrecedenceDfa} for the current DFA.
	 *
	 * @deprecated This method no longer performs any action.
	 */
  @deprecated
  void setPrecedenceDfa(bool precedenceDfa) {
    if (precedenceDfa != isPrecedenceDfa()) {
      throw new UnsupportedError(
          "The precedenceDfa field cannot change after a DFA is constructed.");
    }
  }

  /**
	 * Return a list of all states in this DFA, ordered by state number.
	 */

  List<DFAState> getStates() {
    List<DFAState> result = new List.from(states.keys);

    result.sort((DFAState o1, DFAState o2) {
      return o1.stateNumber - o2.stateNumber;
    });

    return result;
  }

  @override
  String toString() => toStringFromVocabulary(VocabularyImpl.EMPTY_VOCABULARY);

  /**
	 * @deprecated Use {@link #toString(Vocabulary)} instead.
	 */
  @deprecated
  String toStringFromTokenNames(List<String> tokenNames) {
    if (s0 == null) return "";
    DFASerializer serializer =
        new DFASerializer.fromTokenNames(this, tokenNames);
    return serializer.toString();
  }

  String toStringFromVocabulary(Vocabulary vocabulary) {
    if (s0 == null) {
      return "";
    }

    DFASerializer serializer = new DFASerializer(this, vocabulary);
    return serializer.toString();
  }

  String toLexerString() {
    if (s0 == null) return "";
    DFASerializer serializer = new LexerDFASerializer(this);
    return serializer.toString();
  }
}
