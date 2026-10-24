# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

% SCM-002 Constitutional Policy — Deny by Default
% Full evaluation requires an external Prolog interpreter (SWI-Prolog or GNU Prolog)

% Allowed generators for three-strand braid
generator(s1).
generator(s2).
generator(s1_inv).
generator(s2_inv).

valid_word([]).
valid_word([G|Rest]) :-
    generator(G),
    valid_word(Rest).

% Deny by default
decision(Id, Workspace, Target, Candidate, deny) :-
    \+ authorized(Id, Workspace, Target, Candidate),
    !.

authorized(Id, braid, Target, Candidate) :-
    ground(Id),
    valid_word(Target),
    valid_word(Candidate),
    trusted_equivalence(Id, Target, Candidate),
    trusted_cost_contract(Id).

decision(Id, Workspace, Target, Candidate, allow) :-
    authorized(Id, Workspace, Target, Candidate).
