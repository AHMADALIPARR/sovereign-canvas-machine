% Copyright (C) 2026 AHMAD ALI PARR
% Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
%
% Constitutional policy. Deny by default: a goal that is not proved
% authorized/5 is denied. Requires a Prolog system to execute.
% The bootstrap enforcer that the tests run is perl/policy_enforcer.pl,
% which implements the same Artin decision.

:- module(scm_policy, [decision/4, same_braid/2]).

generator(s1).
generator(s2).
generator(s1_inv).
generator(s2_inv).

valid_word([]).
valid_word([G|Rest]) :-
    generator(G),
    valid_word(Rest).

% Map tokens to signed Artin generators.
tok(s1, 1).
tok(s1_inv, -1).
tok(s2, 2).
tok(s2_inv, -2).

word_sig([], []).
word_sig([T|Ts], [S|Ss]) :- tok(T, S), word_sig(Ts, Ss).

% Free reduction, stack stored with the top at the head.
reduce([], []).
reduce([G|Gs], Out) :- reduce_acc(Gs, [G], Rev), reverse(Rev, Out).

reduce_acc([], Acc, Acc).
reduce_acc([G|Gs], [T|Ts], Out) :- G =:= -T, !, reduce_acc(Gs, Ts, Out).
reduce_acc([G|Gs], Acc, Out) :- reduce_acc(Gs, [G|Acc], Out).

% act(Gen, FreeLetter, ImageList)
act(1,  1, [1, 2, -1]).
act(1,  2, [1]).
act(1,  3, [3]).
act(-1, 1, [2]).
act(-1, 2, [-2, 1, 2]).
act(-1, 3, [3]).
act(2,  1, [1]).
act(2,  2, [2, 3, -2]).
act(2,  3, [2]).
act(-2, 1, [1]).
act(-2, 2, [3]).
act(-2, 3, [-3, 2, 3]).

subst([], _, []).
subst([L|Ls], MapGen, Out) :-
    Abs is abs(L),
    act(MapGen, Abs, Img),
    ( L > 0 -> Piece = Img ; invert(Img, Piece) ),
    subst(Ls, MapGen, Rest),
    append(Piece, Rest, Cat),
    reduce(Cat, Out).

invert([], []).
invert([H|T], Out) :- invert(T, R), N is -H, append(R, [N], Out).

artin(Word, Images) :- fold_artin(Word, [[1], [2], [3]], Images).

fold_artin([], Acc, Acc).
fold_artin([G|Gs], Acc, Out) :-
    map_strands(Acc, G, Next),
    fold_artin(Gs, Next, Out).

map_strands([], _, []).
map_strands([S|Ss], G, [R|Rs]) :-
    subst(S, G, R),
    map_strands(Ss, G, Rs).

same_braid(A, B) :-
    word_sig(A, As),
    word_sig(B, Bs),
    artin(As, Ia),
    artin(Bs, Ib),
    Ia == Ib.

trusted_equivalence(Target, Candidate) :-
    same_braid(Target, Candidate).

authorized(braid, Target, Candidate) :-
    valid_word(Target),
    valid_word(Candidate),
    trusted_equivalence(Target, Candidate).

decision(Workspace, Target, Candidate, allow) :-
    authorized(Workspace, Target, Candidate), !.
decision(_, _, _, deny).
