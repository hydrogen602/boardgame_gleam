import gleam/bytes_builder
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import logic/action
import mist.{type Connection, type ResponseData, type WebsocketConnection}

import logic/board.{type Game}

pub fn main() {
  // These values are for the Websocket process initialized below - 
  let selector = process.new_selector()
  let state = board.Game(board.starting_board, board.White)

  // let not_found =
  //   response.new(404)
  //   |> response.set_body(mist.Bytes(bytes_builder.new()))

  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(_conn) { #(state, Some(selector)) },
            on_close: fn(_state) { io.println("goodbye!") },
            handler: handle_ws_message,
          )
        ["echo"] -> echo_body(req)
        [] -> index(req)
        any -> not_found(req, any)
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

pub type MyMessage {
  Reset
  GetBoard
  GetPlayer
  Move(action.ActionType)
}

fn from_string(s: String) -> Result(MyMessage, String) {
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

fn broadcast_new_state(conn, new_state: Game) {
  use _ <- result.then(mist.send_text_frame(
    conn,
    "board=" <> board.to_string(new_state.board),
  ))
  case new_state {
    board.GameWon(_, winner) -> {
      let assert Ok(_) =
        mist.send_text_frame(conn, "winner=" <> board.color_to_string(winner))
    }
    board.Game(_, player) -> {
      let assert Ok(_) =
        mist.send_text_frame(conn, "player=" <> board.color_to_string(player))
    }
  }
}

fn handler2(state: Game, conn, message: MyMessage) {
  case message {
    Reset -> {
      let assert Ok(_) = mist.send_text_frame(conn, "resetting")
      let new_state = board.Game(board.starting_board, board.White)
      let assert Ok(_) = broadcast_new_state(conn, new_state)
      actor.continue(new_state)
    }
    GetBoard -> {
      let assert Ok(_) =
        mist.send_text_frame(conn, "board=" <> board.to_string(state.board))
      actor.continue(state)
    }
    GetPlayer -> {
      let msg = case state {
        board.Game(_, player) -> {
          "player=" <> board.color_to_string(player)
        }
        board.GameWon(_, winner) -> {
          "winner=" <> board.color_to_string(winner)
        }
      }
      let assert Ok(_) = mist.send_text_frame(conn, msg)
      actor.continue(state)
    }
    Move(action) -> {
      let result = action.move(state, action)
      case result {
        Ok(new_state) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "move")
          let assert Ok(_) = broadcast_new_state(conn, new_state)
          actor.continue(new_state)
        }
        Error(err) -> {
          let assert Ok(_) =
            mist.send_text_frame(
              conn,
              "error=" <> action.action_error_to_string(err),
            )
          actor.continue(state)
        }
      }
    }
  }
}

fn handle_ws_message(state: Game, conn: WebsocketConnection, message) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }
    mist.Text(m) -> {
      case from_string(m) {
        Ok(msg) -> handler2(state, conn, msg)
        Error(err) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "error=" <> err)
          actor.continue(state)
        }
      }
    }
    mist.Custom(_) -> {
      actor.continue(state)
    }
    mist.Binary(_) -> {
      actor.continue(state)
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}

fn echo_body(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  mist.read_body(request, 1024 * 1024 * 10)
  |> result.map(fn(req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_bit_array(req.body)))
    |> response.set_header("content-type", content_type)
  })
  |> result.lazy_unwrap(fn() {
    response.new(400)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
  })
}

fn index(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  response.new(200)
  |> response.set_body(mist.Bytes(bytes_builder.from_string("Hello, world!")))
  |> response.set_header("content-type", content_type)
}

fn not_found(
  request: Request(Connection),
  path: List(String),
) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  let body = "Not Found: " <> string.join(path, "/")

  response.new(404)
  |> response.set_body(mist.Bytes(bytes_builder.from_string(body)))
  |> response.set_header("content-type", content_type)
}
