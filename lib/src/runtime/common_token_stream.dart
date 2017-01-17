/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'buffered_token_stream.dart';
import 'token.dart';
import 'token_source.dart';

/**
 * This class extends {@link BufferedTokenStream} with functionality to filter
 * token streams to tokens on a particular channel (tokens where
 * {@link Token#getChannel} returns a particular value).
 *
 * <p>
 * This token stream provides access to all tokens by index or when calling
 * methods like {@link #getText}. The channel filtering is only used for code
 * accessing tokens via the lookahead methods {@link #LA}, {@link #LT}, and
 * {@link #LB}.</p>
 *
 * <p>
 * By default, tokens are placed on the default channel
 * ({@link Token#DEFAULT_CHANNEL}), but may be reassigned by using the
 * {@code ->channel(HIDDEN)} lexer command, or by using an embedded action to
 * call {@link Lexer#setChannel}.
 * </p>
 *
 * <p>
 * Note: lexer rules which use the {@code ->skip} lexer command or call
 * {@link Lexer#skip} do not produce tokens at all, so input text matched by
 * such a rule will not be available as part of the token stream, regardless of
 * channel.</p>we
 */
class CommonTokenStream extends BufferedTokenStream {
  /**
	 * Specifies the channel to use for filtering tokens.
	 *
	 * <p>
	 * The default value is {@link Token#DEFAULT_CHANNEL}, which matches the
	 * default channel assigned to tokens created by the lexer.</p>
	 */
  int channel = Token.DEFAULT_CHANNEL;

  /**
	 * Constructs a new {@link CommonTokenStream} using the specified token
	 * source and the default token channel ({@link Token#DEFAULT_CHANNEL}).
	 *
	 * @param tokenSource The token source.
	 */
  CommonTokenStream(TokenSource tokenSource, [this.channel])
      : super(tokenSource);

  @override
  int adjustSeekIndex(int i) {
    return nextTokenOnChannel(i, channel);
  }

  @override
  Token LB(int k) {
    if (k == 0 || (p - k) < 0) return null;

    int i = p;
    int n = 1;
    // find k good tokens looking backwards
    while (n <= k && i > 0) {
      // skip off-channel tokens
      i = previousTokenOnChannel(i - 1, channel);
      n++;
    }
    if (i < 0) return null;
    return tokens[i];
  }

  @override
  Token LT(int k) {
    //System.out.println("enter LT("+k+")");
    lazyInit();
    if (k == 0) return null;
    if (k < 0) return LB(-k);
    int i = p;
    int n = 1; // we know tokens[p] is a good one
    // find k good tokens
    while (n < k) {
      // skip off-channel tokens, but make sure to not look past EOF
      if (sync(i + 1)) {
        i = nextTokenOnChannel(i + 1, channel);
      }
      n++;
    }
//		if ( i>range ) range = i;
    return tokens[i];
  }

  /** Count EOF just once. */
  int get numberOfOnChannelTokens {
    int n = 0;
    fill();
    for (Token t in tokens) {
      if (t.channel == channel) n++;
      if (t.type == Token.EOF) break;
    }
    return n;
  }
}
