import birl.{type Time}
import birl/duration
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import logic/action
import mist.{type WebsocketConnection}
import player_message
import utils

import logic/board.{type Color, type Game}

pub opaque type TopGamesManagerState {
  TopGamesManagerState(participants: Dict(GameToken, OneGame))
}

pub type TopGamesManagerMessage {
  AddGame(reply_to: process.Subject(GameToken))
  JoinGame(
    GameToken,
    Color,
    reply_to: process.Subject(Result(PlayerToken, String)),
  )
  RegisterConn(
    GameToken,
    PlayerToken,
    WebsocketConnection,
    reply_to: process.Subject(Result(Color, String)),
  )
  Disconnect(GameToken, PlayerToken)
  PlayerMakesMove(
    player_message.PlayerMessage,
    GameToken,
    PlayerToken,
    WebsocketConnection,
    board.Color,
  )
}

pub type OneGame {
  OneGame(
    board: Game,
    players: Dict(Color, #(Option(WebsocketConnection), PlayerToken)),
    last_activity: Time,
  )
}

pub fn new_top_games_manager() -> process.Subject(TopGamesManagerMessage) {
  let m = TopGamesManagerState(participants: dict.new())
  let assert Ok(actor) = actor.start(m, handle_message_top_manager)
  actor
}

pub type GameToken {
  GameToken(String)
}

pub type PlayerToken {
  PlayerToken(String)
}

fn token_gen_game() -> GameToken {
  list.range(1, 16)
  |> list.map(fn(_) { int.random(256) |> int.to_base16 })
  |> string.join("")
  |> GameToken
}

fn token_gen_player() -> PlayerToken {
  list.range(1, 16)
  |> list.map(fn(_) { int.random(256) |> int.to_base16 })
  |> string.join("")
  |> PlayerToken
}

pub fn game_token_to_string(s: GameToken) -> String {
  let GameToken(s) = s
  s
}

pub fn player_token_to_string(s: PlayerToken) -> String {
  let PlayerToken(s) = s
  s
}

fn handle_message_top_manager(
  message: TopGamesManagerMessage,
  state: TopGamesManagerState,
) -> actor.Next(TopGamesManagerMessage, TopGamesManagerState) {
  case message {
    AddGame(reply_to) -> {
      let game_id = token_gen_game()

      let now = birl.now()

      let game =
        OneGame(
          board: board.starting_game,
          players: dict.new(),
          last_activity: now,
        )

      // lets delete all games that have been inactive for 12hrs
      let filtered_participants =
        dict.filter(state.participants, fn(_, game) {
          let diff = birl.difference(now, game.last_activity)
          let result = duration.blur_to(diff, duration.Hour) < 12
          case result {
            True ->
              io.println("deleting game: " <> game_token_to_string(game_id))
            _ -> Nil
          }

          result
        })

      io.println("adding game: " <> game_token_to_string(game_id))

      // there's a tiny chance of collision here, but it's fine for now cause the chance is so low
      let state =
        TopGamesManagerState(participants: dict.insert(
          filtered_participants,
          game_id,
          game,
        ))
      actor.send(reply_to, game_id)
      actor.continue(state)
    }
    JoinGame(game_id, color, reply_to) -> {
      use game <- utils.result_actor(
        reply_to,
        state,
        dict.get(state.participants, game_id)
          |> result.map_error(fn(_) { "Game not found" }),
      )

      let spot_taken = dict.get(game.players, color)

      case spot_taken {
        Ok(_) -> {
          actor.send(reply_to, Error("Spot already taken"))
          actor.continue(state)
        }
        Error(Nil) -> {
          let player_token = token_gen_player()
          let game =
            OneGame(
              board: game.board,
              players: dict.insert(game.players, color, #(None, player_token)),
              last_activity: birl.now(),
            )
          let state =
            TopGamesManagerState(participants: dict.insert(
              state.participants,
              game_id,
              game,
            ))
          actor.send(reply_to, Ok(player_token))
          actor.continue(state)
        }
      }
    }
    RegisterConn(game_id, player_token, conn, reply_to) -> {
      use game <- utils.result_actor(
        reply_to,
        state,
        dict.get(state.participants, game_id)
          |> result.map_error(fn(_) { "Game not found" }),
      )

      use color <- utils.result_actor(
        reply_to,
        state,
        dict.to_list(game.players)
          |> list.find(fn(val) { { val.1 }.1 == player_token })
          |> result.map_error(fn(_) { "Player not found" })
          |> result.map(fn(color_and_player) { color_and_player.0 }),
      )

      let game =
        OneGame(
          board: game.board,
          players: dict.insert(game.players, color, #(Some(conn), player_token)),
          last_activity: birl.now(),
        )

      let state =
        TopGamesManagerState(participants: dict.insert(
          state.participants,
          game_id,
          game,
        ))

      actor.send(reply_to, Ok(color))
      actor.continue(state)
    }
    Disconnect(game_id, player_token) -> {
      use game <- utils.result_actor_no_reply(
        state,
        dict.get(state.participants, game_id)
          |> result.map_error(fn(_) { "Game not found" }),
      )

      use color <- utils.result_actor_no_reply(
        state,
        dict.to_list(game.players)
          |> list.find(fn(val) { { val.1 }.1 == player_token })
          |> result.map_error(fn(_) { "Player not found" })
          |> result.map(fn(color_and_player) { color_and_player.0 }),
      )

      let game =
        OneGame(
          board: game.board,
          players: dict.delete(game.players, color),
          last_activity: birl.now(),
        )

      let state =
        TopGamesManagerState(participants: dict.insert(
          state.participants,
          game_id,
          game,
        ))

      actor.continue(state)
    }
    PlayerMakesMove(msg, game_id, player_token, conn, color) -> {
      use game <- utils.result_actor_no_reply(
        state,
        dict.get(state.participants, game_id)
          |> result.map_error(fn(_) { "Game not found" }),
      )

      use player <- utils.result_actor_no_reply(
        state,
        dict.get(game.players, color)
          |> result.map_error(fn(_) { "Player not found" }),
      )

      let assert True = player_token == player.1

      let new_game =
        handler2(
          game.board,
          color,
          conn,
          msg,
          dict.values(game.players)
            |> list.filter_map(fn(x) { option.to_result(x.0, Nil) }),
        )

      // update conn just in case
      let game =
        OneGame(
          board: new_game,
          players: dict.insert(game.players, color, #(Some(conn), player_token)),
          last_activity: birl.now(),
        )

      let state =
        TopGamesManagerState(participants: dict.insert(
          state.participants,
          game_id,
          game,
        ))

      actor.continue(state)
    }
  }
}

fn handler2(
  game: Game,
  color: board.Color,
  conn,
  message: player_message.PlayerMessage,
  all_cons: List(WebsocketConnection),
) -> Game {
  case message {
    player_message.Reset -> {
      let assert Ok(_) = mist.send_text_frame(conn, "resetting")
      let new_state = board.Game(board.starting_board, board.White)
      broadcast_new_state(all_cons, new_state)
      new_state
    }
    player_message.GetBoard -> {
      let assert Ok(_) =
        mist.send_text_frame(conn, "board=" <> board.to_string(game.board))
      game
    }
    player_message.GetPlayer -> {
      let msg = case game {
        board.Game(_, player) -> {
          "player=" <> board.color_to_string(player)
        }
        board.GameWon(_, winner) -> {
          "winner=" <> board.color_to_string(winner)
        }
      }
      let assert Ok(_) = mist.send_text_frame(conn, msg)
      game
    }
    player_message.Move(action) -> {
      let result = action.move(game, action, color)
      case result {
        Ok(new_state) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "move")
          broadcast_new_state(all_cons, new_state)
          new_state
        }
        Error(err) -> {
          let assert Ok(_) =
            mist.send_text_frame(
              conn,
              "error=" <> action.action_error_to_string(err),
            )
          game
        }
      }
    }
  }
}

fn broadcast_new_state(conns: List(WebsocketConnection), new_state: Game) {
  let one = fn(conn) {
    let assert Ok(_) =
      mist.send_text_frame(conn, "board=" <> board.to_string(new_state.board))

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
  list.each(conns, one)
}
