/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'dart:collection';
import 'misc/interval.dart';
import 'int_stream.dart';
import 'rule_context.dart';
import 'token.dart';
import 'token_source.dart';
import 'token_stream.dart';
import 'writable_token.dart';

/**
 * This implementation of {@link TokenStream} loads tokens from a
 * {@link TokenSource} on-demand, and places the tokens in a buffer to provide
 * access to any previous token by index.
 *
 * <p>
 * This token stream ignores the value of {@link Token#getChannel}. If your
 * parser requires the token stream filter tokens to only those on a particular
 * channel, such as {@link Token#DEFAULT_CHANNEL} or
 * {@link Token#HIDDEN_CHANNEL}, use a filtering token stream such a
 * {@link CommonTokenStream}.</p>
 */
class BufferedTokenStream implements TokenStream {
  /**
	 * The {@link TokenSource} from which tokens for this stream are fetched.
	 */
  TokenSource tokenSource;

  /**
	 * A collection of all tokens fetched from the token source. The list is
	 * considered a complete view of the input once {@link #fetchedEOF} is set
	 * to {@code true}.
	 */
  List<Token> tokens = new List<Token>(100);

  /**
	 * The index into {@link #tokens} of the current token (next token to
	 * {@link #consume}). {@link #tokens}{@code [}{@link #p}{@code ]} should be
	 * {@link #LT LT(1)}.
	 *
	 * <p>This field is set to -1 when the stream is first constructed or when
	 * {@link #setTokenSource} is called, indicating that the first token has
	 * not yet been fetched from the token source. For additional information,
	 * see the documentation of {@link IntStream} for a description of
	 * Initializing Methods.</p>
	 */
  int p = -1;

  /**
	 * Indicates whether the {@link Token#EOF} token has been fetched from
	 * {@link #tokenSource} and added to {@link #tokens}. This field improves
	 * performance for the following cases:
	 *
	 * <ul>
	 * <li>{@link #consume}: The lookahead check in {@link #consume} to prevent
	 * consuming the EOF symbol is optimized by checking the values of
	 * {@link #fetchedEOF} and {@link #p} instead of calling {@link #LA}.</li>
	 * <li>{@link #fetch}: The check to prevent adding multiple EOF symbols into
	 * {@link #tokens} is trivial with this field.</li>
	 * <ul>
	 */
  bool fetchedEOF;

  BufferedTokenStream(TokenSource tokenSource) {
    if (tokenSource == null) {
      throw new ArgumentError.notNull('tokenSource');
    }
    this.tokenSource = tokenSource;
  }

  @override
  int index() {
    return p;
  }

  @override
  int mark() {
    return 0;
  }

  @override
  void release(int marker) {
    // no resources to release
  }

  /**
	 * This method resets the token stream back to the first token in the
	 * buffer. It is equivalent to calling {@link #seek}{@code (0)}.
	 *
	 * @see #setTokenSource(TokenSource)
	 * @deprecated Use {@code seek(0)} instead.
	 */
  @deprecated
  void reset() {
    seek(0);
  }

  @override
  void seek(int index) {
    lazyInit();
    p = adjustSeekIndex(index);
  }

  @override
  int size() {
    return tokens.length;
  }

  @override
  void consume() {
    bool skipEofCheck;
    if (p >= 0) {
      if (fetchedEOF) {
        // the last token in tokens is EOF. skip check if p indexes any
        // fetched token except the last.
        skipEofCheck = p < tokens.length - 1;
      } else {
        // no EOF token in tokens. skip check if p indexes a fetched token.
        skipEofCheck = p < tokens.length;
      }
    } else {
      // not yet initialized
      skipEofCheck = false;
    }

    if (!skipEofCheck && LA(1) == IntStream.EOF) {
      throw new StateError("cannot consume EOF");
    }

    if (sync(p + 1)) {
      p = adjustSeekIndex(p + 1);
    }
  }

  /** Make sure index {@code i} in tokens has a token.
	 *
	 * @return {@code true} if a token is located at index {@code i}, otherwise
	 *    {@code false}.
	 * @see #get(int i)
	 */
  bool sync(int i) {
    assert(i >= 0);
    int n = i - tokens.length + 1; // how many more elements we need?
    //System.out.println("sync("+i+") needs "+n);
    if (n > 0) {
      int fetched = fetch(n);
      return fetched >= n;
    }

    return true;
  }

  /** Add {@code n} elements to buffer.
	 *
	 * @return The actual number of elements added to the buffer.
	 */
  int fetch(int n) {
    if (fetchedEOF) {
      return 0;
    }

    for (int i = 0; i < n; i++) {
      Token t = tokenSource.nextToken();
      if (t is WritableToken) {
        t.tokenIndex = tokens.length;
      }
      tokens.add(t);
      if (t.type == Token.EOF) {
        fetchedEOF = true;
        return i + 1;
      }
    }

    return n;
  }

  @override
  Token get(int i) {
    if (i < 0 || i >= tokens.length) {
      throw new RangeError.range(i, 0, tokens.length - 1);
    }
    return tokens[i];
  }

  /** Get all tokens from start..stop inclusively */
  List<Token> getRange(int start, int stop) {
    if (start < 0 || stop < 0) return null;
    lazyInit();
    List<Token> subset = [];
    if (stop >= tokens.length) stop = tokens.length - 1;
    for (int i = start; i <= stop; i++) {
      Token t = tokens[i];
      if (t.type == Token.EOF) break;
      subset.add(t);
    }
    return subset;
  }

  @override
  int LA(int i) {
    return LT(i).type;
  }

  Token LB(int k) {
    if ((p - k) < 0) return null;
    return tokens[p - k];
  }

  @override
  Token LT(int k) {
    lazyInit();
    if (k == 0) return null;
    if (k < 0) return LB(-k);

    int i = p + k - 1;
    sync(i);
    if (i >= tokens.length) {
      // return EOF token
      // EOF must be last token
      return tokens.last;
    }
//		if ( i>range ) range = i;
    return tokens[i];
  }

  /**
	 * Allowed derived classes to modify the behavior of operations which change
	 * the current stream position by adjusting the target token index of a seek
	 * operation. The default implementation simply returns {@code i}. If an
	 * exception is thrown in this method, the current stream index should not be
	 * changed.
	 *
	 * <p>For example, {@link CommonTokenStream} overrides this method to ensure that
	 * the seek target is always an on-channel token.</p>
	 *
	 * @param i The target token index.
	 * @return The adjusted target token index.
	 */
  int adjustSeekIndex(int i) {
    return i;
  }

  void lazyInit() {
    if (p == -1) {
      setup();
    }
  }

  void setup() {
    sync(0);
    p = adjustSeekIndex(0);
  }

  /** Reset this token stream by setting its token source. */
  void setTokenSource(TokenSource tokenSource) {
    this.tokenSource = tokenSource;
    tokens.clear();
    p = -1;
    fetchedEOF = false;
  }

  /** Given a start and stop index, return a List of all tokens in
     *  the token type BitSet.  Return null if no tokens were found.  This
     *  method looks at both on and off channel tokens.
     */
  List<Token> getTokens(int start, int stop, [_types]) {
    if (_types is int) {
      HashSet<int> s = new HashSet<int>()..add(_types);
      return getTokens(start, stop, s);
    }

    Set<int> types = _types;

    lazyInit();
    if (start < 0 ||
        stop >= tokens.length ||
        stop < 0 ||
        start >= tokens.length) {
      throw new RangeError(
          "start $start or stop $stop not in 0..${tokens.length - 1}");
    }
    if (start > stop) return null;

    // list = tokens[start:stop]:{T t, t.getType() in types}
    List<Token> filteredTokens = [];
    for (int i = start; i <= stop; i++) {
      Token t = tokens[i];
      if (types == null || types.contains(t.type)) {
        filteredTokens.add(t);
      }
    }
    if (filteredTokens.isEmpty) {
      filteredTokens = null;
    }
    return filteredTokens;
  }

  /**
	 * Given a starting index, return the index of the next token on channel.
	 * Return {@code i} if {@code tokens[i]} is on channel. Return the index of
	 * the EOF token if there are no tokens on channel between {@code i} and
	 * EOF.
	 */
  int nextTokenOnChannel(int i, int channel) {
    sync(i);
    if (i >= size()) {
      return size() - 1;
    }

    Token token = tokens[i];
    while (token.channel != channel) {
      if (token.type == Token.EOF) {
        return i;
      }

      i++;
      sync(i);
      token = tokens[i];
    }

    return i;
  }

  /**
	 * Given a starting index, return the index of the previous token on
	 * channel. Return {@code i} if {@code tokens[i]} is on channel. Return -1
	 * if there are no tokens on channel between {@code i} and 0.
	 *
	 * <p>
	 * If {@code i} specifies an index at or after the EOF token, the EOF token
	 * index is returned. This is due to the fact that the EOF token is treated
	 * as though it were on every channel.</p>
	 */
  int previousTokenOnChannel(int i, int channel) {
    sync(i);
    if (i >= size()) {
      // the EOF token is on every channel
      return size() - 1;
    }

    while (i >= 0) {
      Token token = tokens[i];
      if (token.type == Token.EOF || token.channel == channel) {
        return i;
      }

      i--;
    }

    return i;
  }

  /** Collect all tokens on specified channel to the right of
	 *  the current token up until we see a token on DEFAULT_TOKEN_CHANNEL or
	 *  EOF. If channel is -1, find any non default channel token.
	 */
  List<Token> getHiddenTokensToRight(int tokenIndex, [int channel = -1]) {
    lazyInit();
    if (tokenIndex < 0 || tokenIndex >= tokens.length) {
      throw new RangeError.range(tokenIndex, 0, tokens.length - 1);
    }

    int nextOnChannel =
        nextTokenOnChannel(tokenIndex + 1, Lexer.DEFAULT_TOKEN_CHANNEL);
    int to;
    int from = tokenIndex + 1;
    // if none onchannel to right, nextOnChannel=-1 so set to = last token
    if (nextOnChannel == -1)
      to = size() - 1;
    else
      to = nextOnChannel;

    return filterForChannel(from, to, channel);
  }

  /** Collect all tokens on specified channel to the left of
	 *  the current token up until we see a token on DEFAULT_TOKEN_CHANNEL.
	 *  If channel is -1, find any non default channel token.
	 */
  List<Token> getHiddenTokensToLeft(int tokenIndex, [int channel = -1]) {
    lazyInit();
    if (tokenIndex < 0 || tokenIndex >= tokens.length) {
      throw new RangeError.range(tokenIndex, 0, tokens.length - 1);
    }

    if (tokenIndex == 0) {
      // obviously no tokens can appear before the first token
      return null;
    }

    int prevOnChannel =
        previousTokenOnChannel(tokenIndex - 1, Lexer.DEFAULT_TOKEN_CHANNEL);
    if (prevOnChannel == tokenIndex - 1) return null;
    // if none onchannel to left, prevOnChannel=-1 then from=0
    int from = prevOnChannel + 1;
    int to = tokenIndex - 1;

    return filterForChannel(from, to, channel);
  }

  List<Token> filterForChannel(int from, int to, int channel) {
    List<Token> hidden = [];
    for (int i = from; i <= to; i++) {
      Token t = tokens[i];
      if (channel == -1) {
        if (t.channel != Lexer.DEFAULT_TOKEN_CHANNEL) hidden.add(t);
      } else {
        if (t.channel == channel) hidden.add(t);
      }
    }
    if (hidden.isEmpty) return null;
    return hidden;
  }

  @override
  String get sourceName => tokenSource.sourceName;

  /** Get the text of all tokens in this buffer. */

  @override
  String getText() {
    return getTextForInterval(Interval.of(0, size() - 1));
  }

  @override
  String getTextForInterval(Interval interval) {
    int start = interval.a;
    int stop = interval.b;
    if (start < 0 || stop < 0) return "";
    fill();
    if (stop >= tokens.length) stop = tokens.length - 1;

    var buf = new StringBuffer();
    for (int i = start; i <= stop; i++) {
      Token t = tokens[i];
      if (t.type == Token.EOF) break;
      buf.write(t.text);
    }
    return buf.toString();
  }

  @override
  String getTextForRule(RuleContext ctx) {
    return getTextForInterval(ctx.sourceInterval);
  }

  @override
  String getTextForStartStop(Token start, Token stop) {
    if (start != null && stop != null) {
      return getTextForInterval(Interval.of(start.tokenIndex, stop.tokenIndex));
    }

    return "";
  }

  /** Get all tokens from lexer until EOF */
  void fill() {
    lazyInit();
    final int blockSize = 1000;
    while (true) {
      int fetched = fetch(blockSize);
      if (fetched < blockSize) {
        return;
      }
    }
  }
}
