import gleam/bool
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result

import logic/board.{
  type Board, type Color, type Position, Black, Board, Position, RankContent,
  White,
}

pub type ActionResult {
  Continue(Board)
  Win(Board, Color)
}

pub type ActionType {
  Move(player: Color, active: Position, pivot: Position)
  Place(player: Color)
}

pub type ActionError {
  NothingCanBePlaced
  PivotAndActiveAreTheSame
  PivotAndActiveAreTooFarApart
  PivotOrActiveAreEnemy
  MoveTargetIsOccupied
  MoveTargetOffBoard
  WrongTurnPlayer
  GameAlreadyOver
}

pub fn action_error_to_string(a: ActionError) {
  case a {
    NothingCanBePlaced -> "NothingCanBePlaced"
    PivotAndActiveAreTheSame -> "PivotAndActiveAreTheSame"
    PivotAndActiveAreTooFarApart -> "PivotAndActiveAreTooFarApart"
    MoveTargetIsOccupied -> "MoveTargetIsOccupied"
    PivotOrActiveAreEnemy -> "PivotOrActiveAreEnemy"
    MoveTargetOffBoard -> "MoveTargetOffBoard"
    WrongTurnPlayer -> "WrongTurnPlayer"
    GameAlreadyOver -> "GameAlreadyOver"
  }
}

pub fn move(
  game: board.Game,
  action: ActionType,
) -> Result(board.Game, ActionError) {
  case game {
    board.Game(board, player) -> {
      use <- bool.guard(player != action.player, Error(WrongTurnPlayer))

      use result <- result.map(move_inner(board, action))

      case result {
        Continue(new_board) -> board.Game(new_board, board.other_player(player))
        Win(new_board, winner) -> board.GameWon(new_board, winner)
      }
    }
    board.GameWon(_, _) -> Error(GameAlreadyOver)
  }
}

fn move_inner(
  board: Board,
  action: ActionType,
) -> Result(ActionResult, ActionError) {
  case action {
    Move(player, active, pivot) -> {
      use #(new_board, target) <- result.map(move_piece(
        board,
        player,
        active,
        pivot,
      ))

      io.debug(new_board)

      suffocation(new_board, action.player, target)
      |> conversion(action.player, target)
    }
    Place(player) -> place(board, player)
  }
  |> result.map(win_check)
}

// action
// suffocation
// conversion
// win_check

fn move_piece(
  board: Board,
  player: Color,
  active: Position,
  pivot: Position,
) -> Result(#(Board, Position), ActionError) {
  use <- bool.guard(active == pivot, Error(PivotAndActiveAreTheSame))

  use <- bool.guard(
    board.get(board, active) != Some(player),
    Error(PivotOrActiveAreEnemy),
  )
  use <- bool.guard(
    board.get(board, pivot) != Some(player),
    Error(PivotOrActiveAreEnemy),
  )

  use diff <- result.then(
    board.get_diff(from: active, to: pivot)
    |> option.to_result(PivotAndActiveAreTooFarApart),
  )
  io.debug(diff.0)
  io.debug(diff.1)
  use target <- result.then(
    board.apply_diff(pivot, diff)
    |> option.to_result(MoveTargetOffBoard),
  )
  io.debug(target)
  use _ <- result.then(case board.get(board, target) {
    None -> Ok(Nil)
    Some(_) -> Error(MoveTargetIsOccupied)
  })

  let board2 = board.set(board, active, None)

  Ok(#(board.set(board2, target, Some(player)), target))
}

fn place(old_board: Board, player: Color) -> Result(Board, ActionError) {
  let home = case player {
    White -> board.white_home
    Black -> board.black_home
  }

  let #(new_board, count) =
    list.fold(home, #(old_board, 0), fn(board_and_count, pos) {
      let #(board, count) = board_and_count
      case board.set_if_empty(board, pos, player) {
        Some(new_board) -> #(new_board, count + 1)
        None -> board_and_count
      }
    })

  case count {
    0 -> Error(NothingCanBePlaced)
    _ -> Ok(new_board)
  }
}

fn suffocation(
  board: Board,
  player_that_moved: Color,
  target: Position,
) -> Board {
  // around the target pieces
  let enemy_neighbors =
    board.get_neighbors(target)
    |> list.map(fn(pos) {
      board.get(board, pos)
      |> fn(m_color) {
        case m_color {
          None -> None
          Some(c) if c == player_that_moved -> None
          Some(_) -> Some(pos)
        }
      }
    })
    |> option.values

  // check if fully surrounded
  let neighbors_to_suffocate =
    enemy_neighbors
    |> list.filter(fn(pos) {
      board.get_neighbors(pos)
      |> list.all(fn(pos) { board |> board.get(pos) |> option.is_some })
    })

  // terminate the pieces
  list.fold(neighbors_to_suffocate, board, fn(board, pos) {
    board.set(board, pos, None)
  })
}

fn conversion(board: Board, player_that_moved: Color, target: Position) -> Board {
  let enemy_neighbors_with_friends_beyond =
    board.get_neighbors_two_out(target)
    |> list.map(fn(pos2) {
      let #(pos, beyond_pos) = pos2
      let m_color_fst = board.get(board, pos)
      let m_color_snd = board.get(board, beyond_pos)

      case m_color_fst, m_color_snd {
        Some(color_fst), Some(color_snd)
          if color_fst != player_that_moved && color_snd == player_that_moved
        -> Some(pos)
        _, _ -> None
      }
    })
    |> option.values

  // change to player_that_moved
  list.fold(enemy_neighbors_with_friends_beyond, board, fn(board, pos) {
    board.set(board, pos, Some(player_that_moved))
  })
}

/// The winner is whoever can control the center 4 squares
fn win_check(board: Board) -> ActionResult {
  let Board(_, _, _, r3, r4, _, _, _) = board
  let RankContent(_, _, _, top_left, top_right, _, _, _) = r3
  let RankContent(_, _, _, bottom_left, bottom_right, _, _, _) = r4

  case top_left, top_right, bottom_left, bottom_right {
    Some(White), Some(White), Some(White), Some(White) -> Win(board, White)
    Some(Black), Some(Black), Some(Black), Some(Black) -> Win(board, Black)
    _, _, _, _ -> Continue(board)
  }
}
