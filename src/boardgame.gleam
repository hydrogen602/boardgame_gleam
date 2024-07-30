import gleam/bytes_builder
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData, type WebsocketConnection}

import logic/board
import manager.{new_top_games_manager}
import player_message

pub fn main() {
  // These values are for the Websocket process initialized below - 
  let selector = process.new_selector()
  // let state = board.Game(board.starting_board, board.White)

  let games_manager = new_top_games_manager()

  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["ws", game_tok, player_tok] -> {
          let game_token = manager.GameToken(game_tok)
          let player_token = manager.PlayerToken(player_tok)

          mist.websocket(
            request: req,
            on_init: fn(conn) {
              let assert Ok(color) =
                actor.call(
                  games_manager,
                  manager.RegisterConn(game_token, player_token, conn, _),
                  100,
                )
              #(color, Some(selector))
            },
            on_close: fn(_) {
              actor.send(
                games_manager,
                manager.Disconnect(game_token, player_token),
              )
            },
            handler: fn(state, conn, msg) {
              handle_ws_message(
                state,
                conn,
                msg,
                games_manager,
                game_token,
                player_token,
              )
            },
          )
        }
        ["get_code"] -> {
          let payload =
            actor.call(games_manager, manager.AddGame, 100)
            |> manager.game_token_to_string
            |> bytes_builder.from_string
            |> mist.Bytes

          response.new(200)
          |> response.set_body(payload)
          |> response.set_header("content-type", "text/plain")
        }
        ["join_game", color, game_tok] -> {
          let color_ok = case color {
            "white" -> Ok(board.White)
            "black" -> Ok(board.Black)
            _ -> Error("Invalid color")
          }

          case color_ok {
            Error(err) -> {
              response.new(400)
              |> response.set_body(mist.Bytes(bytes_builder.from_string(err)))
              |> response.set_header("content-type", "text/plain")
            }
            Ok(color) -> {
              case
                actor.call(
                  games_manager,
                  manager.JoinGame(manager.GameToken(game_tok), color, _),
                  100,
                )
              {
                Ok(player_tok) -> {
                  response.new(200)
                  |> response.set_body(
                    mist.Bytes(
                      bytes_builder.from_string(manager.player_token_to_string(
                        player_tok,
                      )),
                    ),
                  )
                  |> response.set_header("content-type", "text/plain")
                }
                Error(err) -> {
                  response.new(400)
                  |> response.set_body(
                    mist.Bytes(bytes_builder.from_string(err)),
                  )
                  |> response.set_header("content-type", "text/plain")
                }
              }
            }
          }
        }
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

fn handle_ws_message(
  state: board.Color,
  conn: WebsocketConnection,
  message,
  games_manager: process.Subject(manager.TopGamesManagerMessage),
  game_token: manager.GameToken,
  player_token: manager.PlayerToken,
) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }
    mist.Text(m) -> {
      case player_message.from_string(m) {
        Ok(msg) -> {
          actor.send(
            games_manager,
            manager.PlayerMakesMove(msg, game_token, player_token, conn, state),
          )
          actor.continue(state)
        }
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
