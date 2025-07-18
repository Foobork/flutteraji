
enum PlayerColor { red, blue, yellow, green }

const PlayerColor red = PlayerColor.red;
const PlayerColor blue = PlayerColor.blue;
const PlayerColor yellow = PlayerColor.yellow;
const PlayerColor green = PlayerColor.green;

const Map<String, PlayerColor> colors = {
  'r': red,
  'b': blue,
  'y': yellow,
  'g': green,
};

const Map<PlayerColor, String> colorSymbols = {
  red: 'r',
  blue: 'b',
  yellow: 'y',
  green: 'g',
};

const Map<PlayerColor, String> colorNames = {
  red: 'Red',
  blue: 'Blue',
  yellow: 'Yellow',
  green: 'Green',
};

const Map<PlayerColor, PlayerColor> nextColor = {
  red: blue,
  blue: yellow,
  yellow: green,
  green: red,
};
