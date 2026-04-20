#pragma once
#include <array>
#include <cstdio>
#include <string>
#include <vector>
#include <random>
#include "board.h"
#include "mcts.h"
#include "nnue.h"

struct MatchConfig {
    std::string nnue1;
    std::string nnue2;
    int games = 20;
    int iters = 1000;
    int seed = 42;
};

static int runMatch(const MatchConfig& cfg) {
    NNUEModel model1, model2;
    bool use_nnue1 = (cfg.nnue1 != "none");
    bool use_nnue2 = (cfg.nnue2 != "none");

    if (use_nnue1 && !model1.load(cfg.nnue1)) {
        fprintf(stderr, "Error loading NNUE 1: %s\n", cfg.nnue1.c_str());
        return 1;
    }
    if (use_nnue2 && !model2.load(cfg.nnue2)) {
        fprintf(stderr, "Error loading NNUE 2: %s\n", cfg.nnue2.c_str());
        return 1;
    }

    std::mt19937 rng(cfg.seed);
    int model1_points = 0;
    int model2_points = 0;

    printf("Starting match: %d games, %d iters/move\n", cfg.games, cfg.iters);
    printf("Model 1 (Red/Yellow): %s\n", use_nnue1 ? cfg.nnue1.c_str() : "Hand-crafted Eval");
    printf("Model 2 (Blue/Green): %s\n\n", use_nnue2 ? cfg.nnue2.c_str() : "Hand-crafted Eval");

    for (int g = 0; g < cfg.games; g++) {
        Board board;
        board.reset();

        // Alternate seats every game
        bool m1_is_red = (g % 2 == 0);
        
        MCTS mcts1(rng(), use_nnue1 ? &model1 : nullptr);
        MCTS mcts2(rng(), use_nnue2 ? &model2 : nullptr);

        int ply = 0;
        while (board.turn != GAME_OVER && ply < 512) {
            bool is_m1_turn = (m1_is_red) ? (board.turn == RED || board.turn == YELLOW)
                                          : (board.turn == BLUE || board.turn == GREEN);
            
            Move best;
            if (is_m1_turn) {
                Node root;
                mcts1.search(root, board, cfg.iters);
                best = mcts1.bestMove(root);
            } else {
                Node root;
                mcts2.search(root, board, cfg.iters);
                best = mcts2.bestMove(root);
            }
            board.makeMove(best);
            ply++;
        }

        auto rp = calculateRankPoints(board.points);
        int m1_g_pts = 0, m2_g_pts = 0;
        
        if (m1_is_red) {
            m1_g_pts = rp[RED] + rp[YELLOW];
            m2_g_pts = rp[BLUE] + rp[GREEN];
        } else {
            m2_g_pts = rp[RED] + rp[YELLOW];
            m1_g_pts = rp[BLUE] + rp[GREEN];
        }

        model1_points += m1_g_pts;
        model2_points += m2_g_pts;

        printf("Game %2d: %s, M1 points: %d, M2 points: %d (Total: M1=%d, M2=%d)\n",
               g + 1, m1_is_red ? "M1=R/Y" : "M2=R/Y", m1_g_pts, m2_g_pts,
               model1_points, model2_points);
    }

    printf("\nFinal Result:\n");
    printf("  Model 1: %d\n", model1_points);
    printf("  Model 2: %d\n", model2_points);
    
    if (model1_points > model2_points) printf("WINNER: Model 1\n");
    else if (model2_points > model1_points) printf("WINNER: Model 2\n");
    else printf("RESULT: Draw\n");

    return 0;
}

static int matchMain(int argc, char* argv[]) {
    MatchConfig cfg;
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--nnue1" && i + 1 < argc) cfg.nnue1 = argv[++i];
        else if (arg == "--nnue2" && i + 1 < argc) cfg.nnue2 = argv[++i];
        else if (arg == "--games" && i + 1 < argc) cfg.games = std::stoi(argv[++i]);
        else if (arg == "--iters" && i + 1 < argc) cfg.iters = std::stoi(argv[++i]);
    }

    if (cfg.nnue1.empty() || cfg.nnue2.empty()) {
        printf("Usage: chaturaji match --nnue1 <file> --nnue2 <file> [--games N] [--iters N]\n");
        return 1;
    }

    return runMatch(cfg);
}
