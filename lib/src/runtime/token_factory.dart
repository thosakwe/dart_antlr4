import 'misc/pair.dart';
import 'char_stream.dart';
import 'token_source.dart';

/** The default mechanism for creating tokens. It's used by default in Lexer and
 *  the error handling strategy (to create missing tokens).  Notifying the parser
 *  of a new factory means that it notifies it's token source and error strategy.
 */
abstract class TokenFactory<T> {
/** This is the method used to create tokens in the lexer and in the
 *  error handling strategy. If text!=null, than the start and stop positions
 *  are wiped to -1 in the text override is set in the CommonToken.
 */
  T create(Pair<TokenSource, CharStream> source, int type, String text,
      int channel, int start, int stop, int line, int charPositionInLine);

/** Generically useful */
  T createToken(int type, String text);
}
