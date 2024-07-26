import gleam/bool
import gleam/option.{type Option, None, Some}
import gleam/string
import utils

pub type Game {
  Game(board: Board, player: Color)
  GameWon(board: Board, winner: Color)
}

pub type Color {
  Black
  White
}

pub fn color_to_string(color: Color) -> String {
  case color {
    White -> "White"
    Black -> "Black"
  }
}

pub fn other_player(player: Color) -> Color {
  case player {
    White -> Black
    Black -> White
  }
}

pub type Piece =
  Option(Color)

/// One row
pub type RankContent {
  RankContent(Piece, Piece, Piece, Piece, Piece, Piece, Piece, Piece)
}

/// The board, as a bunch of rows
pub type Board {
  Board(
    RankContent,
    RankContent,
    RankContent,
    RankContent,
    RankContent,
    RankContent,
    RankContent,
    RankContent,
  )
}

pub fn incr_rank(index: Rank) -> Option(Rank) {
  case index {
    One -> Some(Two)
    Two -> Some(Three)
    Three -> Some(Four)
    Four -> Some(Five)
    Five -> Some(Six)
    Six -> Some(Seven)
    Seven -> Some(Eight)
    Eight -> None
  }
}

pub fn decr_rank(index: Rank) -> Option(Rank) {
  case index {
    One -> None
    Two -> Some(One)
    Three -> Some(Two)
    Four -> Some(Three)
    Five -> Some(Four)
    Six -> Some(Five)
    Seven -> Some(Six)
    Eight -> Some(Seven)
  }
}

pub fn incr_file(index: File) -> Option(File) {
  case index {
    A -> Some(B)
    B -> Some(C)
    C -> Some(D)
    D -> Some(E)
    E -> Some(F)
    F -> Some(G)
    G -> Some(H)
    H -> None
  }
}

pub fn decr_file(index: File) -> Option(File) {
  case index {
    A -> None
    B -> Some(A)
    C -> Some(B)
    D -> Some(C)
    E -> Some(D)
    F -> Some(E)
    G -> Some(F)
    H -> Some(G)
  }
}

pub fn get_neighbors(pos: Position) -> List(Position) {
  let Position(target_rank, target_file) = pos
  [
    incr_rank(target_rank)
      |> option.map(Position(_, target_file)),
    decr_rank(target_rank)
      |> option.map(Position(_, target_file)),
    incr_file(target_file)
      |> option.map(Position(target_rank, _)),
    decr_file(target_file)
      |> option.map(Position(target_rank, _)),
  ]
  |> option.values
}

pub fn get_neighbors_two_out(pos: Position) -> List(#(Position, Position)) {
  let Position(target_rank, target_file) = pos
  [
    utils.twice_optional(target_rank, incr_rank)
      |> option.map(fn(r) {
        #(Position(r.0, target_file), Position(r.1, target_file))
      }),
    utils.twice_optional(target_rank, decr_rank)
      |> option.map(fn(r) {
        #(Position(r.0, target_file), Position(r.1, target_file))
      }),
    utils.twice_optional(target_file, incr_file)
      |> option.map(fn(f) {
        #(Position(target_rank, f.0), Position(target_rank, f.1))
      }),
    utils.twice_optional(target_file, decr_file)
      |> option.map(fn(f) {
        #(Position(target_rank, f.0), Position(target_rank, f.1))
      }),
  ]
  |> option.values
}

pub type Rank {
  One
  Two
  Three
  Four
  Five
  Six
  Seven
  Eight
}

pub type File {
  A
  B
  C
  D
  E
  F
  G
  H
}

fn get_piece(rank: RankContent, index: File) -> Piece {
  let RankContent(r0, r1, r2, r3, r4, r5, r6, r7) = rank
  case index {
    A -> r0
    B -> r1
    C -> r2
    D -> r3
    E -> r4
    F -> r5
    G -> r6
    H -> r7
  }
}

fn set_piece(rank: RankContent, index: File, piece: Piece) -> RankContent {
  let RankContent(r0, r1, r2, r3, r4, r5, r6, r7) = rank
  case index {
    A -> RankContent(piece, r1, r2, r3, r4, r5, r6, r7)
    B -> RankContent(r0, piece, r2, r3, r4, r5, r6, r7)
    C -> RankContent(r0, r1, piece, r3, r4, r5, r6, r7)
    D -> RankContent(r0, r1, r2, piece, r4, r5, r6, r7)
    E -> RankContent(r0, r1, r2, r3, piece, r5, r6, r7)
    F -> RankContent(r0, r1, r2, r3, r4, piece, r6, r7)
    G -> RankContent(r0, r1, r2, r3, r4, r5, piece, r7)
    H -> RankContent(r0, r1, r2, r3, r4, r5, r6, piece)
  }
}

fn get_rank(board: Board, index: Rank) -> RankContent {
  let Board(r0, r1, r2, r3, r4, r5, r6, r7) = board
  case index {
    Eight -> r0
    Seven -> r1
    Six -> r2
    Five -> r3
    Four -> r4
    Three -> r5
    Two -> r6
    One -> r7
  }
}

fn set_rank(board: Board, index: Rank, rank: RankContent) -> Board {
  let Board(r0, r1, r2, r3, r4, r5, r6, r7) = board
  case index {
    Eight -> Board(rank, r1, r2, r3, r4, r5, r6, r7)
    Seven -> Board(r0, rank, r2, r3, r4, r5, r6, r7)
    Six -> Board(r0, r1, rank, r3, r4, r5, r6, r7)
    Five -> Board(r0, r1, r2, rank, r4, r5, r6, r7)
    Four -> Board(r0, r1, r2, r3, rank, r5, r6, r7)
    Three -> Board(r0, r1, r2, r3, r4, rank, r6, r7)
    Two -> Board(r0, r1, r2, r3, r4, r5, rank, r7)
    One -> Board(r0, r1, r2, r3, r4, r5, r6, rank)
  }
}

pub fn get(board: Board, position: Position) -> Piece {
  let Position(rank, file) = position
  get_piece(get_rank(board, rank), file)
}

pub fn set(board: Board, position: Position, piece: Piece) -> Board {
  let Position(rank, file) = position
  set_rank(board, rank, set_piece(get_rank(board, rank), file, piece))
}

/// Set a piece if the position is empty and return the board. 
/// Otherwise return none.
pub fn set_if_empty(
  board: Board,
  position: Position,
  player: Color,
) -> Option(Board) {
  case get(board, position) {
    None -> Some(set(board, position, Some(player)))
    Some(_) -> None
  }
}

pub fn empty_board() -> Board {
  Board(
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
    RankContent(None, None, None, None, None, None, None, None),
  )
}

pub const white_home = [
  Position(Eight, E), Position(Eight, F), Position(Eight, G), Position(Eight, H),
  Position(Seven, F), Position(Seven, G), Position(Seven, H), Position(Six, G),
  Position(Six, H), Position(Five, H),
]

pub const black_home = [
  Position(One, A), Position(One, B), Position(One, C), Position(One, D),
  Position(Two, A), Position(Two, B), Position(Two, C), Position(Three, A),
  Position(Three, B), Position(Four, A),
]

///
///    a b c d e f g h
/// 8  · · · · ● ● ● ●
/// 7  · · · · · ● ● ●
/// 6  · · · · · · ● ●
/// 5  · · · + + · · ●
/// 4  ○ · · + + · · ·
/// 3  ○ ○ · · · · · ·
/// 2  ○ ○ ○ · · · · ·
/// 1  ○ ○ ○ ○ · · · ·
/// 
pub const starting_board = Board(
  RankContent(
    None,
    None,
    None,
    None,
    Some(White),
    Some(White),
    Some(White),
    Some(White),
  ),
  RankContent(
    None,
    None,
    None,
    None,
    None,
    Some(White),
    Some(White),
    Some(White),
  ),
  RankContent(None, None, None, None, None, None, Some(White), Some(White)),
  RankContent(None, None, None, None, None, None, None, Some(White)),
  RankContent(Some(Black), None, None, None, None, None, None, None),
  RankContent(Some(Black), Some(Black), None, None, None, None, None, None),
  RankContent(
    Some(Black),
    Some(Black),
    Some(Black),
    None,
    None,
    None,
    None,
    None,
  ),
  RankContent(
    Some(Black),
    Some(Black),
    Some(Black),
    Some(Black),
    None,
    None,
    None,
    None,
  ),
)

pub fn to_string(board: Board) -> String {
  let Board(r0, r1, r2, r3, r4, r5, r6, r7) = board
  "  A B C D E F G H\n"
  <> "8 "
  <> to_string_rank(r0)
  <> "\n"
  <> "7 "
  <> to_string_rank(r1)
  <> "\n"
  <> "6 "
  <> to_string_rank(r2)
  <> "\n"
  <> "5 "
  <> to_string_rank(r3)
  <> "\n"
  <> "4 "
  <> to_string_rank(r4)
  <> "\n"
  <> "3 "
  <> to_string_rank(r5)
  <> "\n"
  <> "2 "
  <> to_string_rank(r6)
  <> "\n"
  <> "1 "
  <> to_string_rank(r7)
}

fn to_string_rank(rank: RankContent) -> String {
  let RankContent(r0, r1, r2, r3, r4, r5, r6, r7) = rank
  to_string_piece(r0)
  <> " "
  <> to_string_piece(r1)
  <> " "
  <> to_string_piece(r2)
  <> " "
  <> to_string_piece(r3)
  <> " "
  <> to_string_piece(r4)
  <> " "
  <> to_string_piece(r5)
  <> " "
  <> to_string_piece(r6)
  <> " "
  <> to_string_piece(r7)
}

fn to_string_piece(piece: Piece) -> String {
  case piece {
    None -> "·"
    Some(White) -> "●"
    Some(Black) -> "○"
  }
}

pub type Position {
  Position(rank: Rank, file: File)
}

pub fn position_from_string(s: String) -> Option(Position) {
  case string.to_graphemes(s) {
    [file, rank] -> {
      use r <- option.then(rank_from_string(rank))
      use f <- option.then(file_from_string(file))
      Some(Position(r, f))
    }
    _ -> None
  }
}

fn rank_from_string(s: String) -> Option(Rank) {
  case s {
    "1" -> Some(One)
    "2" -> Some(Two)
    "3" -> Some(Three)
    "4" -> Some(Four)
    "5" -> Some(Five)
    "6" -> Some(Six)
    "7" -> Some(Seven)
    "8" -> Some(Eight)
    _ -> None
  }
}

fn file_from_string(s: String) -> Option(File) {
  case s {
    "a" -> Some(A)
    "b" -> Some(B)
    "c" -> Some(C)
    "d" -> Some(D)
    "e" -> Some(E)
    "f" -> Some(F)
    "g" -> Some(G)
    "h" -> Some(H)
    _ -> None
  }
}

pub type RankDiff {
  RankDiffZero
  RankDiffIncr
  RankDiffDecr
  RankDiffIncrIncr
  RankDiffDecrDecr
}

fn get_diff_rank(from from: Rank, to to: Rank) -> Option(RankDiff) {
  use <- bool.guard(from == to, Some(RankDiffZero))
  use <- bool.guard(incr_rank(from) == Some(to), Some(RankDiffIncr))
  use <- bool.guard(decr_rank(from) == Some(to), Some(RankDiffDecr))
  use <- bool.guard(
    incr_rank(from) |> option.then(incr_rank) == Some(to),
    Some(RankDiffIncrIncr),
  )
  use <- bool.guard(
    decr_rank(from) |> option.then(decr_rank) == Some(to),
    Some(RankDiffDecrDecr),
  )
  None
}

pub type FileDiff {
  FileDiffZero
  FileDiffIncr
  FileDiffDecr
  FileDiffIncrIncr
  FileDiffDecrDecr
}

fn get_diff_file(from from: File, to to: File) -> Option(FileDiff) {
  use <- bool.guard(from == to, Some(FileDiffZero))
  use <- bool.guard(incr_file(from) == Some(to), Some(FileDiffIncr))
  use <- bool.guard(decr_file(from) == Some(to), Some(FileDiffDecr))
  use <- bool.guard(
    incr_file(from) |> option.then(incr_file) == Some(to),
    Some(FileDiffIncrIncr),
  )
  use <- bool.guard(
    decr_file(from) |> option.then(decr_file) == Some(to),
    Some(FileDiffDecrDecr),
  )
  None
}

pub fn get_diff(
  from from: Position,
  to to: Position,
) -> Option(#(RankDiff, FileDiff)) {
  let Position(from_rank, from_file) = from
  let Position(to_rank, to_file) = to
  use rank_diff <- option.then(get_diff_rank(from: from_rank, to: to_rank))
  use file_diff <- option.then(get_diff_file(from: from_file, to: to_file))
  Some(#(rank_diff, file_diff))
}

fn apply_rank_diff(rank: Rank, diff: RankDiff) -> Option(Rank) {
  case diff {
    RankDiffZero -> Some(rank)
    RankDiffIncr -> incr_rank(rank)
    RankDiffDecr -> decr_rank(rank)
    RankDiffIncrIncr -> incr_rank(rank) |> option.then(incr_rank)
    RankDiffDecrDecr -> decr_rank(rank) |> option.then(decr_rank)
  }
}

fn apply_file_diff(file: File, diff: FileDiff) -> Option(File) {
  case diff {
    FileDiffZero -> Some(file)
    FileDiffIncr -> incr_file(file)
    FileDiffDecr -> decr_file(file)
    FileDiffIncrIncr -> incr_file(file) |> option.then(incr_file)
    FileDiffDecrDecr -> decr_file(file) |> option.then(decr_file)
  }
}

pub fn apply_diff(
  position: Position,
  diff: #(RankDiff, FileDiff),
) -> Option(Position) {
  let #(rank_diff, file_diff) = diff
  let Position(rank, file) = position
  use new_rank <- option.then(apply_rank_diff(rank, rank_diff))
  use new_file <- option.then(apply_file_diff(file, file_diff))
  Some(Position(new_rank, new_file))
}
