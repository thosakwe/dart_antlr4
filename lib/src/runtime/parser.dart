import 'dfa/dfa_class.dart';
import 'default_error_strategy.dart';
import 'error_listener.dart';
import 'error_strategy.dart';
import 'int_stream.dart';
import 'parser_rule_context.dart';
import 'recognition_exception.dart';
import 'recognizer.dart';
import 'rule_context.dart';
import 'token.dart';
import 'token_factory.dart';
import 'token_stream.dart';
import 'token_source.dart';
import 'trace_listener.dart';
import 'trim_to_size_listener.dart';

/** This is all the parsing support code essentially; most of it is error recovery stuff. */
abstract class Parser extends Recognizer<Token, ParserATNSimulator> {
  /**
   * This field maps from the serialized ATN string to the deserialized {@link ATN} with
   * bypass alternatives.
   *
   * @see ATNDeserializationOptions#isGenerateRuleBypassTransitions()
   */
  static final Map<String, ATN> _bypassAltsAtnCache = {};

  /**
   * The error handling strategy for the parser. The default value is a new
   * instance of {@link DefaultErrorStrategy}.
   *
   * @see #getErrorHandler
   * @see #setErrorHandler
   */

  ANTLRErrorStrategy _errHandler = new DefaultErrorStrategy();

  /**
   * The input stream.
   *
   * @see #getInputStream
   * @see #setInputStream
   */
  TokenStream _input;

  final IntegerStack _precedenceStack = new IntegerStack()..push(0);

  ParserRuleContext _ctx;

  /**
   * The {@link ParserRuleContext} object for the currently executing rule.
   * This is always non-null during the parsing process.
   */
  ParserRuleContext get ctx => _ctx;

  /**
   * Specifies whether or not the parser should construct a parse tree during
   * the parsing process. The default value is {@code true}.
   *
   * @see #getBuildParseTree
   * @see #setBuildParseTree
   */
  bool _buildParseTrees = true;

  /**
   * When {@link #setTrace}{@code (true)} is called, a reference to the
   * {@link TraceListener} is stored here so it can be easily removed in a
   * later call to {@link #setTrace}{@code (false)}. The listener itself is
   * implemented as a parser listener so this field is not directly used by
   * other parser methods.
   */
  TraceListener _tracer;

  /**
   * The list of {@link ParseTreeListener} listeners registered to receive
   * events during the parse.
   *
   * @see #addParseListener
   */
  List<ParseTreeListener> _parseListeners;

  /**
   * The number of syntax errors reported during parsing. This value is
   * incremented each time {@link #notifyErrorListeners} is called.
   */
  int _syntaxErrors;

  /** Indicates parser has match()ed EOF token. See {@link #exitRule()}. */
  bool matchedEOF;

  Parser(TokenStream input) {
    inputStream = input;
  }

  /** reset the parser's state */
  void reset() {
    inputStream?.seek(0);
    _errHandler.reset(this);
    _ctx = null;
    _syntaxErrors = 0;
    matchedEOF = false;
    this.trace = false;
    _precedenceStack.clear();
    _precedenceStack.push(0);
    ATNSimulator interpreter = this.interpreter;
    if (interpreter != null) {
      interpreter.reset();
    }
  }

  /**
   * Match current input symbol against {@code ttype}. If the symbol type
   * matches, {@link ANTLRErrorStrategy#reportMatch} and {@link #consume} are
   * called to complete the match process.
   *
   * <p>If the symbol type does not match,
   * {@link ANTLRErrorStrategy#recoverInline} is called on the current error
   * strategy to attempt recovery. If {@link #getBuildParseTree} is
   * {@code true} and the token index of the symbol returned by
   * {@link ANTLRErrorStrategy#recoverInline} is -1, the symbol is added to
   * the parse tree by calling {@link ParserRuleContext#addErrorNode}.</p>
   *
   * @param ttype the token type to match
   * @return the matched symbol
   * @throws RecognitionException if the current input symbol did not match
   * {@code ttype} and the error strategy could not recover from the
   * mismatched symbol
   */
  Token match(int ttype) {
    Token t = this.currentToken;
    if (t.type == ttype) {
      if (ttype == Token.EOF) {
        matchedEOF = true;
      }
      _errHandler.reportMatch(this);
      consume();
    } else {
      t = _errHandler.recoverInline(this);
      if (_buildParseTrees && t.tokenIndex == -1) {
        // we must have conjured up a new token during single token insertion
        // if it's not the current symbol
        _ctx.addErrorNode(t);
      }
    }
    return t;
  }

  /**
   * Match current input symbol as a wildcard. If the symbol type matches
   * (i.e. has a value greater than 0), {@link ANTLRErrorStrategy#reportMatch}
   * and {@link #consume} are called to complete the match process.
   *
   * <p>If the symbol type does not match,
   * {@link ANTLRErrorStrategy#recoverInline} is called on the current error
   * strategy to attempt recovery. If {@link #getBuildParseTree} is
   * {@code true} and the token index of the symbol returned by
   * {@link ANTLRErrorStrategy#recoverInline} is -1, the symbol is added to
   * the parse tree by calling {@link ParserRuleContext#addErrorNode}.</p>
   *
   * @return the matched symbol
   * @throws RecognitionException if the current input symbol did not match
   * a wildcard and the error strategy could not recover from the mismatched
   * symbol
   */
  Token matchWildcard() {
    Token t = this.currentToken;
    if (t.type > 0) {
      _errHandler.reportMatch(this);
      consume();
    } else {
      t = _errHandler.recoverInline(this);
      if (_buildParseTrees && t.tokenIndex == -1) {
        // we must have conjured up a new token during single token insertion
        // if it's not the current symbol
        _ctx.addErrorNode(t);
      }
    }

    return t;
  }

  /**
   * Track the {@link ParserRuleContext} objects during the parse and hook
   * them up using the {@link ParserRuleContext#children} list so that it
   * forms a parse tree. The {@link ParserRuleContext} returned from the start
   * rule represents the root of the parse tree.
   *
   * <p>Note that if we are not building parse trees, rule contexts only point
   * upwards. When a rule exits, it returns the context but that gets garbage
   * collected if nobody holds a reference. It points upwards but nobody
   * points at it.</p>
   *
   * <p>When we build parse trees, we are adding all of these contexts to
   * {@link ParserRuleContext#children} list. Contexts are then not candidates
   * for garbage collection.</p>
   */
  void set buildParseTree(bool buildParseTrees) {
    this._buildParseTrees = buildParseTrees;
  }

  /**
   * Gets whether or not a complete parse tree will be constructed while
   * parsing. This property is {@code true} for a newly constructed parser.
   *
   * @return {@code true} if a complete parse tree will be constructed while
   * parsing, otherwise {@code false}
   */
  bool get buildParseTree => _buildParseTrees;

  /**
   * Trim the internal lists of the parse tree during parsing to conserve memory.
   * This property is set to {@code false} by default for a newly constructed parser.
   *
   * @param trimParseTrees {@code true} to trim the capacity of the {@link ParserRuleContext#children}
   * list to its size after a rule is parsed.
   */
  void set trimParseTree(bool trimParseTrees) {
    if (trimParseTrees) {
      if (this.trimParseTree) return;
      addParseListener(TrimToSizeListener.INSTANCE);
    } else {
      removeParseListener(TrimToSizeListener.INSTANCE);
    }
  }

  /**
   * @return {@code true} if the {@link ParserRuleContext#children} list is trimmed
   * using the default {@link Parser.TrimToSizeListener} during the parse process.
   */
  bool get trimParseTree =>
      parseListeners.contains(TrimToSizeListener.INSTANCE);

  List<ParseTreeListener> get parseListeners {
    List<ParseTreeListener> listeners = _parseListeners;
    if (listeners == null) {
      return <ParseTreeListener>[];
    }

    return listeners;
  }

  /**
   * Registers {@code listener} to receive events during the parsing process.
   *
   * <p>To support output-preserving grammar transformations (including but not
   * limited to left-recursion removal, automated left-factoring, and
   * optimized code generation), calls to listener methods during the parse
   * may differ substantially from calls made by
   * {@link ParseTreeWalker#DEFAULT} used after the parse is complete. In
   * particular, rule entry and exit events may occur in a different order
   * during the parse than after the parser. In addition, calls to certain
   * rule entry methods may be omitted.</p>
   *
   * <p>With the following specific exceptions, calls to listener events are
   * <em>deterministic</em>, i.e. for identical input the calls to listener
   * methods will be the same.</p>
   *
   * <ul>
   * <li>Alterations to the grammar used to generate code may change the
   * behavior of the listener calls.</li>
   * <li>Alterations to the command line options passed to ANTLR 4 when
   * generating the parser may change the behavior of the listener calls.</li>
   * <li>Changing the version of the ANTLR Tool used to generate the parser
   * may change the behavior of the listener calls.</li>
   * </ul>
   *
   * @param listener the listener to add
   *
   * @throws NullPointerException if {@code} listener is {@code null}
   */
  void addParseListener(ParseTreeListener listener) {
    if (listener == null) {
      throw new ArgumentError.notNull("listener");
    }

    if (_parseListeners == null) {
      _parseListeners = <ParseTreeListener>[];
    }

    this._parseListeners.add(listener);
  }

  /**
   * Remove {@code listener} from the list of parse listeners.
   *
   * <p>If {@code listener} is {@code null} or has not been added as a parse
   * listener, this method does nothing.</p>
   *
   * @see #addParseListener
   *
   * @param listener the listener to remove
   */
  void removeParseListener(ParseTreeListener listener) {
    if (_parseListeners != null) {
      if (_parseListeners.remove(listener)) {
        if (_parseListeners.isEmpty) {
          _parseListeners = null;
        }
      }
    }
  }

  /**
   * Remove all parse listeners.
   *
   * @see #addParseListener
   */
  void removeParseListeners() {
    _parseListeners = null;
  }

  /**
   * Notify any parse listeners of an enter rule event.
   *
   * @see #addParseListener
   */
  void triggerEnterRuleEvent() {
    for (ParseTreeListener listener in _parseListeners) {
      listener.enterEveryRule(_ctx);
      _ctx.enterRule(listener);
    }
  }

  /**
   * Notify any parse listeners of an exit rule event.
   *
   * @see #addParseListener
   */
  void triggerExitRuleEvent() {
    // reverse order walk of listeners
    for (int i = _parseListeners.length - 1; i >= 0; i--) {
      ParseTreeListener listener = _parseListeners[i];
      _ctx.exitRule(listener);
      listener.exitEveryRule(_ctx);
    }
  }

  /**
   * Gets the number of syntax errors reported during parsing. This value is
   * incremented each time {@link #notifyErrorListeners} is called.
   *
   * @see #notifyErrorListeners
   */
  int get numberOfSyntaxErrors => _syntaxErrors;

  @override
  TokenFactory get tokenFactory => _input.tokenSource.tokenFactory;

  /** Tell our token source and error strategy about a new way to create tokens. */
  @override
  void set tokenFactory(TokenFactory _factory) {
    _input.tokenSource.tokenFactory = _factory;
  }

  /**
   * The ATN with bypass alternatives is expensive to create so we create it
   * lazily.
   *
   * @throws UnsupportedOperationException if the current parser does not
   * implement the {@link #getSerializedATN()} method.
   */

  ATN get atnWithBypassAlts {
    String serializedAtn = this.serializedATN;
    if (serializedAtn == null) {
      throw new StateError(
          "The current parser does not support an ATN with bypass alternatives.");
    }

    synchronized(bypassAltsAtnCache) {
      ATN result = bypassAltsAtnCache.get(serializedAtn);
      if (result == null) {
        ATNDeserializationOptions deserializationOptions =
            new ATNDeserializationOptions();
        deserializationOptions.setGenerateRuleBypassTransitions(true);
        result = new ATNDeserializer(deserializationOptions)
            .deserialize(serializedAtn.toCharArray());
        bypassAltsAtnCache.put(serializedAtn, result);
      }

      return result;
    }

    return synchronized(_bypassAltsAtnCache);
  }

  /**
   * The preferred method of getting a tree pattern. For example, here's a
   * sample use:
   *
   * <pre>
   * ParseTree t = parser.expr();
   * ParseTreePattern p = parser.compileParseTreePattern("&lt;ID&gt;+0", MyParser.RULE_expr);
   * ParseTreeMatch m = p.match(t);
   * String id = m.get("ID");
   * </pre>
   */
  ParseTreePattern compileParseTreePattern(
      String pattern, int patternRuleIndex) {
    if (tokenStream != null) {
      TokenSource tokenSource = tokenStream.tokenSource;
      if (tokenSource is Lexer) {
        Lexer lexer = tokenSource;
        return compileParseTreePattern(pattern, patternRuleIndex, lexer);
      }
    }
    throw new StateError("Parser can't discover a lexer to use");
  }

  /**
   * The same as {@link #compileParseTreePattern(String, int)} but specify a
   * {@link Lexer} rather than trying to deduce it from this parser.
   */
  ParseTreePattern compileParseTreePattern(
      String pattern, int patternRuleIndex, Lexer lexer) {
    ParseTreePatternMatcher m = new ParseTreePatternMatcher(lexer, this);
    return m.compile(pattern, patternRuleIndex);
  }

  ANTLRErrorStrategy get errorHandler => _errHandler;

  void set errorHandler(ANTLRErrorStrategy handler) {
    this._errHandler = handler;
  }

  @override
  TokenStream get inputStream => tokenStream;

  @override
  void set inputStream(IntStream input) {
    tokenStream = input as TokenStream;
  }

  TokenStream get tokenStream => _input;

  /** Set the token stream and reset the parser. */
  void set tokenStream(TokenStream input) {
    this._input = null;
    reset();
    this._input = input;
  }

  /** Match needs to return the current input symbol, which gets put
   *  into the label for the associated token ref; e.g., x=ID.
   */

  Token get currentToken => _input.LT(1);

  void notifyErrorListeners(msg, [offendingToken, e]) {
    void _notifyErrorListeners(
        Token offendingToken, String msg, RecognitionException e) {
      _syntaxErrors++;
      int line = -1;
      int charPositionInLine = -1;
      line = offendingToken.line;
      charPositionInLine = offendingToken.charPositionInLine;

      ANTLRErrorListener listener = getErrorListenerDispatch();
      listener.syntaxError(
          this, offendingToken, line, charPositionInLine, msg, e);
    }

    if (offendingToken == null)
      _notifyErrorListeners(currentToken, msg, null);
    else
      _notifyErrorListeners(offendingToken, msg, e);
  }

  /**
   * Consume and return the {@linkplain #getCurrentToken current symbol}.
   *
   * <p>E.g., given the following input with {@code A} being the current
   * lookahead symbol, this function moves the cursor to {@code B} and returns
   * {@code A}.</p>
   *
   * <pre>
   *  A B
   *  ^
   * </pre>
   *
   * If the parser is not in error recovery mode, the consumed symbol is added
   * to the parse tree using {@link ParserRuleContext#addChild(Token)}, and
   * {@link ParseTreeListener#visitTerminal} is called on any parse listeners.
   * If the parser <em>is</em> in error recovery mode, the consumed symbol is
   * added to the parse tree using
   * {@link ParserRuleContext#addErrorNode(Token)}, and
   * {@link ParseTreeListener#visitErrorNode} is called on any parse
   * listeners.
   */
  Token consume() {
    Token o = this.currentToken;
    if (o.type != Token.EOF) {
      this.inputStream.consume();
    }

    bool hasListener = _parseListeners != null && !_parseListeners.isEmpty;
    if (_buildParseTrees || hasListener) {
      if (_errHandler.inErrorRecoveryMode(this)) {
        ErrorNode node = _ctx.addErrorNode(o);
        if (_parseListeners != null) {
          for (ParseTreeListener listener in _parseListeners) {
            listener.visitErrorNode(node);
          }
        }
      } else {
        TerminalNode node = _ctx.addChild(o);
        if (_parseListeners != null) {
          for (ParseTreeListener listener in _parseListeners) {
            listener.visitTerminal(node);
          }
        }
      }
    }
    return o;
  }

  void addContextToParseTree() {
    ParserRuleContext parent = _ctx.parent;
    // add current context to parent if we have a parent
    parent?.addChild(_ctx);
  }

  /**
   * Always called by generated parsers upon entry to a rule. Access field
   * {@link #_ctx} get the current context.
   */
  void enterRule(ParserRuleContext localctx, int state, int ruleIndex) {
    this.state = state;
    _ctx = localctx;
    _ctx.start = _input.LT(1);
    if (_buildParseTrees) addContextToParseTree();
    if (_parseListeners != null) triggerEnterRuleEvent();
  }

  void exitRule() {
    if (matchedEOF) {
      // if we have matched EOF, it cannot consume past EOF so we use LT(1) here
      _ctx.stop = _input.LT(1); // LT(1) will be end of file
    } else {
      _ctx.stop = _input.LT(-1); // stop node is what we just matched
    }
    // trigger event on _ctx, before it reverts to parent
    if (_parseListeners != null) triggerExitRuleEvent();
    this.state = _ctx.invokingState;
    _ctx = _ctx.parent;
  }

  void enterOuterAlt(ParserRuleContext localctx, int altNum) {
    localctx.altNumber = altNum;
    // if we have new localctx, make sure we replace existing ctx
    // that is previous child of parse tree
    if (_buildParseTrees && _ctx != localctx) {
      ParserRuleContext parent = _ctx.parent;
      if (parent != null) {
        parent.removeLastChild();
        parent.addChild(localctx);
      }
    }
    _ctx = localctx;
  }

  /**
   * Get the precedence level for the top-most precedence rule.
   *
   * @return The precedence level for the top-most precedence rule, or -1 if
   * the parser context is not nested within a precedence rule.
   */
  int get precedence {
    if (_precedenceStack.isEmpty()) {
      return -1;
    }

    return _precedenceStack.peek();
  }

  void enterRecursionRule(ParserRuleContext localctx, int state, int ruleIndex,
      [int precedence = 0]) {
    this.state = state;
    _precedenceStack.push(precedence);
    _ctx = localctx;
    _ctx.start = _input.LT(1);
    if (_parseListeners != null) {
      triggerEnterRuleEvent(); // simulates rule entry for left-recursive rules
    }
  }

  /** Like {@link #enterRule} but for recursive rules.
   *  Make the current context the child of the incoming localctx.
   */
  void pushNewRecursionContext(
      ParserRuleContext localctx, int state, int ruleIndex) {
    ParserRuleContext previous = _ctx;
    previous.parent = localctx;
    previous.invokingState = state;
    previous.stop = _input.LT(-1);

    _ctx = localctx;
    _ctx.start = previous.start;
    if (_buildParseTrees) {
      _ctx.addChild(previous);
    }

    if (_parseListeners != null) {
      triggerEnterRuleEvent(); // simulates rule entry for left-recursive rules
    }
  }

  void unrollRecursionContexts(ParserRuleContext _parentctx) {
    _precedenceStack.pop();
    _ctx.stop = _input.LT(-1);
    ParserRuleContext retctx = _ctx; // save current ctx (return value)

    // unroll so _ctx is as it was before call to recursive method
    if (_parseListeners != null) {
      while (_ctx != _parentctx) {
        triggerExitRuleEvent();
        _ctx = _ctx.parent as ParserRuleContext;
      }
    } else {
      _ctx = _parentctx;
    }

    // hook into tree
    retctx.parent = _parentctx;

    if (_buildParseTrees && _parentctx != null) {
      // add return ctx into invoking rule's tree
      _parentctx.addChild(retctx);
    }
  }

  ParserRuleContext getInvokingContext(int ruleIndex) {
    ParserRuleContext p = _ctx;
    while (p != null) {
      if (p.ruleIndex == ruleIndex) return p;
      p = p.parent;
    }
    return null;
  }

  ParserRuleContext get context => _ctx;

  void set context(ParserRuleContext ctx) {
    _ctx = ctx;
  }

  @override
  bool precpred(RuleContext localctx, int precedence) =>
      precedence >= _precedenceStack.peek();

  // TODO: useful in parser?
  bool inContext(String context) => false;

  /**
   * Checks whether or not {@code symbol} can follow the current state in the
   * ATN. The behavior of this method is equivalent to the following, but is
   * implemented such that the complete context-sensitive follow set does not
   * need to be explicitly constructed.
   *
   * <pre>
   * return getExpectedTokens().contains(symbol);
   * </pre>
   *
   * @param symbol the symbol type to check
   * @return {@code true} if {@code symbol} can follow the current state in
   * the ATN, otherwise {@code false}.
   */
  bool isExpectedToken(int symbol) {
    //   		return getInterpreter().atn.nextTokens(_ctx);
    ATN atn = interpreter.atn;
    ParserRuleContext ctx = _ctx;
    ATNState s = atn.states.get(state);
    IntervalSet following = atn.nextTokens(s);
    if (following.contains(symbol)) {
      return true;
    }
    //        System.out.println("following "+s+"="+following);
    if (!following.contains(Token.EPSILON)) return false;

    while (ctx != null &&
        ctx.invokingState >= 0 &&
        following.contains(Token.EPSILON)) {
      ATNState invokingState = atn.states.get(ctx.invokingState);
      RuleTransition rt = invokingState.transition(0);
      following = atn.nextTokens(rt.followState);
      if (following.contains(symbol)) {
        return true;
      }

      ctx = ctx.parent;
    }

    if (following.contains(Token.EPSILON) && symbol == Token.EOF) {
      return true;
    }

    return false;
  }

  bool get isMatchedEOF => matchedEOF;

  /**
   * Computes the set of input symbols which could follow the current parser
   * state and context, as given by {@link #getState} and {@link #getContext},
   * respectively.
   *
   * @see ATN#getExpectedTokens(int, RuleContext)
   */
  IntervalSet get expectedTokens => atn.expectedTokens(state, context);

  IntervalSet get expectedTokensWithinCurrentRule {
    ATN atn = interpreter.atn;
    ATNState s = atn.states.get(state);
    return atn.nextTokens(s);
  }

  /** Get a rule's index (i.e., {@code RULE_ruleName} field) or -1 if not found. */
  int getRuleIndex(String ruleName) {
    int ruleIndex = ruleIndexMap[ruleName];
    if (ruleIndex != null) return ruleIndex;
    return -1;
  }

  ParserRuleContext get ruleContext => _ctx;

  /** Return List&lt;String&gt; of the rule names in your parser instance
   *  leading up to a call to the current rule.  You could override if
   *  you want more details such as the file/line info of where
   *  in the ATN a rule is invoked.
   *
   *  This is very useful for error messages.
   */
  List<String> getRuleInvocationStack([RuleContext _p]) {
    RuleContext p = _p ?? _ctx;
    List<String> ruleNames = this.ruleNames;
    List<String> stack = [];
    while (p != null) {
      // compute what follows who invoked us
      int ruleIndex = p.getRuleIndex();
      if (ruleIndex < 0)
        stack.add("n/a");
      else
        stack.add(ruleNames[ruleIndex]);
      p = p.parent;
    }
    return stack;
  }

  /** For debugging and other purposes. */
  List<String> get dfaStrings {
    synchronized(_interp_decisionToDFA) {
      List<String> s = [];
      for (int d = 0; d < _interp_decisionToDFA.length; d++) {
        DFA dfa = _interp_decisionToDFA[d];
        s.add(dfa.toString(vocabulary));
      }
      return s;
    }

    // TODO (thosakwe): This was originally "_interp.decisionToDFA"
    return synchronized(interpreter.decisionToDFA);
  }

  /** For debugging and other purposes. */
  void dumpDFA() {
    synchronized(_interp_decisionToDFA) {
      bool seenOne = false;
      var buf = new StringBuffer();
      for (int d = 0; d < _interp_decisionToDFA.length; d++) {
        DFA dfa = _interp_decisionToDFA[d];
        if (!dfa.states.isEmpty()) {
          if (seenOne) buf.writeln();
          buf.write(
              "Decision ${dfa.decision}:${dfa.convertToString(vocabulary)}");
          seenOne = true;
        }
      }

      return print(buf);
    }

    // TODO (thosakwe): This was originally "_interp.decisionToDFA"
    return synchronized(interpreter.decisionToDFA);
  }

  String get sourceName => _input.sourceName;

  @override
  ParseInfo get parseInfo {
    ParserATNSimulator interp = this.interpreter;
    if (interp is ProfilingATNSimulator) {
      return new ParseInfo(interp as rofilingATNSimulator);
    }
    return null;
  }

  /**
   * @since 4.3
   */
  void set profile(bool profile) {
    ParserATNSimulator interp = this.interpreter;
    PredictionMode saveMode = interp.predictionMode;
    if (profile) {
      if (!(interp is ProfilingATNSimulator)) {
        this.interpreter = ProfilingATNSimulator(this);
      }
    } else if (interp is ProfilingATNSimulator) {
      ParserATNSimulator sim = new ParserATNSimulator(
          this, atn, interp.decisionToDFA, interp.sharedContextCache);
      this.interpreter = sim;
    }
    this.interpreter.predictionMode = saveMode;
  }

  /** During a parse is sometimes useful to listen in on the rule entry and exit
   *  events as well as token matches. This is for quick and dirty debugging.
   */
  void set trace(bool trace) {
    if (!trace) {
      removeParseListener(_tracer);
      _tracer = null;
    } else {
      if (_tracer != null)
        removeParseListener(_tracer);
      else
        _tracer = new TraceListener();
      addParseListener(_tracer);
    }
  }

  /**
   * Gets whether a {@link TraceListener} is registered as a parse listener
   * for the parser.
   *
   * @see #setTrace(bool)
   */
  bool get isTrace => _tracer != null;
}
