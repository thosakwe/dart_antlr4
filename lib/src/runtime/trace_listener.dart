import 'tree/tree.dart';
import 'parser_rule_context.dart';

class TraceListener implements ParseTreeListener {
  @override
  void enterEveryRule(ParserRuleContext ctx) {
    print("enter   ${ruleNames[ctx.ruleIndex]}, LT(1)=_input.LT(1).getText()");
  }

  @override
  void visitTerminal(TerminalNode node) {
    print("consume ${node.getSymbol()} rule ${ruleNames[_ctx.ruleIndex]}");
  }

  @override
  void visitErrorNode(ErrorNode node) {}

  @override
  void exitEveryRule(ParserRuleContext ctx) {
    print(
        "exit    ${ruleNames[ctx.ruleIndex]}, LT(1)=${_input.LT(1).getText()}");
  }
}
