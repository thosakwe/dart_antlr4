import 'parser_rule_context.dart';

class TraceListener implements ParseTreeListener {
  @override
  void enterEveryRule(ParserRuleContext ctx) {
    print(
        "enter   ${getRuleNames()[ctx.getRuleIndex()]}, LT(1)=_input.LT(1).getText()");
  }

  @override
  void visitTerminal(TerminalNode node) {
    print(
        "consume ${node.getSymbol()} rule ${getRuleNames()[_ctx.getRuleIndex()]}");
  }

  @override
  void visitErrorNode(ErrorNode node) {}

  @override
  void exitEveryRule(ParserRuleContext ctx) {
    print(
        "exit    ${getRuleNames()[ctx.getRuleIndex()]}, LT(1)=${_input.LT(1).getText()}");
  }
}
