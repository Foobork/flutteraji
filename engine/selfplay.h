#pragma once
#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <random>
#include <vector>
#include "board.h"
#include "mcts.h"

// ============================================================
// Self-play configuration
// ============================================================
struct SelfPlayConfig {
    int         games      = 100;   // number of games to play
    int         iters      = 400;   // MCTS iterations per move
    int         tempPlies  = 8;     // plies with temperature > 0 (opening diversity)
    int         seed       = 42;
    const char* outFile    = "selfplay.txt";
    const char* nnuePath   = nullptr;
    bool        verbose    = false; // print game summaries to stderr
};

// ============================================================
// One recorded position
// ============================================================
struct PositionRecord {
    char   fen[256];
    int    rankPoints[4];   // filled in at game end: 6/4/2/0
};

// ============================================================
// Play a single game and return the list of position records
// (FEN at each ply before the move, plus final rank-points)
// ============================================================
static std::vector<PositionRecord> playSingleGame(
    const SelfPlayConfig& cfg, std::mt19937& rng, int gameIdx, NNUEModel* nnueModel)
{
    Board board;
    board.reset();
    std::vector<PositionRecord> records;
    int ply = 0;

    MCTS mcts(rng(), nnueModel);  // use parent rng for child seed

    while (board.turn != GAME_OVER) {
        // Record the position before the move
        PositionRecord rec;
        std::string fen = board.generateFen();
        strncpy(rec.fen, fen.c_str(), sizeof(rec.fen) - 1);
        rec.fen[sizeof(rec.fen) - 1] = '\0';
        memset(rec.rankPoints, 0, sizeof(rec.rankPoints));
        records.push_back(rec);

        // Run MCTS from this position
        Node root;
        mcts.search(root, board, cfg.iters);

        // Move selection:
        // - during opening (ply < tempPlies): sample proportional to visit^1 (temperature=1)
        // - after opening: argmax (most visited)
        Move chosen;
        if (ply < cfg.tempPlies && !root.children.empty()) {
            // Build distribution proportional to visit counts
            std::vector<double> weights;
            std::vector<Move> candidateMoves;
            for (const auto& child : root.children) {
                if (child->visitCount > 0) {
                    weights.push_back(static_cast<double>(child->visitCount));
                    candidateMoves.push_back(child->move);
                }
            }
            if (!candidateMoves.empty()) {
                std::discrete_distribution<int> dist(weights.begin(), weights.end());
                chosen = candidateMoves[dist(rng)];
            } else {
                chosen = mcts.bestMove(root);
            }
        } else {
            chosen = mcts.bestMove(root);
        }

        board.makeMove(chosen);
        ply++;

        // Safety valve: cap game length to avoid infinite games
        if (ply > 512) break;
    }

    // Compute final rank-points from the terminal board state
    auto rankPts = calculateRankPoints(board.points);

    // Fill rank-points into every recorded position
    for (auto& rec : records) {
        for (int c = 0; c < 4; c++) rec.rankPoints[c] = rankPts[c];
    }

    if (cfg.verbose) {
        fprintf(stderr, "Game %d: %d plies, points r=%d b=%d y=%d g=%d, ranks r=%d b=%d y=%d g=%d\n",
                gameIdx + 1, ply,
                board.points[0], board.points[1], board.points[2], board.points[3],
                rankPts[0], rankPts[1], rankPts[2], rankPts[3]);
    }

    return records;
}

// ============================================================
// Run self-play and write output file
// ============================================================
// Output format (text, one line per position):
//   <FEN> | <rank_r> <rank_b> <rank_y> <rank_g>
//
// For example:
//   bRbP2yK.../rRrNrBrK 0/0/0/0 r | 6 4 0 2
// ============================================================
static int runSelfPlay(const SelfPlayConfig& cfg) {
    FILE* out = fopen(cfg.outFile, "w");
    if (!out) {
        fprintf(stderr, "Error: cannot open output file: %s\n", cfg.outFile);
        return 1;
    }

    NNUEModel nnue;
    if (cfg.nnuePath) {
        if (!nnue.load(cfg.nnuePath)) {
            fprintf(stderr, "Error: failed to load NNUE from: %s\n", cfg.nnuePath);
            fclose(out);
            return 1;
        }
    }

    std::mt19937 rng(cfg.seed);
    long long totalPositions = 0;

    fprintf(stderr, "Self-play: %d games, %d iters/move, %d temp-plies, seed=%d\n",
            cfg.games, cfg.iters, cfg.tempPlies, cfg.seed);
    if (cfg.nnuePath) fprintf(stderr, "Model:     %s\n", cfg.nnuePath);
    else              fprintf(stderr, "Model:     Hand-crafted evaluator (baseline)\n");
    fprintf(stderr, "Output:    %s\n\n", cfg.outFile);

    for (int g = 0; g < cfg.games; g++) {
        auto records = playSingleGame(cfg, rng, g, nnue.loaded ? &nnue : nullptr);

        // Write all positions for this game
        for (const auto& rec : records) {
            fprintf(out, "%s | %d %d %d %d\n",
                    rec.fen,
                    rec.rankPoints[0], rec.rankPoints[1],
                    rec.rankPoints[2], rec.rankPoints[3]);
        }

        totalPositions += static_cast<long long>(records.size());

        // Progress every 10 games
        if ((g + 1) % 10 == 0 || g + 1 == cfg.games) {
            fprintf(stderr, "  completed %d/%d games  (%lld positions)\n",
                    g + 1, cfg.games, totalPositions);
        }
    }

    fclose(out);
    fprintf(stderr, "\nDone. Wrote %lld positions to %s\n", totalPositions, cfg.outFile);
    return 0;
}

// ============================================================
// Parse self-play CLI arguments
//   selfplay [--games N] [--iters N] [--temp-plies N]
//            [--out FILE] [--seed N] [--nnue FILE] [--verbose]
// ============================================================
static int selfPlayMain(int argc, char* argv[]) {
    SelfPlayConfig cfg;

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if ((arg == "--games" || arg == "-g") && i + 1 < argc) {
            cfg.games = std::stoi(argv[++i]);
        } else if ((arg == "--iters" || arg == "-n") && i + 1 < argc) {
            cfg.iters = std::stoi(argv[++i]);
        } else if ((arg == "--temp-plies") && i + 1 < argc) {
            cfg.tempPlies = std::stoi(argv[++i]);
        } else if ((arg == "--out" || arg == "-o") && i + 1 < argc) {
            cfg.outFile = argv[++i];
        } else if ((arg == "--nnue") && i + 1 < argc) {
            cfg.nnuePath = argv[++i];
        } else if ((arg == "--seed") && i + 1 < argc) {
            cfg.seed = std::stoi(argv[++i]);
        } else if (arg == "--verbose" || arg == "-v") {
            cfg.verbose = true;
        } else if (arg == "--help" || arg == "-h") {
            printf(
                "Usage: chaturaji.exe selfplay [options]\n\n"
                "Options:\n"
                "  --games N       Number of games to play (default: 100)\n"
                "  --iters N       MCTS iterations per move (default: 400)\n"
                "  --temp-plies N  Opening plies with sampling (default: 8)\n"
                "  --out FILE      Output file path (default: selfplay.txt)\n"
                "  --nnue FILE      NNUE model file (.nnue)\n"
                "  --seed N        Random seed (default: 42)\n"
                "  --verbose       Print game summaries to stderr\n\n"
                "Output format (one line per position):\n"
                "  <FEN> | <rank_r> <rank_b> <rank_y> <rank_g>\n"
            );
            return 0;
        }
    }

    return runSelfPlay(cfg);
}
