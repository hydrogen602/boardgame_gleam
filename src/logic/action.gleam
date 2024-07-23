import gleam/bool
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
  MoveTargetIsOccupied
  MoveTargetOffBoard
  Other
}

pub fn move(
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
  use diff <- result.then(
    board.get_diff(from: active, to: pivot)
    |> option.to_result(PivotAndActiveAreTooFarApart),
  )
  use target <- result.then(
    board.apply_diff(active, diff)
    |> option.to_result(MoveTargetOffBoard),
  )
  use _ <- result.then(case board.get(board, target) {
    None -> Ok(Nil)
    Some(_) -> Error(MoveTargetIsOccupied)
  })

  Ok(#(board.set(board, target, Some(player)), target))
}

fn place(old_board: Board, player: Color) -> Result(Board, ActionError) {
  let home = case player {
    White -> board.white_home
    Black -> board.black_home
  }

  list.try_fold(home, old_board, fn(board, pos) {
    board.set_if_empty(board, pos, player) |> option.to_result(Nil)
  })
  |> result.map_error(fn(_) { NothingCanBePlaced })
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

  todo as "Implement the conversion function"
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
