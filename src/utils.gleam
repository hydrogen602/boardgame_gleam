import gleam/erlang/process
import gleam/io
import gleam/option.{type Option}
import gleam/otp/actor

pub fn tuple2(a: a, b: b) -> #(a, b) {
  #(a, b)
}

pub fn twice_optional(start: a, f: fn(a) -> Option(a)) -> Option(#(a, a)) {
  use first <- option.then(f(start))
  f(first) |> option.map(tuple2(first, _))
}

pub fn combine(ma: Option(a), mb: Option(b)) -> Option(#(a, b)) {
  ma
  |> option.then(fn(a) { mb |> option.map(tuple2(a, _)) })
}

pub fn result_actor(
  reply_to: process.Subject(Result(m_any, e)),
  old_state: s,
  result: Result(m, e),
  continue: fn(m) -> actor.Next(c, s),
) -> actor.Next(c, s) {
  case result {
    Ok(good) -> {
      continue(good)
    }
    Error(err) -> {
      actor.send(reply_to, Error(err))
      actor.continue(old_state)
    }
  }
}

pub fn result_actor_no_reply(
  old_state: s,
  result: Result(m, e),
  continue: fn(m) -> actor.Next(c, s),
) -> actor.Next(c, s) {
  case result {
    Ok(good) -> {
      continue(good)
    }
    Error(err) -> {
      io.debug(err)
      actor.continue(old_state)
    }
  }
}
