import 'tree/tree.dart';
import 'parser_rule_context.dart';

class TrimToSizeListener implements ParseTreeListener {
  static final TrimToSizeListener INSTANCE = new TrimToSizeListener();

  @override
  void enterEveryRule(ParserRuleContext ctx) {}

  @override
  void visitTerminal(TerminalNode node) {}

  @override
  void visitErrorNode(ErrorNode node) {}

  @override
  void exitEveryRule(ParserRuleContext ctx) {
    /*if (ctx.children is List) {
      //((ArrayList<?>)ctx.children).trimToSize();
    }*/
  }
}
