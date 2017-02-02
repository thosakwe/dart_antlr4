/*
 * [The "BSD license"]
 *  Copyright (c) 2012 Terence Parr
 *  Copyright (c) 2012 Sam Harwell
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 *  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 *  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 *  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 *  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
import 'misc/interval.dart';
import 'tree/tree.dart';
import 'parser.dart' show Parser;
import 'parser_rule_context.dart' show ParserRuleContext;
import 'recognizer.dart';

/** A rule context is a record of a single rule invocation.
 *
 *  We form a stack of these context objects using the parent
 *  pointer. A parent pointer of null indicates that the current
 *  context is the bottom of the stack. The ParserRuleContext subclass
 *  as a children list so that we can turn this data structure into a
 *  tree.
 *
 *  The root node always has a null pointer and invokingState of -1.
 *
 *  Upon entry to parsing, the first invoked rule function creates a
 *  context object (asubclass specialized for that rule such as
 *  SContext) and makes it the root of a parse tree, recorded by field
 *  Parser._ctx.
 *
 *  public final SContext s() throws RecognitionException {
 *      SContext _localctx = new SContext(_ctx, getState()); <-- create new node
 *      enterRule(_localctx, 0, RULE_s);                     <-- push it
 *      ...
 *      exitRule();                                          <-- pop back to _localctx
 *      return _localctx;
 *  }
 *
 *  A subsequent rule invocation of r from the start rule s pushes a
 *  new context object for r whose parent points at s and use invoking
 *  state is the state with r emanating as edge label.
 *
 *  The invokingState fields from a context object to the root
 *  together form a stack of rule indication states where the root
 *  (bottom of the stack) has a -1 sentinel value. If we invoke start
 *  symbol s then call r1, which calls r2, the  would look like
 *  this:
 *
 *     SContext[-1]   <- root node (bottom of the stack)
 *     R1Context[p]   <- p in rule s called r1
 *     R2Context[q]   <- q in rule r1 called r2
 *
 *  So the top of the stack, _ctx, represents a call to the current
 *  rule and it holds the return address from another rule that invoke
 *  to this rule. To invoke a rule, we must always have a current context.
 *
 *  The parent contexts are useful for computing lookahead sets and
 *  getting error information.
 *
 *  These objects are used during parsing and prediction.
 *  For the special case of parsers, we use the subclass
 *  ParserRuleContext.
 *
 *  @see ParserRuleContext
 */
class RuleContext implements RuleNode {
  static final ParserRuleContext EMPTY = new ParserRuleContext();

  /** What context invoked this rule? */
  @override
  RuleContext parent;

  /** What state invoked the rule associated with this context?
	 *  The "return address" is the followState of invokingState
	 *  If parent is null, this should be -1 this context object represents
	 *  the start rule.
	 */
  int invokingState = -1;

  RuleContext([RuleContext parent, int invokingState]) {
    this.parent = parent;
    //if ( parent!=null ) System.out.println("invoke "+stateNumber+" from "+parent);
    this.invokingState = invokingState;
  }

  int depth() {
    int n = 0;
    RuleContext p = this;
    while (p != null) {
      p = p.parent;
      n++;
    }
    return n;
  }

  /** A context is empty if there is no invoking state; meaning nobody called
	 *  current context.
	 */
  bool get isEmpty => invokingState == -1;

  // satisfy the ParseTree / SyntaxTree interface

  @override
  Interval get sourceInterval => Interval.INVALID;

  @override
  RuleContext get ruleContext => this;

  @override
  RuleContext get payload => this;

  /** Return the combined text of all child nodes. This method only considers
	 *  tokens which have been added to the parse tree.
	 *  <p>
	 *  Since tokens on hidden channels (e.g. whitespace or comments) are not
	 *  added to the parse trees, they will not appear in the output of this
	 *  method.
	 */
  @override
  String get text {
    if (childCount == 0) {
      return "";
    }

    var builder = new StringBuffer();
    for (int i = 0; i < childCount; i++) {
      builder.write(getChild(i).text);
    }

    return builder.toString();
  }

  int get ruleIndex => -1;

  /** For rule associated with this parse tree internal node, return
	 *  the outer alternative number used to match the input. Default
	 *  implementation does not compute nor store this alt num. Create
	 *  a subclass of ParserRuleContext with backing field and set
	 *  option contextSuperClass.
	 *  to set it.
	 *
	 *  @since 4.5.3
	 */
  int get altNumber => ATN.INVALID_ALT_NUMBER;

  /** Set the outer alternative number for this context node. Default
	 *  implementation does nothing to avoid backing field overhead for
	 *  trees that don't need it.  Create
     *  a subclass of ParserRuleContext with backing field and set
     *  option contextSuperClass.
	 *
	 *  @since 4.5.3
	 */
  void set altNumber(int altNumber) {}

  @override
  ParseTree getChild(int i) => null;

  @override
  int get childCount => 0;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitChildren(this);

  @override
  String toStringTree([x]) {
    if (x is Parser)
      return Trees.toStringTree(this, x);
    else if (x is List<String>) return Trees.toStringTree(this, x);
    return toStringTree(null);
  }

  // @override
  String convertToString([x, y]) {
    if (x is Recognizer) {
      if (y is RuleContext) {
        var recog = x, stop = y;
        List<String> ruleNames = recog != null ? recog.ruleNames : null;
        List<String> ruleNamesList = ruleNames != null ? ruleNames : null;
        return convertToString(ruleNamesList, stop);
      } else
        return convertToString(x, ParserRuleContext.EMPTY);
    } else if (x is List<String> || x == null) {
      var ruleNames = x;
      RuleContext stop = y;
      var buf = new StringBuffer();
      RuleContext p = this;
      buf.write("[");
      while (p != null && p != stop) {
        if (ruleNames == null) {
          if (!p.isEmpty) {
            buf.write(p.invokingState);
          }
        } else {
          int ruleIndex = p.ruleIndex;
          String ruleName = ruleIndex >= 0 && ruleIndex < ruleNames.length
              ? ruleNames[ruleIndex]
              : ruleIndex.toString();
          buf.write(ruleName);
        }

        if (p.parent != null && (ruleNames != null || !p.parent.isEmpty)) {
          buf.write(" ");
        }

        p = p.parent;
      }

      buf.write("]");
      return buf.toString();
    } else {
      return convertToString(null, null);
    }
  }
}
