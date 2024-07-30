import gleam/option
import gleam/result
import gleam/string

import logic/action
import logic/board

pub type PlayerMessage {
  Reset
  GetBoard
  GetPlayer
  Move(action.ActionType)
}

pub fn from_string(s: String) -> Result(PlayerMessage, String) {
  case s {
    "reset" -> Ok(Reset)
    "get_board" -> Ok(GetBoard)
    "get_player" -> Ok(GetPlayer)
    "move=" <> rest -> from_string_move(rest) |> result.map(Move(_))
    _ -> Error("Unknown message")
  }
}

fn from_string_move(s: String) -> Result(action.ActionType, String) {
  case s {
    "move=" <> rest ->
      case string.split(rest, ",") {
        [color, active, pivot] -> {
          use color <- result.then(case color {
            "white" -> Ok(board.White)
            "black" -> Ok(board.Black)
            _ -> Error("Invalid color")
          })
          use active <- result.then(
            board.position_from_string(active)
            |> option.to_result("Invalid move"),
          )
          use pivot <- result.then(
            board.position_from_string(pivot)
            |> option.to_result("Invalid move"),
          )
          Ok(action.Move(color, active, pivot))
        }
        _ -> Error("Invalid move")
      }
    "place=white" -> Ok(action.Place(board.White))
    "place=black" -> Ok(action.Place(board.Black))
    _ -> Error("Unknown move")
  }
}
