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
#include "nnue.h"

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
    double prior    = 1.0;     // Tactical prior probability P(s, a)

    Node() : move(RESIGN_MOVE) {}
    explicit Node(Move m, Node* p, double p_prior = 1.0) : move(m), parent(p), prior(p_prior) {}

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
// Tactical Move Scorer (MVV-LVA, Checks, Promotions, Center)
// ============================================================
inline double scoreMove(const Board& board, const Move& move) {
    if (move.from < 0 || move.to < 0) {
        return 0.0001; // RESIGN_MOVE
    }

    double score = 1.0; // Base score for quiet moves
    uint8_t movingPiece = board.board[move.from];
    uint8_t targetPiece = board.board[move.to];
    uint8_t movingType = movingPiece & PIECE_MASK;
    uint8_t targetType = targetPiece & PIECE_MASK;

    // 1. Captures (MVV-LVA)
    if (targetPiece != EMPTY) {
        int victimVal = capturePoints(targetPiece);
        int attackerVal = capturePoints(movingPiece);
        score += 50.0 + (victimVal * 20.0) - (attackerVal * 1.0);
        if (targetType == KING) {
            score += 100.0; // Extra bonus for capturing a King
        }
    }

    // 2. Pawn Promotions
    if (movingType == PAWN) {
        int r = move.to >> 4;
        int c = move.to & 0x0F;
        bool isPromotion = false;
        switch (board.turn) {
            case RED:    isPromotion = (r == 0); break;
            case BLUE:   isPromotion = (c == 7); break;
            case YELLOW: isPromotion = (r == 7); break;
            case GREEN:  isPromotion = (c == 0); break;
        }
        if (isPromotion) {
            score += 40.0;
        }
    }

    // 3. Center Control for Quiet Moves
    int toRow = move.to >> 4;
    int toCol = move.to & 0x0F;
    if ((toRow == 3 || toRow == 4) && (toCol == 3 || toCol == 4)) {
        score += 2.0;
    } else if ((toRow >= 2 && toRow <= 5) && (toCol >= 2 && toCol <= 5)) {
        score += 1.0;
    }

    // 4. King in check defense
    if (board.isKingInCheck(board.turn)) {
        if (movingType == KING) {
            score += 30.0; // King evasion
        } else if (targetPiece != EMPTY) {
            score += 25.0; // Capture checking piece
        }
    }

    return std::max(0.001, score);
}

// ============================================================
// MCTS
// ============================================================
class MCTS {
public:
    static constexpr double UCT_C = 12.0;      // exploration constant (matches Dart)
    static constexpr double UNVISITED_BONUS = 1e4;

    explicit MCTS(unsigned seed = 42, NNUEModel* model = nullptr) 
        : rng_(seed), nnueModel_(model) {}

    void setNNUE(NNUEModel* model) { nnueModel_ = model; }

    // Run `iterations` MCTS simulations from rootBoard.
    // Caller owns the root node.
    void search(Node& root, const Board& rootBoard, int iterations) {
        for (int i = 0; i < iterations; i++) {
            Board board;
            memcpy(&board, &rootBoard, sizeof(Board));
            board.undoCount = 0;  // simulations start fresh — don't inherit game history
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
    NNUEModel*   nnueModel_;

    void simulate(Node& root, Board& board) {
        // ---- 1. Selection: walk down fully-expanded nodes using PUCT ----
        Node* node = &root;
        while (node->expanded && board.turn != GAME_OVER) {
            node = selectChild(node, board.turn);
            board.makeMove(node->move, nnueModel_);
        }

        // ---- 2. Expansion: add all children of a non-terminal node ----
        if (board.turn != GAME_OVER && !node->expanded) {
            Move moves[MAX_MOVES];
            int count = board.generateMoves(moves);
            if (count > 0) {
                node->children.reserve(count);
                std::vector<double> scores(count);
                double scoreSum = 0.0;
                for (int i = 0; i < count; i++) {
                    scores[i] = scoreMove(board, moves[i]);
                    scoreSum += scores[i];
                }
                if (scoreSum <= 0.0) scoreSum = 1.0;

                for (int i = 0; i < count; i++) {
                    double normalizedPrior = scores[i] / scoreSum;
                    auto child = std::make_unique<Node>(moves[i], node, normalizedPrior);
                    node->children.push_back(std::move(child));
                }

                // Sort children so highest prior is at index 0
                std::sort(node->children.begin(), node->children.end(),
                    [](const std::unique_ptr<Node>& a, const std::unique_ptr<Node>& b) {
                        return a->prior > b->prior;
                    });
            }
            node->expanded = true;

            // Pick highest tactical prior child to evaluate first
            if (!node->children.empty()) {
                node = node->children[0].get();
                board.makeMove(node->move, nnueModel_);
            }
        }

        // ---- 3. Evaluation (AlphaZero-style leaf eval, no rollout) ----
        double evalPoints[4] = {0.0, 0.0, 0.0, 0.0};
        if (board.turn == GAME_OVER) {
            auto rp = calculateRankPoints(board.points);
            for (int c = 0; c < 4; c++) evalPoints[c] = (double)rp[c];
        } else if (nnueModel_ && nnueModel_->loaded) {
            float probs[NNUE_OUT_SIZE];
            nnueModel_->evaluate(board, probs);
            // NNUE predicts distribution [self, left, across, right] relative to board.turn.
            // Map back to [Red, Blue, Yellow, Green] and scale to rank-points (sum=12).
            for (int c = 0; c < 4; c++) {
                int rel = NNUE_RELATION[board.turn][c];
                evalPoints[c] = (double)(probs[rel] * 12.0f);
            }
        } else {
            auto evalScores = evaluate(board);
            int rounded[4];
            for (int c = 0; c < 4; c++) rounded[c] = static_cast<int>(std::round(evalScores[c]));
            auto rp = calculateRankPoints(rounded);
            for (int c = 0; c < 4; c++) evalPoints[c] = (double)rp[c];
        }

        // ---- 4. Backpropagation ----
        Node* n = node;
        while (n != nullptr) {
            n->visitCount++;
            for (int c = 0; c < 4; c++) n->qSum[c] += evalPoints[c];
            n = n->parent;
        }
    }

    // PUCT child selection — balances exploitation with tactical prior exploration
    Node* selectChild(Node* node, int turn) const {
        double bestVal = -1e18;
        Node* bestChild = nullptr;

        double sumN = 0.0;
        for (const auto& child : node->children) {
            sumN += child->visitCount;
        }
        double sqrtSumN = std::sqrt(std::max(1.0, sumN));

        for (const auto& child : node->children) {
            double val;
            if (child->visitCount == 0) {
                val = UNVISITED_BONUS + (child->prior * 1000.0) +
                      std::uniform_real_distribution<double>(0.0, 0.01)(
                          const_cast<std::mt19937&>(rng_));
            } else {
                double exploit = child->qSum[turn] / child->visitCount;
                double explore = UCT_C * child->prior * (sqrtSumN / (1.0 + child->visitCount));
                val = exploit + explore;
            }
            if (val > bestVal) {
                bestVal = val;
                bestChild = child.get();
            }
        }
        return bestChild ? bestChild : (node->children.empty() ? nullptr : node->children[0].get());
    }
};

