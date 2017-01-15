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
import 'parser.dart' show Parser;
import 'recognition_exception.dart';
import 'rule_context.dart';
import 'token.dart';

/** A rule invocation record for parsing.
 *
 *  Contains all of the information about the current rule not stored in the
 *  RuleContext. It handles parse tree children list, Any ATN state
 *  tracing, and the default values available for rule invocations:
 *  start, stop, rule index, current alt number.
 *
 *  Subclasses made for each rule and grammar track the parameters,
 *  return values, locals, and labels specific to that rule. These
 *  are the objects that are returned from rules.
 *
 *  Note text is not an actual field of a rule return value; it is computed
 *  from start and stop using the input stream's toString() method.  I
 *  could add a ctor to this so that we can pass in and store the input
 *  stream, but I'm not sure we want to do that.  It would seem to be undefined
 *  to get the .text property anyway if the rule matches tokens from multiple
 *  input streams.
 *
 *  I do not use getters for fields of objects that are used simply to
 *  group values such as this aggregate.  The getters/setters are there to
 *  satisfy the superclass interface.
 */
class ParserRuleContext extends RuleContext {
  /** If we are debugging or building a parse tree for a visitor,
	 *  we need to track all of the tokens and rule invocations associated
	 *  with this rule's context. This is empty for parsing w/o tree constr.
	 *  operation because we don't the need to track the details about
	 *  how we parse this rule.
	 */
  List<ParseTree> children;

  /** For debugging/tracing purposes, we want to track all of the nodes in
	 *  the ATN traversed by the parser for a particular rule.
	 *  This list indicates the sequence of ATN nodes used to match
	 *  the elements of the children list. This list does not include
	 *  ATN nodes and other rules used to match rule invocations. It
	 *  traces the rule invocation node itself but nothing inside that
	 *  other rule's ATN submachine.
	 *
	 *  There is NOT a one-to-one correspondence between the children and
	 *  states list. There are typically many nodes in the ATN traversed
	 *  for each element in the children list. For example, for a rule
	 *  invocation there is the invoking state and the following state.
	 *
	 *  The parser setState() method updates field s and adds it to this list
	 *  if we are debugging/tracing.
     *
     *  This does not trace states visited during prediction.
	 */
//	 List<Integer> states;

  /**
	 * Get the initial token in this context.
	 * Note that the range from start to stop is inclusive, so for rules that do not consume anything
	 * (for example, zero length or error productions) this token may exceed stop.
	 */
  Token start;

  /**
	 * Get the final token in this context.
	 * Note that the range from start to stop is inclusive, so for rules that do not consume anything
	 * (for example, zero length or error productions) this token may precede start.
	 */
  Token stop;

  /**
	 * The exception that forced this rule to return. If the rule successfully
	 * completed, this is {@code null}.
	 */
  RecognitionException exception;

  /** COPY a ctx (I'm deliberately not using copy constructor) to avoid
	 *  confusion with creating node with parent. Does not copy children.
	 */
  void copyFrom(ParserRuleContext ctx) {
    this.parent = ctx.parent;
    this.invokingState = ctx.invokingState;

    this.start = ctx.start;
    this.stop = ctx.stop;
  }

  ParserRuleContext([ParserRuleContext parent, int invokingStateNumber])
      : super(parent, invokingStateNumber);

  // Double dispatch methods for listeners

  void enterRule(ParseTreeListener listener) {}
  void exitRule(ParseTreeListener listener) {}

  /** Does not set parent link; other add methods do that */
  TerminalNode addChild(TerminalNode t) {
    if (children == null) children = <ParseTree>[];
    children.add(t);
    return t;
  }

  RuleContext addChild(RuleContext ruleInvocation) {
    if (children == null) children = <ParseTree>[];
    children.add(ruleInvocation);
    return ruleInvocation;
  }

  /** Used by enterOuterAlt to toss out a RuleContext previously added as
	 *  we entered a rule. If we have # label, we will need to remove
	 *  generic ruleContext object.
 	 */
  void removeLastChild() {
    children?.removeLast();
  }

//	 void trace(int s) {
//		if ( states==null ) states = new ArrayList<Integer>();
//		states.add(s);
//	}

  TerminalNode addChild(Token matchedToken) {
    TerminalNodeImpl t = new TerminalNodeImpl(matchedToken);
    addChild(t);
    t.parent = this;
    return t;
  }

  ErrorNode addErrorNode(Token badToken) {
    ErrorNodeImpl t = new ErrorNodeImpl(badToken);
    addChild(t);
    t.parent = this;
    return t;
  }

  @override
  /** override to make type more specific */
  ParserRuleContext get parent => super.parent as ParserRuleContext;

  @override
  ParseTree getChild(int i) {
    return children != null && i >= 0 && i < children.length
        ? children[i]
        : null;
  }

  // TODO: (thosakwe) Probably create an isType<T>
  ParseTree getChild(Type ctxType, int i) {
    if (children == null || i < 0 || i >= children.length) {
      return null;
    }

    int j = -1; // what element have we found with ctxType?
    for (ParseTree o in children) {
      // TODO: (thosakwe) if (ctxType.isInstance(o))
      if (ctxType.runtimeType == ctxType) {
        j++;
        if (j == i) {
          // TODO: (thosakwe) Make this cast
          return ctxType.cast(o);
        }
      }
    }
    return null;
  }

  TerminalNode getToken(int ttype, int i) {
    if (children == null || i < 0 || i >= children.length) {
      return null;
    }

    int j = -1; // what token with ttype have we found?
    for (ParseTree o in children) {
      if (o is TerminalNode) {
        TerminalNode tnode = o;
        Token symbol = tnode.symbol;
        if (symbol.type == ttype) {
          j++;
          if (j == i) {
            return tnode;
          }
        }
      }
    }

    return null;
  }

  List<TerminalNode> getTokens(int ttype) {
    if (children == null) {
      return [];
    }

    List<TerminalNode> tokens = null;
    for (ParseTree o in children) {
      if (o is TerminalNode) {
        TerminalNode tnode = o;
        Token symbol = tnode.symbol;
        if (symbol.type == ttype) {
          if (tokens == null) {
            tokens = [];
          }
          tokens.add(tnode);
        }
      }
    }

    if (tokens == null) {
      return [];
    }

    return tokens;
  }

  ParserRuleContext getRuleContext(Type ctxType, int i) {
    return getChild(ctxType, i);
  }

  List<ParserRuleContext> getRuleContexts(Type ctxType) {
    if (children == null) {
      return [];
    }

    List<ParserRuleContext> contexts = null;
    for (ParseTree o in children) {
      if (ctxType.isInstance(o)) {
        if (contexts == null) {
          contexts = [];
        }

        contexts.add(ctxType.cast(o));
      }
    }

    if (contexts == null) {
      return [];
    }

    return contexts;
  }

  @override
  int get childCount => children != null ? children.length : 0;

  @override
  Interval get sourceInterval {
    if (start == null) {
      return Interval.INVALID;
    }
    if (stop == null || stop.tokenIndex < start.tokenIndex) {
      return Interval.of(start.tokenIndex, start.tokenIndex - 1); // empty
    }
    return Interval.of(start.tokenIndex, stop.tokenIndex);
  }

  /** Used for rule context info debugging during parse-time, not so much for ATN debugging */
  String toInfoString(Parser recognizer) {
    List<String> rules = recognizer.getRuleInvocationStack(this);
    rules = rules.reversed;
    return "ParserRuleContext$rules{start=$start, stop=$stop}";
  }
}
