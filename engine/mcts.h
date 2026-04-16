#pragma once
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <memory>
#include <vector>
#include <algorithm>
#include <random>
#include "board.h"
#include "eval.h"

// ============================================================
// MCTS Node
// ============================================================
struct Node {
    // Statistics
    int    visitCount   = 0;
    double qSum[4]      = {0.0, 0.0, 0.0, 0.0};  // cumulative rank-points per color

    // Tree structure
    Move   move;            // move that led to this node from parent (RESIGN_MOVE for root)
    Node*  parent   = nullptr;
    std::vector<std::unique_ptr<Node>> children;

    // Expansion state
    bool   expanded = false;   // true once children have been generated

    Node() : move(RESIGN_MOVE) {}
    explicit Node(Move m, Node* p) : move(m), parent(p) {}

    double q(int color) const {
        return visitCount > 0 ? qSum[color] / visitCount : 0.0;
    }
};

// ============================================================
// Rank-points from final score array  (6/4/2/0, ties averaged)
// ============================================================
inline std::array<int, 4> calculateRankPoints(const int finalPoints[4]) {
    constexpr int placePoints[4] = {6, 4, 2, 0};

    // Sort indices by score descending
    int idx[4] = {0, 1, 2, 3};
    std::sort(idx, idx + 4, [&](int a, int b) {
        return finalPoints[a] > finalPoints[b];
    });

    std::array<int, 4> result = {};
    int i = 0;
    while (i < 4) {
        int j = i;
        while (j < 4 && finalPoints[idx[j]] == finalPoints[idx[i]]) j++;
        // Average place-points across tied players
        int sum = 0;
        for (int p = i; p < j; p++) sum += placePoints[p];
        int avg = sum / (j - i);
        for (int p = i; p < j; p++) result[idx[p]] = avg;
        i = j;
    }
    return result;
}

// ============================================================
// MCTS
// ============================================================
class MCTS {
public:
    static constexpr double UCT_C = 12.0;      // exploration constant (matches Dart)
    static constexpr double UNVISITED_BONUS = 1e4;

    explicit MCTS(unsigned seed = 42) : rng_(seed) {}

    // Run `iterations` MCTS simulations from rootBoard.
    // Caller owns the root node.
    void search(Node& root, const Board& rootBoard, int iterations) {
        for (int i = 0; i < iterations; i++) {
            Board board;
            memcpy(&board, &rootBoard, sizeof(Board));
            simulate(root, board);
        }
    }

    // Best move at root: most visited child
    Move bestMove(const Node& root) const {
        const Node* best = nullptr;
        for (const auto& child : root.children) {
            if (!best || child->visitCount > best->visitCount)
                best = child.get();
        }
        return best ? best->move : RESIGN_MOVE;
    }

private:
    std::mt19937 rng_;

    void simulate(Node& root, Board& board) {
        // ---- 1. Selection: walk down fully-expanded nodes using UCT ----
        Node* node = &root;
        while (node->expanded && board.turn != GAME_OVER) {
            node = selectChild(node, board.turn);
            board.makeMove(node->move);
        }

        // ---- 2. Expansion: add all children of a non-terminal node ----
        if (board.turn != GAME_OVER && !node->expanded) {
            Move moves[MAX_MOVES];
            int count = board.generateMoves(moves);
            node->children.reserve(count);
            for (int i = 0; i < count; i++) {
                auto child = std::make_unique<Node>(moves[i], node);
                node->children.push_back(std::move(child));
            }
            node->expanded = true;

            // Pick a random unexplored child to evaluate
            if (!node->children.empty()) {
                int pick = std::uniform_int_distribution<int>(
                    0, static_cast<int>(node->children.size()) - 1)(rng_);
                node = node->children[pick].get();
                board.makeMove(node->move);
            }
        }

        // ---- 3. Evaluation (AlphaZero-style leaf eval, no rollout) ----
        std::array<int, 4> rankPoints;
        if (board.turn == GAME_OVER) {
            rankPoints = calculateRankPoints(board.points);
        } else {
            auto evalScores = evaluate(board);
            int rounded[4];
            for (int c = 0; c < 4; c++) rounded[c] = static_cast<int>(std::round(evalScores[c]));
            rankPoints = calculateRankPoints(rounded);
        }

        // ---- 4. Backpropagation ----
        Node* n = node;
        while (n != nullptr) {
            n->visitCount++;
            for (int c = 0; c < 4; c++) n->qSum[c] += rankPoints[c];
            n = n->parent;
        }
    }

    // UCT child selection — picks highest UCT value for the player-to-move
    Node* selectChild(Node* node, int turn) const {
        double logN = std::log(std::max(1, node->visitCount));
        double bestVal = -1e18;
        Node* bestChild = nullptr;

        for (const auto& child : node->children) {
            double val;
            if (child->visitCount == 0) {
                val = UNVISITED_BONUS +
                      std::uniform_real_distribution<double>(0.0, 1.0)(
                          const_cast<std::mt19937&>(rng_));
            } else {
                double exploit = child->qSum[turn] / child->visitCount;
                double explore = UCT_C * std::sqrt(logN / child->visitCount);
                val = exploit + explore;
            }
            if (val > bestVal) {
                bestVal = val;
                bestChild = child.get();
            }
        }
        return bestChild;
    }
};
