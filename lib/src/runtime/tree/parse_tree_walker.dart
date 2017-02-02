/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../parser_rule_context.dart';
import 'error_node.dart';
import 'rule_node.dart';
import 'terminal_node.dart';
import 'parse_tree.dart';
import 'parse_tree_listener.dart';

class ParseTreeWalker {
  static final ParseTreeWalker DEFAULT = new ParseTreeWalker();

  void walk(ParseTreeListener listener, ParseTree t) {
    if (t is ErrorNode) {
      listener.visitErrorNode(t);
      return;
    } else if (t is TerminalNode) {
      listener.visitTerminal(t);
      return;
    }
    RuleNode r = t;
    enterRule(listener, r);
    int n = r.childCount;
    for (int i = 0; i < n; i++) {
      walk(listener, r.getChild(i));
    }
    exitRule(listener, r);
  }

  /**
	 * The discovery of a rule node, involves sending two events: the generic
	 * {@link ParseTreeListener#enterEveryRule} and a
	 * {@link RuleContext}-specific event. First we trigger the generic and then
	 * the rule specific. We to them in reverse order upon finishing the node.
	 */
  void enterRule(ParseTreeListener listener, RuleNode r) {
    var ctx = r.ruleContext as ParserRuleContext;
    listener.enterEveryRule(ctx);
    ctx.enterRule(listener);
  }

  void exitRule(ParseTreeListener listener, RuleNode r) {
    var ctx = r.ruleContext as ParserRuleContext;
    ctx.exitRule(listener);
    listener.exitEveryRule(ctx);
  }
}
