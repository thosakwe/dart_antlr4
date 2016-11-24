import 'token.dart';

abstract class WritableToken extends Token {
  void setText(String text);

  void setType(int ttype);

  void setLine(int line);

  void setCharPositionInLine(int pos);

  void setChannel(int channel);

  void setTokenIndex(int index);
}
