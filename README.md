# Flutteraji: Chaturaji Analysis Tool

Flutteraji is a Flutter-based application designed for the analysis and exploration of Chaturaji, an ancient four-player Indian chess variant.

## Features

- **Chaturaji Engine**: A complete implementation of Chaturaji rules, including piece movements (King, Elephant/Bishop, Horse/Knight, Ship/Rook, and Pawn), scoring systems, and check/double-check/triple-check detection.
- **Graph-Based Analysis**: Tracks game states using a directed graph, allowing for exploration of different move sequences and their outcomes.
- **Interactive UI**: A graphical interface to play moves, visualize the board, and view real-time statistics like node visits (N) and value estimates (Q) for different positions.
- **FEN Support**: Supports loading and generating Forsyth-Edwards Notation (FEN) specifically adapted for the 4-player Chaturaji layout.
- **State Management**: Easily undo moves, reset the game, and export/import the analysis graph.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- A mobile emulator or physical device, or a web browser for web development.

### Running the App

1.  Clone the repository:
    ```bash
    git clone [repository-url]
    ```
2.  Navigate to the project directory:
    ```bash
    cd flutteraji
    ```
3.  Install dependencies:
    ```bash
    flutter pub get
    ```
4.  Run the application:
    ```bash
    flutter run
    ```

## Project Structure

- `lib/chaturaji`: Core game logic, board representation, and move generation.
- `lib/graph`: Data structures for managing the analysis graph.
- `lib/gui`: UI components and controllers for the Chaturaji board and analysis table.
- `chaturbot`: A sub-project/module focused on automated play and move execution (e.g., for Chess.com automation).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
